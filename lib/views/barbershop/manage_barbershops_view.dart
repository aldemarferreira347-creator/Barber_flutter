import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../models/platform_settings.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/platform_settings_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/payment_status_line.dart';
import '../widgets/responsive_body.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/shop_avatar.dart';
import '../widgets/status_badge.dart';
import 'admin_shop_sheet.dart';
import 'approval_status_badge.dart';
import 'barbershop_detail_view.dart';
import 'owner_barbershop_manage_view.dart';
import 'payment_insight.dart';
import '../../utils/error_text.dart';

enum AdminShopFilter { pending, ok, dueSoon, grace, blocked }

/// Gestión de barberías del admin: todas las barberías con búsqueda, filtros
/// por estado de revisión y de mensualidad, y una hoja de acciones por
/// barbería (aprobar, rechazar, bloquear, confirmar pago…). Las barberías
/// propias del dueño viven en `MyBarbershopsView` y el catálogo del cliente
/// en `BarbershopCatalogView`.
class ManageBarbershopsView extends StatefulWidget {
  /// Filtro con el que abre la lista: p. ej. las pendientes de aprobación,
  /// desde el aviso del dashboard.
  final AdminShopFilter? initialFilter;

  const ManageBarbershopsView({super.key, this.initialFilter});

  @override
  State<ManageBarbershopsView> createState() => _ManageBarbershopsViewState();
}

class _ManageBarbershopsViewState extends State<ManageBarbershopsView> {
  late final Stream<List<Barbershop>> _shops = context
      .read<BarbershopRepository>()
      .watchAll();
  late final Stream<PlatformSettings> _settings = context
      .read<PlatformSettingsRepository>()
      .watch();

  String _query = '';
  late AdminShopFilter? _filter = widget.initialFilter;

  String _filterLabel(AdminShopFilter filter) => switch (filter) {
    AdminShopFilter.pending => 'Pendientes',
    AdminShopFilter.ok => 'Al día',
    AdminShopFilter.dueSoon => 'Vence pronto',
    AdminShopFilter.grace => 'En gracia o bloqueo',
    AdminShopFilter.blocked => 'Bloqueadas',
  };

