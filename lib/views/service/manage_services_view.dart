import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/empty_state.dart';
import 'add_service_view.dart';

/// Lista de servicios de una barbería. [canManage] controla si se puede
/// agregar/activar-desactivar (Dueño) o solo se muestran (Cliente).
class ManageServicesView extends StatelessWidget {
  final String barbershopId;
  final bool canManage;

  const ManageServicesView({super.key, required this.barbershopId, this.canManage = false});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ServiceRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => AddServiceView(barbershopId: barbershopId))),
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<Service>>(
        stream: repo.watchByBarbershop(barbershopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final services = snapshot.data ?? [];
          if (services.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.content_cut,
                title: 'Sin servicios todavía',
                subtitle: 'Añade cortes, coloración u otros servicios con precio y foto.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final service = services[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: service.photoUrl != null
                          ? Image.network(service.photoUrl!, width: 56, height: 56, fit: BoxFit.cover)
                          : Container(
                              width: 56,
                              height: 56,
                              color: AppColors.background,
                              child: const Icon(Icons.content_cut, color: AppColors.textSecondary),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(service.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            '${service.durationMinutes} min',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${service.price.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent),
                    ),
                    if (canManage)
                      Switch(
                        value: service.active,
                        onChanged: (value) => repo.setActive(barbershopId, service.id, value),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
