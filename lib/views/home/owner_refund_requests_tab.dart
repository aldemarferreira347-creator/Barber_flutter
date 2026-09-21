import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../appointment/refund_requests_view.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';

/// Resuelve la barbería del dueño autenticado y muestra sus solicitudes de
/// reembolso — mismo patrón que OwnerServicesTab/OwnerProductsTab.
class OwnerRefundRequestsTab extends StatelessWidget {
  const OwnerRefundRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final barbershopService = context.read<BarbershopRepository>();

    return StreamBuilder<List<Barbershop>>(
      stream: profile == null
          ? const Stream<List<Barbershop>>.empty()
          : barbershopService.watchByOwner(profile.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Solicitudes de reembolso')),
            body: const Center(
              child: ErrorState(
                title: 'No pudimos cargar tu barbería',
                subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
              ),
            ),
          );
        }
        final shops = snapshot.data ?? [];
        if (shops.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Solicitudes de reembolso')),
            body: const Center(
              child: EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Registra tu barbería primero',
                subtitle: 'Desde la pestaña Inicio puedes registrar los datos básicos.',
              ),
            ),
          );
        }
        return RefundRequestsView(barbershopId: shops.first.id);
      },
    );
  }
}
