import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../models/user_role.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../appointment/owner_appointments_view.dart';
import '../appointment/refund_requests_view.dart';
import '../barber/manage_barbers_view.dart';
import '../product/claim_purchase_view.dart';
import '../product/manage_products_view.dart';
import '../service/manage_services_view.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/error_state.dart';
import '../widgets/responsive_body.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/shop_avatar.dart';
import 'approval_status_badge.dart';
import 'barbershop_detail_view.dart';
import 'barbershop_reviews_view.dart';
import 'close_shop_view.dart';
import 'edit_barbershop_view.dart';
import 'edit_schedule_view.dart';
import 'payment_insight.dart';
import 'subscription_section.dart';
import '../../utils/error_text.dart';

/// Panel de gestión de UNA barbería: revisar sus datos, editarlos y entrar a
/// sus barberos, servicios, productos, horario, citas, compras, reseñas,
/// reembolsos y cierre por evento externo.
///
/// Solo abre para el dueño de esa barbería o para el admin (que tiene acceso
/// a todo); para cualquier otra persona muestra que no tiene permiso, sin
/// importar cómo llegó hasta aquí. Es solo la capa de interfaz: la barrera
/// real es firestore.rules, que exige `ownerId == uid` en cada escritura.
class OwnerBarbershopManageView extends StatelessWidget {
  final String barbershopId;

  const OwnerBarbershopManageView({super.key, required this.barbershopId});

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Eliminar barbería',
      message:
          '¿Eliminar "${shop.name}" definitivamente? No se puede deshacer y '
          'sus barberos, servicios y productos dejarán de ser accesibles.',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Volver',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await repo.delete(shop.id);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('"${shop.name}" fue eliminada')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: ${errorText(e)}')),
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
              padding: EdgeInsets.all(AppSpace.lg),
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

          Widget gap() => const SizedBox(height: AppSpace.sm);

          return ResponsiveBody(
            maxWidth: AppLayout.formWidth,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
              children: [
                _Header(shop: shop),
                const SizedBox(height: AppSpace.lg),
                if (approved)
                  SubscriptionSection(shop: shop)
                else
                  for (final alert in shopAlerts(shop))
                    ShopAlertBanner(alert: alert),
                const SizedBox(height: AppSpace.sm),
                const SectionHeader(title: 'Mi barbería'),
                ActionListTile(
                  icon: Icons.info_outline,
                  label: 'Ver información',
                  subtitle: 'Cómo la ven tus clientes',
                  onTap: () => _push(
                    context,
                    BarbershopDetailView(barbershopId: shop.id),
                  ),
                ),
                gap(),
                ActionListTile(
                  icon: Icons.edit_outlined,
                  label: 'Editar datos',
                  subtitle: 'Nombre, contacto, Nequi, foto y ubicación',
                  onTap: () => _push(context, EditBarbershopView(shop: shop)),
                ),
                gap(),
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
                const SizedBox(height: AppSpace.xl),
                const SectionHeader(title: 'Equipo y catálogo'),
                ActionListTile(
                  icon: Icons.content_cut,
                  label: 'Barberos',
                  onTap: () =>
                      _push(context, ManageBarbersView(barbershopId: shop.id)),
                ),
                gap(),
                ActionListTile(
                  icon: Icons.design_services_outlined,
                  label: 'Servicios',
                  onTap: () => _push(
                    context,
                    ManageServicesView(barbershopId: shop.id, canManage: true),
                  ),
                ),
                gap(),
                ActionListTile(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Productos',
                  onTap: () => _push(
                    context,
                    ManageProductsView(barbershopId: shop.id, canManage: true),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                const SectionHeader(title: 'Operación'),
                ActionListTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Citas de esta barbería',
                  subtitle: 'Confirma pagos Nequi y gestiona las citas',
                  onTap: () => _push(
                    context,
                    OwnerAppointmentsView(barbershopId: shop.id),
                  ),
                ),
                gap(),
                ActionListTile(
                  icon: Icons.qr_code,
                  label: 'Compras de productos',
                  subtitle: 'Confirma pagos y entrega con código',
                  onTap: () =>
                      _push(context, ClaimPurchaseView(barbershopId: shop.id)),
                ),
                gap(),
                ActionListTile(
                  icon: Icons.reviews_outlined,
                  label: 'Reseñas',
                  onTap: () => _push(
                    context,
                    BarbershopReviewsView(barbershopId: shop.id),
                  ),
                ),
                gap(),
                ActionListTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Solicitudes de reembolso',
                  onTap: () =>
                      _push(context, RefundRequestsView(barbershopId: shop.id)),
                ),
                gap(),
                ActionListTile(
                  icon: Icons.storefront_outlined,
                  label: 'Cerrar por evento externo',
                  onTap: () =>
                      _push(context, CloseShopView(barbershopId: shop.id)),
                ),
                const SizedBox(height: AppSpace.xl),
                const SectionHeader(title: 'Zona de riesgo'),
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
            ),
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
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          ShopAvatar(photoUrl: shop.photoUrl, name: shop.name, size: 56),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.name, style: text.titleMedium),
                if ((shop.address ?? '').isNotEmpty)
                  Text(shop.address!, style: text.bodySmall),
                const SizedBox(height: AppSpace.sm),
                ApprovalStatusBadge(status: shop.approvalStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