  bool _matchesFilter(Barbershop shop, int graceDays) {
    final filter = _filter;
    if (filter == null) return true;
    if (filter == AdminShopFilter.pending) {
      return shop.approvalStatus == BarbershopApprovalStatus.pending;
    }
    if (shop.approvalStatus != BarbershopApprovalStatus.approved) {
      return false;
    }
    final level = paymentInsight(shop, graceDays: graceDays).level;
    return switch (filter) {
      AdminShopFilter.pending => false, // ya cubierto arriba
      AdminShopFilter.ok => level == PaymentInsightLevel.ok,
      AdminShopFilter.dueSoon => level == PaymentInsightLevel.dueSoon,
      AdminShopFilter.grace =>
        level == PaymentInsightLevel.grace ||
            level == PaymentInsightLevel.graceExpired,
      AdminShopFilter.blocked => level == PaymentInsightLevel.blocked,
    };
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openActions(Barbershop shop, int graceDays) async {
    final action = await AdminShopSheet.show(
      context,
      shop: shop,
      insight: paymentInsight(shop, graceDays: graceDays),
    );
    if (action == null || !mounted) return;
    final repo = context.read<BarbershopRepository>();
    switch (action) {
      case AdminShopAction.approve:
        await _run(
          () => repo.resolveApproval(shop.id, approve: true),
          success: '"${shop.name}" aprobada y pago confirmado',
          failure: 'No se pudo aprobar',
        );
      case AdminShopAction.reject:
        final ok = await AppDialog.confirm(
          context,
          title: 'Rechazar barbería',
          message:
              '"${shop.name}" no aparecerá en el catálogo y su pago quedará '
              'como no recibido. El dueño podrá corregirla o eliminarla.',
          confirmLabel: 'Sí, rechazar',
          cancelLabel: 'Volver',
          destructive: true,
        );
        if (ok) {
          await _run(
            () => repo.resolveApproval(shop.id, approve: false),
            success: '"${shop.name}" rechazada',
            failure: 'No se pudo rechazar',
          );
        }
      case AdminShopAction.info:
        _push(BarbershopDetailView(barbershopId: shop.id));
      case AdminShopAction.manage:
        _push(OwnerBarbershopManageView(barbershopId: shop.id));
      case AdminShopAction.toggleActive:
        await _run(
          () => repo.setActive(shop.id, !shop.active),
          success: shop.active ? 'Barbería desactivada' : 'Barbería activada',
          failure: 'No se pudo actualizar',
        );
      case AdminShopAction.confirmPayment:
        final ok = await AppDialog.confirm(
          context,
          title: 'Registrar pago recibido',
          message:
              'Confirma que recibiste la mensualidad de "${shop.name}" fuera '
              'de la app. Quedará al día por 30 días más y se reactivará si '
              'estaba bloqueada.',
          confirmLabel: 'Sí, lo recibí',
        );
        if (ok) {
          await _run(
            () => repo.confirmPaymentReceived(shop.id),
            success: 'Mensualidad al día por 30 días más',
            failure: 'No se pudo confirmar el pago',
          );
        }
      case AdminShopAction.block:
        final ok = await AppDialog.confirm(
          context,
          title: 'Bloquear por impago',
          message:
              '"${shop.name}" y sus barberos quedarán bloqueados de inmediato '
              'y desaparecerán del catálogo hasta regularizar el pago.',
          confirmLabel: 'Sí, bloquear',
          cancelLabel: 'Volver',
          destructive: true,
        );
        if (ok) {
          await _run(
            () => repo.blockForNonPayment(shop.id),
            success: '"${shop.name}" bloqueada por impago',
            failure: 'No se pudo bloquear',
          );
        }
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String success,
    required String failure,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$failure: ${errorText(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de barberías')),
      body: StreamBuilder<PlatformSettings>(
        stream: _settings,
        initialData: PlatformSettings.defaults,
        builder: (context, settingsSnapshot) {
          final graceDays =
              (settingsSnapshot.data ?? PlatformSettings.defaults).graceDays;
          return ResponsiveBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpace.lg),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar barberías…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: AppSpace.md),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpace.sm),
                        child: ChoiceChip(
                          label: const Text('Todas'),
                          selected: _filter == null,
                          onSelected: (_) => setState(() => _filter = null),
                        ),
                      ),
                      for (final filter in AdminShopFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpace.sm),
                          child: ChoiceChip(
                            label: Text(_filterLabel(filter)),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Expanded(
                  child: StreamBuilder<List<Barbershop>>(
                    stream: _shops,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const ErrorState(
                          title: 'No pudimos cargar las barberías',
                          subtitle:
                              'Verifica tu conexión e inténtalo de nuevo.',
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const ShimmerList();
                      }
                      final shops = [
                        for (final shop
                            in snapshot.data ?? const <Barbershop>[])
                          if ((_query.isEmpty ||
                                  shop.name.toLowerCase().contains(_query)) &&
                              _matchesFilter(shop, graceDays))
                            shop,
                      ];
                      if (shops.isEmpty) {
                        return const EmptyState(
                          icon: Icons.storefront_outlined,
                          title: 'Sin barberías',
                          subtitle:
                              'No hay barberías que coincidan con la búsqueda '
                              'o el filtro.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: AppSpace.xl),
                        itemCount: shops.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpace.md),
                        itemBuilder: (context, index) => _ShopCard(
                          shop: shops[index],
                          graceDays: graceDays,
                          onTap: () => _openActions(shops[index], graceDays),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final Barbershop shop;
  final int graceDays;
  final VoidCallback onTap;

  const _ShopCard({
    required this.shop,
    required this.graceDays,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final approved = shop.approvalStatus == BarbershopApprovalStatus.approved;
    final pending = shop.approvalStatus == BarbershopApprovalStatus.pending;
    final insight = paymentInsight(shop, graceDays: graceDays);
    return AppCard(
      onTap: onTap,
      semanticLabel: 'Acciones de ${shop.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShopAvatar(photoUrl: shop.photoUrl, name: shop.name),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.name, style: text.titleSmall),
                    if ((shop.address ?? '').isNotEmpty)
                      Text(
                        shop.address!,
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: AppSpace.sm),
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: [
                        ApprovalStatusBadge(status: shop.approvalStatus),
                        if (approved)
                          StatusBadge(
                            label: insight.label,
                            color: insight.color,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_vert, color: AppColors.textSecondary),
            ],
          ),
          if (pending && shop.paymentId != null) ...[
            const SizedBox(height: AppSpace.md),
            PaymentStreamBuilder(
              paymentId: shop.paymentId,
              builder: (context, payment) => payment == null
                  ? Text('Cargando pago…', style: text.bodySmall)
                  : PaymentStatusLine(payment: payment),
            ),
          ],
        ],
      ),
    );
  }
}
