import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';
import 'add_barbershop_view.dart';
import 'barbershop_detail_view.dart';

/// Lista de barberías. Con [ownerId] solo muestra las de ese dueño; sin él,
/// muestra todas (uso de admin/cliente). [canAdd] controla el FAB.
class ManageBarbershopsView extends StatefulWidget {
  final String? ownerId;
  final bool canAdd;
  final bool adminControls;

  const ManageBarbershopsView({super.key, this.ownerId, this.canAdd = false, this.adminControls = false});

  @override
  State<ManageBarbershopsView> createState() => _ManageBarbershopsViewState();
}

class _ManageBarbershopsViewState extends State<ManageBarbershopsView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final service = context.read<BarbershopRepository>();
    // Catálogo del cliente (ni ownerId ni adminControls): solo barberías
    // aprobadas y activas (spec 12.1/12.6) — el admin sí ve todas, incluidas
    // las pendientes de revisión.
    final stream = widget.ownerId != null
        ? service.watchByOwner(widget.ownerId!)
        : widget.adminControls
        ? service.watchAll()
        : service.watchApproved();

    return Scaffold(
      appBar: AppBar(title: const Text('Barberías')),
      floatingActionButton: widget.canAdd
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddBarbershopView())),
              child: const Icon(Icons.add),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(hintText: 'Buscar barberías...', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<Barbershop>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var shops = snapshot.data ?? [];
                  if (_query.isNotEmpty) {
                    shops = shops.where((s) => s.name.toLowerCase().contains(_query)).toList();
                  }
                  if (shops.isEmpty) {
                    return const EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Sin barberías todavía',
                      subtitle: 'Cuando se registre una barbería aparecerá aquí.',
                    );
                  }
                  return ListView.separated(
                    itemCount: shops.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final shop = shops[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () =>
                            Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => BarbershopDetailView(barbershopId: shop.id))),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                  image: shop.photoUrl != null
                                      ? DecorationImage(image: NetworkImage(shop.photoUrl!), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: shop.photoUrl == null
                                    ? const Icon(Icons.storefront, color: Colors.white, size: 22)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(
                                      shop.address ?? '',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.adminControls)
                                _AdminShopControls(shop: shop, service: service)
                              else if (widget.ownerId != null)
                                _ApprovalStatusBadge(status: shop.approvalStatus)
                              else
                                StatusBadge.active(shop.active),
                            ],
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

class _ApprovalStatusBadge extends StatelessWidget {
  final BarbershopApprovalStatus status;

  const _ApprovalStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BarbershopApprovalStatus.pending => ('Pendiente', AppColors.warning),
      BarbershopApprovalStatus.approved => ('Aprobada', AppColors.success),
      BarbershopApprovalStatus.rejected => ('Rechazada', AppColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Panel del admin (spec 12.4): aprueba/rechaza solicitudes pendientes; ya
/// aprobada, controla el bloqueo/desbloqueo general como antes.
class _AdminShopControls extends StatelessWidget {
  final Barbershop shop;
  final BarbershopRepository service;

  const _AdminShopControls({required this.shop, required this.service});

  @override
  Widget build(BuildContext context) {
    if (shop.approvalStatus == BarbershopApprovalStatus.pending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Rechazar',
            icon: const Icon(Icons.close, color: AppColors.error),
            onPressed: () => service.resolveApproval(shop.id, approve: false),
          ),
          IconButton(
            tooltip: 'Aprobar',
            icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
            onPressed: () => service.resolveApproval(shop.id, approve: true),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _ApprovalStatusBadge(status: shop.approvalStatus),
        if (shop.approvalStatus == BarbershopApprovalStatus.approved)
          Switch(value: shop.active, onChanged: (value) => service.setActive(shop.id, value)),
      ],
    );
  }
}
