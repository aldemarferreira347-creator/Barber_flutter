import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../barber/manage_barbers_view.dart';
import '../barbershop/add_barbershop_view.dart';
import '../barbershop/barbershop_detail_view.dart';
import '../barbershop/edit_schedule_view.dart';
import '../service/manage_services_view.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';

class OwnerDashboardTab extends StatelessWidget {
  const OwnerDashboardTab({super.key});

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature próximamente')));
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final barbershopService = context.read<BarbershopRepository>();
    final greetingName = profile?.firstName.isNotEmpty == true ? profile!.firstName : 'Dueño';

    return Scaffold(
      appBar: AppBar(title: Text('Hola, $greetingName 👋')),
      body: StreamBuilder<List<Barbershop>>(
        stream: profile == null ? const Stream<List<Barbershop>>.empty() : barbershopService.watchByOwner(profile.uid),
        builder: (context, snapshot) {
          final shops = snapshot.data ?? [];
          final shop = shops.isNotEmpty ? shops.first : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Tu barbería en buenas manos', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              if (shop == null)
                Column(
                  children: [
                    const EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Aún no tienes una barbería',
                      subtitle: 'Registra los datos básicos para empezar a gestionarla.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddBarbershopView())),
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar barbería'),
                    ),
                  ],
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.storefront, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mi barbería', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      StatusBadge.active(shop.active),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ActionListTile(
                  icon: Icons.info_outline,
                  label: 'Ver información',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BarbershopDetailView(barbershopId: shop.id))),
                ),
                const SizedBox(height: 10),
                ActionListTile(
                  icon: Icons.content_cut,
                  label: 'Gestionar barberos',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManageBarbersView(barbershopId: shop.id))),
                ),
                const SizedBox(height: 10),
                ActionListTile(
                  icon: Icons.design_services_outlined,
                  label: 'Gestionar servicios',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManageServicesView(barbershopId: shop.id, canManage: true))),
                ),
                const SizedBox(height: 10),
                ActionListTile(
                  icon: Icons.schedule_outlined,
                  label: 'Horarios de atención',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EditScheduleView(barbershopId: shop.id, initialSchedule: shop.schedule),
                  )),
                ),
                const SizedBox(height: 10),
                ActionListTile(icon: Icons.bar_chart_outlined, label: 'Ver estadísticas', onTap: () => _comingSoon(context, 'Las estadísticas')),
              ],
            ],
          );
        },
      ),
    );
  }
}
