import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../models/user_role.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../appointment/owner_appointments_view.dart';
import '../appointment/refund_requests_view.dart';
import '../barber/manage_barbers_view.dart';
import '../product/manage_products_view.dart';
import '../service/manage_services_view.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_box.dart';
import 'approval_status_badge.dart';
import 'barbershop_detail_view.dart';
import 'barbershop_reviews_view.dart';
import 'close_shop_view.dart';
import 'edit_barbershop_view.dart';
import 'edit_schedule_view.dart';
import 'payment_insight.dart';

/// Panel de gestión de UNA barbería: revisar sus datos, editarlos y entrar a
/// sus barberos, servicios, productos, horario, citas, reseñas, reembolsos y
/// cierre por evento externo.
///
/// Solo abre para el dueño de esa barbería o para el admin (que tiene acceso
/// a todo); para cualquier otra persona muestra que no tiene permiso, sin
/// importar cómo llegó hasta aquí. Es solo la capa de interfaz: la barrera
/// real es firestore.rules, que exige `ownerId == uid` en cada escritura.
class OwnerBarbershopManageView extends StatelessWidget {
  final String barbershopId;

  const OwnerBarbershopManageView({super.key, required this.barbershopId});

  String _paymentLabel(PaymentStatus status) => switch (status) {
    PaymentStatus.ok => 'Mensualidad al día',
    PaymentStatus.overdue => 'En mora',
    PaymentStatus.blocked => 'Bloqueada',
  };

