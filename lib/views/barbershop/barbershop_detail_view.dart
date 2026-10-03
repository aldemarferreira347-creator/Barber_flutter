import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../models/day_schedule.dart';
import '../../models/platform_settings.dart';
import '../../models/user_role.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/platform_settings_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../utils/shop_hours.dart';
import '../appointment/book_appointment_view.dart';
import '../product/manage_products_view.dart';
import '../service/manage_services_view.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_network_image.dart';
import '../widgets/error_state.dart';
import '../widgets/responsive_body.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/status_badge.dart';
import 'barbershop_reviews_view.dart';
import 'payment_insight.dart';

/// Ficha de una barbería: portada, valoración, si está abierta ahora,
/// contacto, horario y accesos a servicios, productos y reseñas. Quien
/// puede reservar (cliente, o dueño en barbería ajena) ve el botón de
/// agendar; el estado de la mensualidad solo lo ven el dueño y el admin.
class BarbershopDetailView extends StatelessWidget {
  final String barbershopId;

  const BarbershopDetailView({super.key, required this.barbershopId});

  Future<void> _launch(BuildContext context, Uri uri, String failure) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(failure)));
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<BarbershopRepository>();
    final profile = context.watch<AuthController>().profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Barbería')),
      body: StreamBuilder<Barbershop?>(
        stream: service.watchOne(barbershopId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: ErrorState(
                title: 'No pudimos cargar la barbería',
                subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: ShimmerList(itemHeight: 120),
            );
          }
          final shop = snapshot.data;
          if (shop == null) {
            return Center(
              child: Text(
                'Esta barbería ya no existe',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          final isOwnerOrAdmin =
              profile != null &&
              (profile.role == UserRole.admin || shop.ownerId == profile.uid);
          // Reservan los Clientes y también los Dueños (en barberías ajenas:
          // no tiene sentido agendarse en la propia).
          final canBook =
              profile != null &&
              (profile.role == UserRole.client ||
                  (profile.role == UserRole.owner &&
                      shop.ownerId != profile.uid));

          return ResponsiveBody(
            maxWidth: AppLayout.formWidth,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
              children: [
                _Cover(shop: shop),
                const SizedBox(height: AppSpace.lg),
                _Summary(shop: shop),
                const SizedBox(height: AppSpace.lg),
                if (canBook) _BookButton(shop: shop),
                const SizedBox(height: AppSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.content_cut,
                        label: 'Servicios',
                        onTap: () => _push(
                          context,
                          ManageServicesView(barbershopId: shop.id),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Productos',
                        onTap: () => _push(
                          context,
                          ManageProductsView(barbershopId: shop.id),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.reviews_outlined,
                        label: 'Reseñas',
                        onTap: () => _push(
                          context,
                          BarbershopReviewsView(barbershopId: shop.id),
                        ),
                      ),
                    ),
                  ],
                ),
                if ((shop.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpace.xl),
                  const SectionHeader(title: 'Información general'),
                  Text(
                    shop.description!,
                    style: Theme.of(context).textTheme.secondary,
                  ),
                ],
                const SizedBox(height: AppSpace.xl),
                const SectionHeader(title: 'Contacto'),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.lg,
                    vertical: AppSpace.xs,
                  ),
                  child: Column(
                    children: [
                      _ContactRow(
                        icon: Icons.location_on_outlined,
                        label: shop.address ?? 'Sin dirección',
                        actionLabel: shop.location == null
                            ? null
                            : 'Cómo llegar',
                        onAction: shop.location == null
                            ? null
                            : () => _launch(
                                context,
                                Uri.parse(
                                  'https://www.google.com/maps/search/?api=1&query='
                                  '${shop.location!.latitude},${shop.location!.longitude}',
                                ),
                                'No se pudo abrir el mapa',
                              ),
                      ),
                      _ContactRow(
                        icon: Icons.phone_outlined,
                        label: shop.phone ?? 'Sin teléfono',
                        actionLabel: (shop.phone ?? '').isEmpty
                            ? null
                            : 'Llamar',
                        onAction: (shop.phone ?? '').isEmpty
                            ? null
                            : () => _launch(
                                context,
                                Uri(scheme: 'tel', path: shop.phone),
                                'No se pudo iniciar la llamada',
                              ),
                      ),
                      _ContactRow(
                        icon: Icons.mail_outline,
                        label: shop.email ?? 'Sin correo de contacto',
                        actionLabel: (shop.email ?? '').isEmpty
                            ? null
                            : 'Escribir',
                        onAction: (shop.email ?? '').isEmpty
                            ? null
                            : () => _launch(
                                context,
                                Uri(scheme: 'mailto', path: shop.email),
                                'No se pudo abrir el correo',
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                const SectionHeader(title: 'Horarios'),
                _ScheduleCard(schedule: shop.schedule),
                if (isOwnerOrAdmin) ...[
                  const SizedBox(height: AppSpace.xl),
                  const SectionHeader(title: 'Mensualidad'),
                  _SubscriptionCard(shop: shop),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final Barbershop shop;

  const _Cover({required this.shop});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    final url = shop.photoUrl;
    if (url != null && url.isNotEmpty) {
      return AppNetworkImage(
        url: url,
        semanticLabel: 'Foto de portada de ${shop.name}',
        height: 180,
        width: double.infinity,
        borderRadius: radius,
      );
    }
    return Container(
      height: 180,
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: radius),
      alignment: Alignment.center,
      child: const Icon(Icons.storefront, color: AppColors.onColor, size: 48),
    );
  }
}

class _Summary extends StatelessWidget {
  final Barbershop shop;

  const _Summary({required this.shop});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final open = shopOpenStatus(shop.schedule);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(shop.name, style: text.headlineSmall),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (shop.ratingCount > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: AppColors.gold, size: 18),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    '${shop.averageRating.toStringAsFixed(1)} '
                    '(${shop.ratingCount})',
                    style: text.titleSmall,
                  ),
                ],
              )
            else
              Text('Sin calificaciones', style: text.bodySmall),
            StatusBadge(
              label: open.label,
              color: open.isOpen ? AppColors.success : AppColors.textSecondary,
            ),
            if (shop.acceptsNequi)
              StatusBadge(label: 'Acepta Nequi', color: AppColors.accent),
          ],
        ),
      ],
    );
  }
}

