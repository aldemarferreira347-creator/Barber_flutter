import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../models/barbershop.dart';
import '../../models/payment_record.dart';
import '../../models/platform_settings.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/platform_settings_repository.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../admin/manage_users_view.dart';
import '../admin/pending_payments_view.dart';
import '../admin/platform_settings_view.dart';
import '../barbershop/manage_barbershops_view.dart';
import '../barbershop/payment_insight.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/brand_mark.dart';
import '../widgets/dashboard_scaffold.dart';
import '../widgets/error_state.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  late final Stream<PlatformSettings> _settings = context
      .read<PlatformSettingsRepository>()
      .watch();
  late final Stream<List<PaymentRecord>> _pendingPayments = context
      .read<PaymentRepository>()
      .watchPendingSubscriptions();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkOverduePayments(context);
    });
  }

  /// Barrido de mensualidades sin backend (no hay cron sin plan de pago):
  /// se corre cuando el admin abre su panel y deja guardado lo que ya es
  /// verdad por fechas — vencida => 'overdue' (y avisa al dueño); pasada la
  /// gracia => bloqueada. Aunque nadie lo corra, el estado se DERIVA igual
  /// de la fecha (ver `paymentInsight`) y las reglas ya impiden que una
  /// barbería con la gracia vencida reciba citas; esto solo lo vuelve
  /// visible y notifica.
  Future<void> _checkOverduePayments(BuildContext context) async {
    final barbershopRepo = context.read<BarbershopRepository>();
    final notificationRepo = context.read<NotificationRepository>();
    final settings = await context
        .read<PlatformSettingsRepository>()
        .watch()
        .first;
    final shops = await barbershopRepo.watchAll().first;
    final now = DateTime.now();

    for (final shop in shops) {
      final dueDate = shop.paymentDueDate;
      if (shop.approvalStatus != BarbershopApprovalStatus.approved ||
          dueDate == null) {
        continue;
      }
      final level = paymentInsight(
        shop,
        now: now,
        graceDays: settings.graceDays,
      ).level;
      final due = '${dueDate.day}/${dueDate.month}/${dueDate.year}';
      if (level == PaymentInsightLevel.graceExpired &&
          shop.paymentStatus != PaymentStatus.blocked) {
        await barbershopRepo.blockForNonPayment(shop.id);
        await notificationRepo.send(
          toUserId: shop.ownerId,
          title: 'Barbería bloqueada por mora',
          body:
              '"${shop.name}" se bloqueó: la mensualidad venció el $due y terminó el período de gracia. Paga para reactivarla.',
          type: NotificationType.autoPaymentOverdue,
        );
      } else if (level == PaymentInsightLevel.grace &&
          shop.paymentStatus == PaymentStatus.ok) {
        await barbershopRepo.setPaymentStatus(shop.id, PaymentStatus.overdue);
        await notificationRepo.send(
          toUserId: shop.ownerId,
          title: 'Pago vencido',
          body:
              'El pago de "${shop.name}" venció el $due. Regulariza antes de que termine la gracia para evitar el bloqueo.',
          type: NotificationType.autoPaymentOverdue,
        );
      }
    }
  }

  void _openShops(AdminShopFilter? filter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManageBarbershopsView(initialFilter: filter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final userService = context.read<UserRepository>();
    final barbershopService = context.read<BarbershopRepository>();
    final greetingName = profile?.firstName.isNotEmpty == true
        ? profile!.firstName
        : 'Admin';

    return DashboardScaffold(
      greeting: 'Hola, $greetingName 👋',
      subtitle: 'Panel de administración',
      avatar: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.surface,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: BrandMark(size: 28, spin: false),
        ),
      ),
      notificationsUid: profile?.uid,
      children: [
        StreamBuilder<List<AppUser>>(
          stream: userService.watchAll(),
          builder: (context, userSnapshot) {
            if (userSnapshot.hasError) {
              return const ErrorState(
                title: 'No pudimos cargar las estadísticas',
                subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
              );
            }
            final users = userSnapshot.data ?? [];
            return StreamBuilder<PlatformSettings>(
              stream: _settings,
              initialData: PlatformSettings.defaults,
              builder: (context, settingsSnapshot) =>
                  StreamBuilder<List<PaymentRecord>>(
                    stream: _pendingPayments,
                    builder: (context, paymentsSnapshot) {
                      final settings =
                          settingsSnapshot.data ?? PlatformSettings.defaults;
                      final pendingPayments =
                          paymentsSnapshot.data?.length ?? 0;
                      return StreamBuilder<List<Barbershop>>(
                        stream: barbershopService.watchAll(),
                        builder: (context, shopSnapshot) {
                          if (shopSnapshot.hasError) {
                            return const ErrorState(
                              title: 'No pudimos cargar las estadísticas',
                              subtitle:
                                  'Verifica tu conexión e inténtalo de nuevo.',
                            );
                          }
                          final shops = shopSnapshot.data ?? [];
                          final pending = shops
                              .where(
                                (s) =>
                                    s.approvalStatus ==
                                    BarbershopApprovalStatus.pending,
                              )
                              .length;
                          final late = shops.where((s) {
                            if (s.approvalStatus !=
                                BarbershopApprovalStatus.approved) {
                              return false;
                            }
                            final level = paymentInsight(
                              s,
                              graceDays: settings.graceDays,
                            ).level;
                            return level == PaymentInsightLevel.grace ||
                                level == PaymentInsightLevel.graceExpired;
                          }).length;
                          final needsAttention =
                              pending > 0 ||
                              late > 0 ||
                              pendingPayments > 0 ||
                              !settings.canCharge;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (needsAttention) ...[
                                const SectionHeader(
                                  title: 'Requiere tu atención',
                                ),
                                if (!settings.canCharge) ...[
                                  ActionListTile(
                                    icon: Icons.account_balance_wallet_outlined,
                                    iconColor: AppColors.error,
                                    label:
                                        'Configura el Nequi de la plataforma',
                                    subtitle: 'Sin él los dueños no pueden pagar su mensualidad',
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PlatformSettingsView(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpace.sm),
                                ],
                                if (pendingPayments > 0) ...[
                                  ActionListTile(
                                    icon: Icons.fact_check_outlined,
                                    iconColor: AppColors.warning,
                                    label: 'Pagos por verificar',
                                    subtitle: 'Mensualidades que esperan tu confirmación',
                                    trailing: StatusBadge(
                                      label: '$pendingPayments',
                                      color: AppColors.warning,
                                    ),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PendingPaymentsView(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpace.sm),
                                ],
                                if (pending > 0)
                                  ActionListTile(
                                    icon: Icons.hourglass_top_outlined,
                                    iconColor: AppColors.warning,
                                    label: 'Solicitudes de barbería',
                                    subtitle: 'Esperan tu aprobación o rechazo',
                                    trailing: StatusBadge(
                                      label: '$pending',
                                      color: AppColors.warning,
                                    ),
                                    onTap: () =>
                                        _openShops(AdminShopFilter.pending),
                                  ),
                                if (pending > 0 && late > 0)
                                  const SizedBox(height: AppSpace.sm),
                                if (late > 0)
                                  ActionListTile(
                                    icon: Icons.payments_outlined,
                                    iconColor: AppColors.error,
                                    label: 'Mensualidades por regularizar',
                                    subtitle: 'En mora o en período de gracia',
                                    trailing: StatusBadge(
                                      label: '$late',
                                      color: AppColors.error,
                                    ),
                                    onTap: () =>
                                        _openShops(AdminShopFilter.grace),
                                  ),
                                const SizedBox(height: AppSpace.xl),
                              ],
                              const SectionHeader(title: 'Resumen'),
                              StatGrid(
                                children: [
                                  StatCard(
                                    icon: Icons.storefront_outlined,
                                    value: '${shops.length}',
                                    label: 'Barberías registradas',
                                    iconColor: AppColors.accent,
                                  ),
                                  StatCard(
                                    icon: Icons.people_outline,
                                    value:
                                        '${users.where((u) => u.active).length}',
                                    label: 'Usuarios activos',
                                    iconColor: AppColors.success,
                                  ),
                                  StatCard(
                                    icon: Icons.storefront,
                                    value:
                                        '${shops.where((s) => s.active).length}',
                                    label: 'Barberías activas',
                                    iconColor: AppColors.accent,
                                  ),
                                  StatCard(
                                    icon: Icons.warning_amber_outlined,
                                    value:
                                        '${pending + late + pendingPayments}',
                                    label: 'Pendientes de atención',
                                    iconColor: AppColors.warning,
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
            );
          },
        ),
        const SizedBox(height: AppSpace.xl),
        const SectionHeader(title: 'Acciones rápidas'),
        ActionListTile(
          icon: Icons.people_outline,
          label: 'Gestionar usuarios',
          subtitle: 'Roles, bloqueos y notificaciones',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ManageUsersView())),
        ),
        const SizedBox(height: AppSpace.sm),
        ActionListTile(
          icon: Icons.storefront_outlined,
          label: 'Gestión de barberías',
          subtitle: 'Aprobaciones, estado y mensualidad',
          onTap: () => _openShops(null),
        ),
        const SizedBox(height: AppSpace.sm),
        ActionListTile(
          icon: Icons.fact_check_outlined,
          label: 'Pagos por verificar',
          subtitle: 'Confirma las mensualidades pagadas por Nequi',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PendingPaymentsView()),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        ActionListTile(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Datos de cobro',
          subtitle: 'Nequi de la plataforma, tarifa y días de gracia',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlatformSettingsView()),
          ),
        ),
      ],
    );
  }
}
