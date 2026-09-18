import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../product/manage_products_view.dart';
import '../widgets/empty_state.dart';

/// Resuelve la barbería del dueño autenticado y muestra sus productos —
/// mismo patrón que OwnerServicesTab.
class OwnerProductsTab extends StatelessWidget {
  const OwnerProductsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final barbershopService = context.read<BarbershopRepository>();

    return StreamBuilder<List<Barbershop>>(
      stream: profile == null ? const Stream<List<Barbershop>>.empty() : barbershopService.watchByOwner(profile.uid),
      builder: (context, snapshot) {
        final shops = snapshot.data ?? [];
        if (shops.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Productos')),
            body: const Center(
              child: EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Registra tu barbería primero',
                subtitle: 'Desde la pestaña Inicio puedes registrar los datos básicos.',
              ),
            ),
          );
        }
        return ManageProductsView(barbershopId: shops.first.id, canManage: true);
      },
    );
  }
}