/// Botón de agendar: si la barbería no puede operar (bloqueada o con la
/// mensualidad vencida más allá de la gracia) se explica en vez de dejar
/// que la reserva falle.
class _BookButton extends StatelessWidget {
  final Barbershop shop;

  const _BookButton({required this.shop});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlatformSettings>(
      stream: context.read<PlatformSettingsRepository>().watch(),
      initialData: PlatformSettings.defaults,
      builder: (context, snapshot) {
        final graceDays =
            (snapshot.data ?? PlatformSettings.defaults).graceDays;
        final operational = shop.isOperational(graceDays: graceDays);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              icon: Icons.calendar_month_outlined,
              onPressed: operational
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookAppointmentView(
                          barbershopId: shop.id,
                          barbershopName: shop.name,
                        ),
                      ),
                    )
                  : null,
              child: const Text('Agendar cita'),
            ),
            if (!operational)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: Text(
                  'Esta barbería no está recibiendo citas por ahora.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpace.md,
        horizontal: AppSpace.sm,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(height: AppSpace.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ContactRow({
    required this.icon,
    required this.label,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Text(label)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Map<String, DaySchedule> schedule;

  const _ScheduleCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final week = schedule.isEmpty ? weekScheduleFromMap(null) : schedule;
    final today = kWeekdays[DateTime.now().weekday - 1];
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.sm,
      ),
      child: Column(
        children: [
          for (final day in kWeekdays)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      day[0].toUpperCase() + day.substring(1),
                      style: day == today ? text.titleSmall : text.bodyMedium,
                    ),
                  ),
                  Text(
                    (week[day]?.isOpen ?? false)
                        ? '${week[day]!.openTime} – ${week[day]!.closeTime}'
                        : 'Cerrado',
                    style: (week[day]?.isOpen ?? false)
                        ? (day == today ? text.titleSmall : text.bodyMedium)
                        : text.secondary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final Barbershop shop;

  const _SubscriptionCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return StreamBuilder<PlatformSettings>(
      stream: context.read<PlatformSettingsRepository>().watch(),
      initialData: PlatformSettings.defaults,
      builder: (context, snapshot) {
        final settings = snapshot.data ?? PlatformSettings.defaults;
        final insight = paymentInsight(shop, graceDays: settings.graceDays);
        final due = shop.paymentDueDate;
        return AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estado de pago', style: text.bodySmall),
                    const SizedBox(height: AppSpace.xs),
                    StatusBadge(label: insight.label, color: insight.color),
                  ],
                ),
              ),
              if (due != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Vence', style: text.bodySmall),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      '${due.day.toString().padLeft(2, '0')}/'
                      '${due.month.toString().padLeft(2, '0')}/${due.year}',
                      style: text.titleSmall,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
