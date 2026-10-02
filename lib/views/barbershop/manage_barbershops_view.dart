import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/status_badge.dart';
import 'approval_status_badge.dart';
import 'owner_barbershop_manage_view.dart';
import 'barbershop_detail_view.dart';
import 'payment_insight.dart';

enum AdminShopFilter { pending, ok, dueSoon, grace, blocked }

/// Lista de barberías: con [adminControls] (solo rol admin) muestra todas con
/// sus controles de revisión; sin él es el catálogo del cliente, con las
/// aprobadas y activas. Las barberías propias del dueño (y sus borradores)
/// viven en `MyBarbershopsView`, nunca aquí.
class ManageBarbershopsView extends StatefulWidget {
  final bool adminControls;

  /// Filtro con el que abre la lista (solo admin): p. ej. las pendientes de
  /// aprobación, desde el aviso del dashboard.
  final AdminShopFilter? initialFilter;

  const ManageBarbershopsView({
    super.key,
    this.adminControls = false,
    this.initialFilter,
  });

  @override
  State<ManageBarbershopsView> createState() => _ManageBarbershopsViewState();
}

class _ManageBarbershopsViewState extends State<ManageBarbershopsView> {
  String _query = '';
  late AdminShopFilter? _filter = widget.initialFilter;

  String _filterLabel(AdminShopFilter filter) => switch (filter) {
    AdminShopFilter.pending => 'Pendientes',
    AdminShopFilter.ok => 'Al día',
    AdminShopFilter.dueSoon => 'Vence pronto',
    AdminShopFilter.grace => 'En gracia',
    AdminShopFilter.blocked => 'Bloqueadas',
  };

