import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../barbershop/close_shop_view.dart';
import '../widgets/empty_state.dart';

/// Resuelve la barbería del dueño autenticado antes de abrir el cierre por
/// evento externo — mismo patrón que OwnerServicesTab/OwnerProductsTab.
class OwnerCloseShopTab extends StatelessWidget {
  const OwnerCloseShopTab({super.key});

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
            appBar: AppBar(title: const Text('Cerrar por evento externo')),
            body: const Center(
              child: EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Registra tu barbería primero',
                subtitle: 'Desde la pestaña Inicio puedes registrar los datos básicos.',
              ),
            ),
          );
        }
        return CloseShopView(barbershopId: shops.first.id);
      },
    );
  }
}