  Color _paymentColor(PaymentStatus status) => switch (status) {
    PaymentStatus.ok => AppColors.success,
    PaymentStatus.overdue => AppColors.warning,
    PaymentStatus.blocked => AppColors.error,
  };

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _cancelSubscription(
    BuildContext context,
    BarbershopRepository repo,
    String shopId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar membresía'),
        content: const Text(
          'Tu barbería se bloqueará de inmediato, sin período de gracia. Las citas ya pagadas dentro del período vigente no se ven afectadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await repo.cancelSubscription(shopId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo cancelar: $e')));
      }
    }
  }

  Future<void> _paySubscription(
    BuildContext context,
    BarbershopRepository repo,
    String shopId,
  ) async {
    try {
      await repo.paySubscription(shopId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensualidad pagada. ¡Gracias!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo iniciar el pago: $e')),
        );
      }
    }
  }

  /// Espejo de la regla de borrado de firestore.rules: una barbería viva
  /// (aprobada y con mensualidad vigente) no se borra — primero se cancela la
  /// membresía, que la bloquea; una pendiente o rechazada sí se borra directo.
  static bool canDelete(Barbershop shop) =>
      shop.approvalStatus != BarbershopApprovalStatus.approved ||
      shop.paymentStatus == PaymentStatus.blocked;

  Future<void> _delete(
    BuildContext context,
    BarbershopRepository repo,
    Barbershop shop,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!canDelete(shop)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Esta barbería está activa. Cancela primero la membresía para poder eliminarla.',
          ),
        ),
      );
      return;
    }
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar barbería'),
        content: Text(
          '¿Eliminar "${shop.name}" definitivamente? No se puede deshacer y sus barberos, servicios y productos dejarán de ser accesibles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repo.delete(shop.id);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('"${shop.name}" fue eliminada')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<BarbershopRepository>();
    final profile = context.watch<AuthController>().profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar barbería')),
      body: StreamBuilder<Barbershop?>(
        stream: repo.watchOne(barbershopId),
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
              padding: EdgeInsets.all(16),
              child: ShimmerList(count: 4, itemHeight: 64),
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
          final canManage =
              profile != null &&
              (profile.role == UserRole.admin || shop.ownerId == profile.uid);
          if (!canManage) {
            return const Center(
              child: ErrorState(
                title: 'No puedes gestionar esta barbería',
                subtitle: 'Solo su dueño o el administrador pueden hacerlo.',
              ),
            );
          }
          final approved =
              shop.approvalStatus == BarbershopApprovalStatus.approved;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(shop: shop),
              const SizedBox(height: 12),
              for (final alert in shopAlerts(shop))
                ShopAlertBanner(
                  alert: alert,
                  // Toda alerta de una barbería aprobada es de mensualidad.
                  actionLabel: approved
                      ? 'Pagar ${formatCop(kBarbershopMonthlyFee)}'
                      : null,
                  onAction: approved
                      ? () => _paySubscription(context, repo, shop.id)
                      : null,
                ),
              if (approved) ...[
                ActionListTile(
                  icon: Icons.shield_outlined,
                  label: _paymentLabel(shop.paymentStatus),
                  subtitle: shop.paymentDueDate != null
                      ? 'Vence el ${shop.paymentDueDate!.day}/${shop.paymentDueDate!.month}/${shop.paymentDueDate!.year}'
                      : null,
                  iconColor: _paymentColor(shop.paymentStatus),
                  trailing: shop.paymentStatus == PaymentStatus.ok
                      ? TextButton(
                          onPressed: () =>
                              _cancelSubscription(context, repo, shop.id),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : FilledButton(
                          onPressed: () =>
                              _paySubscription(context, repo, shop.id),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(
                            'Pagar ${formatCop(kBarbershopMonthlyFee)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                ),
                const SizedBox(height: 10),
              ],
              ActionListTile(
                icon: Icons.info_outline,
                label: 'Ver información',
                subtitle: 'Cómo la ven tus clientes',
                onTap: () =>
                    _push(context, BarbershopDetailView(barbershopId: shop.id)),
              ),
              const SizedBox(height: 10),
              ActionListTile(
                icon: Icons.edit_outlined,
                label: 'Editar datos',
                subtitle: 'Nombre, dirección, contacto, foto y ubicación',
                onTap: () => _push(context, EditBarbershopView(shop: shop)),
              ),
              const SizedBox(height: 10),
              ActionListTile(
                icon: Icons.schedule_outlined,
                label: 'Horarios de atención',
                onTap: () => _push(
                  context,
                  EditScheduleView(
                    barbershopId: shop.id,
                    initialSchedule: shop.schedule,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ActionListTile(
                icon: Icons.content_cut,
                label: 'Barberos',
                onTap: () =>
                    _push(context, ManageBarbersView(barbershopId: shop.id)),
              ),
              const SizedBox(height: 10),
              ActionListTile(
                icon: Icons.design_services_outlined,
                label: 'Servicios',
                onTap: () => _push(
                  context,
                  ManageServicesView(barbershopId: shop.id, canManage: true),
                ),
              ),
              const SizedBox(height: 10),
              ActionListTile(
                icon: Icons.shopping_bag_outlined,
                label: 'Productos',
                onTap: () => _push(
                  context,
                  ManageProductsView(barbershopId: shop.id, canManage: true),
                ),
              ),
              const SizedBox(height: 10),
              ActionListTile(
                icon: Icons.calendar_month_outlined,
                label: 'Citas de esta barbería',
                onTap: () => _push(
                  context,
                  OwnerAppointmentsView(barbershopId: shop.id),
                ),
              ),
              const SizedBox(height: 10),
              ActionListTile(
                icon: Icons.reviews_outlined,
                label: 'Reseñas',
                onTap: () => _push(
                  context,
                  BarbershopReviewsView(barbershopId: shop.id),
                ),
              ),
              const SizedBox(height: 10),
              ActionListTile(
                icon: Icons.receipt_long_outlined,
                label: 'Solicitudes de reembolso',
                onTap: () =>
                    _push(context, RefundRequestsView(barbershopId: shop.id)),
              ),
              const SizedBox(height: 10),
              ActionListTile(
                icon: Icons.storefront_outlined,
                label: 'Cerrar por evento externo',
                onTap: () =>
                    _push(context, CloseShopView(barbershopId: shop.id)),
              ),
              const SizedBox(height: 10),
              ActionListTile(
                icon: Icons.delete_outline,
                label: 'Eliminar barbería',
                subtitle: canDelete(shop)
                    ? 'Borra la barbería definitivamente'
                    : 'Primero cancela la membresía',
                iconColor: AppColors.error,
                onTap: () => _delete(context, repo, shop),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Barbershop shop;

  const _Header({required this.shop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
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
                ? const Icon(Icons.storefront, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if ((shop.address ?? '').isNotEmpty)
                  Text(
                    shop.address!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 6),
                ApprovalStatusBadge(status: shop.approvalStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