  bool _matchesFilter(Barbershop shop) {
    final filter = _filter;
    if (filter == null) return true;
    if (filter == AdminShopFilter.pending) {
      return shop.approvalStatus == BarbershopApprovalStatus.pending;
    }
    if (shop.approvalStatus != BarbershopApprovalStatus.approved) {
      return false;
    }
    final level = paymentInsight(shop).level;
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

  // ─── Acciones de admin ──────────────────────────────────────────────────

  void _showShopActions(
    BuildContext context,
    Barbershop shop,
    BarbershopRepository service,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ShopActionsSheet(
        shop: shop,
        insight: paymentInsight(shop),
        onApprove: () => _approve(context, service, shop),
        onReject: () => _confirmReject(context, service, shop),
        onViewInfo: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BarbershopDetailView(barbershopId: shop.id),
          ),
        ),
        onManage: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OwnerBarbershopManageView(barbershopId: shop.id),
          ),
        ),
        onToggleActive: () => _toggleActive(context, service, shop),
        onConfirmPayment: () => _confirmPaymentReceived(context, service, shop),
        onBlockForNonPayment: () => _blockForNonPayment(context, service, shop),
      ),
    );
  }

  Future<void> _approve(
    BuildContext context,
    BarbershopRepository service,
    Barbershop shop,
  ) async {
    try {
      await service.resolveApproval(shop.id, approve: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${shop.name}" aprobada'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo aprobar: $e')));
      }
    }
  }

  Future<void> _confirmReject(
    BuildContext context,
    BarbershopRepository service,
    Barbershop shop,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar barbería'),
        content: Text(
          '"${shop.name}" no aparecerá en el catálogo. Esta acción se puede revertir después.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, rechazar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await service.resolveApproval(shop.id, approve: false);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('"${shop.name}" rechazada')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo rechazar: $e')));
      }
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    BarbershopRepository service,
    Barbershop shop,
  ) async {
    try {
      await service.setActive(shop.id, !shop.active);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
      }
    }
  }

  Future<void> _confirmPaymentReceived(
    BuildContext context,
    BarbershopRepository service,
    Barbershop shop,
  ) async {
    try {
      await service.confirmPaymentReceived(shop.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pago confirmado. Mensualidad al día por 30 días más.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo confirmar el pago: $e')),
        );
      }
    }
  }

  Future<void> _blockForNonPayment(
    BuildContext context,
    BarbershopRepository service,
    Barbershop shop,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquear por impago'),
        content: Text(
          '"${shop.name}" y sus barberos quedarán bloqueados de inmediato y desaparecerán del catálogo hasta regularizar el pago.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, bloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await service.blockForNonPayment(shop.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${shop.name}" bloqueada por impago'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo bloquear: $e')));
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final service = context.read<BarbershopRepository>();
    // Catálogo del cliente (sin adminControls): solo barberías aprobadas y
    // activas (spec 12.1/12.6) — el admin sí ve todas, incluidas las
    // pendientes de revisión.
    final stream = widget.adminControls
        ? service.watchAll()
        : service.watchApproved();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.adminControls ? 'Gestión de barberías' : 'Barberías',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar barberías...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            if (widget.adminControls) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'Todas',
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    for (final filter in AdminShopFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FilterChip(
                          label: _filterLabel(filter),
                          selected: _filter == filter,
                          onTap: () => setState(() => _filter = filter),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<Barbershop>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const ErrorState(
                      title: 'No pudimos cargar las barberías',
                      subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ShimmerList();
                  }
                  var shops = snapshot.data ?? [];
                  if (_query.isNotEmpty) {
                    shops = shops
                        .where((s) => s.name.toLowerCase().contains(_query))
                        .toList();
                  }
                  if (widget.adminControls) {
                    shops = shops.where(_matchesFilter).toList();
                  }
                  if (shops.isEmpty) {
                    return const EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Sin barberías todavía',
                      subtitle:
                          'Cuando se registre una barbería aparecerá aquí.',
                    );
                  }
                  return ListView.separated(
                    itemCount: shops.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final shop = shops[index];
                      return PressableScale(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                BarbershopDetailView(barbershopId: shop.id),
                          ),
                        ),
                        child: Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          elevation: 1,
                          shadowColor: AppColors.textPrimary.withValues(
                            alpha: 0.08,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    BarbershopDetailView(barbershopId: shop.id),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                      image: shop.photoUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                shop.photoUrl!,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: shop.photoUrl == null
                                        ? const Icon(
                                            Icons.storefront,
                                            color: AppColors.onColor,
                                            size: 22,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          shop.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          shop.address ?? '',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (widget.adminControls) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              ApprovalStatusBadge(
                                                status: shop.approvalStatus,
                                              ),
                                              if (shop.approvalStatus ==
                                                  BarbershopApprovalStatus
                                                      .approved)
                                                StatusBadge(
                                                  label: paymentInsight(shop)
                                                      .label,
                                                  color: paymentInsight(shop)
                                                      .color,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (widget.adminControls)
                                    _ActionMenuButton(
                                      onTap: () => _showShopActions(
                                        context,
                                        shop,
                                        service,
                                      ),
                                    )
                                  else
                                    StatusBadge.active(shop.active),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? AppColors.onColor : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: AppColors.border),
    );
  }
}

// ─── Botón de acciones (menú "...") ────────────────────────────────────────

class _ActionMenuButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _ActionMenuButton({this.onTap});

  @override
  State<_ActionMenuButton> createState() => _ActionMenuButtonState();
}

class _ActionMenuButtonState extends State<_ActionMenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.more_vert_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ─── Modal de acciones de la barbería ───────────────────────────────────────

class _ShopActionsSheet extends StatelessWidget {
  final Barbershop shop;
  final PaymentInsight insight;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewInfo;
  final VoidCallback onManage;
  final VoidCallback onToggleActive;
  final VoidCallback onConfirmPayment;
  final VoidCallback onBlockForNonPayment;

  const _ShopActionsSheet({
    required this.shop,
    required this.insight,
    required this.onApprove,
    required this.onReject,
    required this.onViewInfo,
    required this.onManage,
    required this.onToggleActive,
    required this.onConfirmPayment,
    required this.onBlockForNonPayment,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = shop.approvalStatus == BarbershopApprovalStatus.pending;
    final isApproved = shop.approvalStatus == BarbershopApprovalStatus.approved;
    final canReconsider =
        isPending || shop.approvalStatus == BarbershopApprovalStatus.rejected;

    final actions = <_SheetAction>[
      if (canReconsider)
        _SheetAction(
          icon: Icons.check_circle_outline_rounded,
          label: 'Aprobar barbería',
          subtitle: 'Aparecerá en el catálogo de clientes',
          color: AppColors.success,
          onTap: () {
            Navigator.of(context).pop();
            onApprove();
          },
        ),
      if (isPending)
        _SheetAction(
          icon: Icons.close_rounded,
          label: 'Rechazar barbería',
          subtitle: 'No aparecerá en el catálogo',
          color: AppColors.error,
          onTap: () {
            Navigator.of(context).pop();
            onReject();
          },
          isDestructive: true,
        ),
      _SheetAction(
        icon: Icons.info_outline_rounded,
        label: 'Ver información completa',
        subtitle: 'Datos, horario y calificación',
        color: AppColors.accent,
        onTap: () {
          Navigator.of(context).pop();
          onViewInfo();
        },
      ),
      _SheetAction(
        icon: Icons.tune_rounded,
        label: 'Gestionar barbería',
        subtitle: 'Datos, barberos, servicios, productos y citas',
        color: AppColors.primary,
        onTap: () {
          Navigator.of(context).pop();
          onManage();
        },
      ),
      if (isApproved) ...[
        _SheetAction(
          icon: shop.active
              ? Icons.block_rounded
              : Icons.check_circle_outline_rounded,
          label: shop.active ? 'Desactivar barbería' : 'Activar barbería',
          subtitle: shop.active
              ? 'Desaparece del catálogo de clientes'
              : 'Vuelve a ser visible en el catálogo',
          color: shop.active ? AppColors.warning : AppColors.success,
          onTap: () {
            Navigator.of(context).pop();
            onToggleActive();
          },
        ),
        if (shop.paymentStatus != PaymentStatus.ok)
          _SheetAction(
            icon: Icons.payments_outlined,
            label: 'Confirmar pago recibido',
            subtitle: 'Marca la mensualidad al día y renueva el ciclo 30 días',
            color: AppColors.success,
            onTap: () {
              Navigator.of(context).pop();
              onConfirmPayment();
            },
          ),
        if (shop.paymentStatus != PaymentStatus.blocked)
          _SheetAction(
            icon: Icons.lock_outline_rounded,
            label: 'Bloquear por impago',
            subtitle:
                'Bloquea la barbería de inmediato y la oculta del catálogo',
            color: AppColors.error,
            onTap: () {
              Navigator.of(context).pop();
              onBlockForNonPayment();
            },
            isDestructive: true,
          ),
      ],
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Perfil de la barbería
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  image: shop.photoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(shop.photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: shop.photoUrl == null
                    ? const Icon(Icons.storefront, color: AppColors.onColor)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((shop.address ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        shop.address!,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ApprovalStatusBadge(status: shop.approvalStatus),
                        if (isApproved)
                          StatusBadge(
                            label: insight.label,
                            color: insight.color,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isApproved && insight.detail != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: insight.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: insight.color.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: insight.color,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      insight.detail!,
                      style: TextStyle(
                        fontSize: 12,
                        color: insight.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),

          for (final action in actions) _SheetActionTile(action: action),
        ],
      ),
    );
  }
}

// ─── Datos y tile de acción ─────────────────────────────────────────────────

class _SheetAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
  });
}

class _SheetActionTile extends StatefulWidget {
  final _SheetAction action;
  const _SheetActionTile({required this.action});

  @override
  State<_SheetActionTile> createState() => _SheetActionTileState();
}

class _SheetActionTileState extends State<_SheetActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        a.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _pressed
              ? a.color.withValues(alpha: 0.1)
              : a.color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _pressed
                ? a.color.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: a.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(a.icon, color: a.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: a.isDestructive ? a.color : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    a.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
