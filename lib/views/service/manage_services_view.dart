import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../theme/app_tokens.dart';
import '../widgets/catalog_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/responsive_body.dart';
import '../widgets/shimmer_box.dart';
import 'service_form_sheet.dart';

/// Catálogo de servicios de una barbería. Con [canManage] (dueño) se agregan,
/// editan, eliminan y ocultan; sin él (cliente o barbero) solo se consultan.
class ManageServicesView extends StatelessWidget {
  final String barbershopId;
  final bool canManage;

  const ManageServicesView({
    super.key,
    required this.barbershopId,
    this.canManage = false,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ServiceRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () =>
                  showServiceForm(context, barbershopId: barbershopId),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo servicio'),
            )
          : null,
      body: StreamBuilder<List<Service>>(
        stream: repo.watchByBarbershop(barbershopId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: ErrorState(title: 'No pudimos cargar los servicios'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: ShimmerList(),
            );
          }
          final services = [
            for (final s in snapshot.data ?? const <Service>[])
              if (canManage || s.active) s,
          ];
          if (services.isEmpty) {
            return Center(
              child: EmptyState(
                icon: Icons.content_cut,
                title: 'Sin servicios todavía',
                subtitle: canManage
                    ? 'Añade cortes, barba u otros servicios con precio, duración y foto.'
                    : 'Esta barbería aún no publicó servicios.',
                actionLabel: canManage ? 'Nuevo servicio' : null,
                onAction: canManage
                    ? () => showServiceForm(context, barbershopId: barbershopId)
                    : null,
              ),
            );
          }
          return ResponsiveBody(
            maxWidth: AppLayout.formWidth,
            child: ListView.separated(
              padding: EdgeInsets.only(
                top: AppSpace.lg,
                bottom: canManage ? 96 : AppSpace.xl,
              ),
              itemCount: services.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
              itemBuilder: (context, index) {
                final service = services[index];
                return CatalogTile(
                  name: service.name,
                  detail:
                      '${service.durationMinutes} min'
                      '${(service.description ?? '').isEmpty ? '' : ' · ${service.description}'}',
                  priceLabel: formatCop(service.price),
                  photoUrl: service.photoUrl,
                  fallbackIcon: Icons.content_cut,
                  active: service.active,
                  onActiveChanged: canManage
                      ? (value) =>
                            repo.setActive(barbershopId, service.id, value)
                      : null,
                  onTap: canManage
                      ? () => showServiceForm(
                          context,
                          barbershopId: barbershopId,
                          service: service,
                        )
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
