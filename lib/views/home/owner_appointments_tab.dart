import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../models/barbershop.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/staff_appointment_card.dart';

/// "Mis citas" del Dueño: las citas que sus clientes agendaron en SUS
/// barberías (no las que él mismo reserva como cliente — esas están en
/// Más → Mis reservas). Con varias barberías se puede filtrar por una.
class OwnerAppointmentsTab extends StatefulWidget {
  const OwnerAppointmentsTab({super.key});

  @override
  State<OwnerAppointmentsTab> createState() => _OwnerAppointmentsTabState();
}

class _OwnerAppointmentsTabState extends State<OwnerAppointmentsTab> {
  /// null = todas las barberías.
  String? _shopId;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final barbershopService = context.read<BarbershopRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis citas')),
      body: StreamBuilder<List<Barbershop>>(
        stream: profile == null
            ? const Stream<List<Barbershop>>.empty()
            : barbershopService.watchByOwner(profile.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: ErrorState(
                title: 'No pudimos cargar tus barberías',
                subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: ShimmerList(),
            );
          }
          final shops = snapshot.data!;
          if (shops.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Aún no tienes barberías',
                subtitle: 'Cuando registres una, aquí verás las citas que agenden tus clientes.',
              ),
            );
          }
          final selected = shops.any((s) => s.id == _shopId) ? _shopId : null;
          final ids = [
            for (final s in shops)
              if (selected == null || s.id == selected) s.id,
          ];
          final names = {for (final s in shops) s.id: s.name};

          return Column(
            children: [
              if (shops.length > 1)
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    children: [
                      _ShopChip(
                        label: 'Todas',
                        selected: selected == null,
                        onTap: () => setState(() => _shopId = null),
                      ),
                      for (final shop in shops)
                        _ShopChip(
                          label: shop.name,
                          selected: selected == shop.id,
                          onTap: () => setState(() => _shopId = shop.id),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: _AppointmentsList(
                  // La clave fuerza a reabrir el stream al cambiar de filtro.
                  key: ValueKey(ids.join(',')),
                  barbershopIds: ids,
                  shopNames: names,
                  showShopName: shops.length > 1,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppointmentsList extends StatefulWidget {
  final List<String> barbershopIds;
  final Map<String, String> shopNames;
  final bool showShopName;

  const _AppointmentsList({
    super.key,
    required this.barbershopIds,
    required this.shopNames,
    required this.showShopName,
  });

  @override
  State<_AppointmentsList> createState() => _AppointmentsListState();
}

class _AppointmentsListState extends State<_AppointmentsList> {
  // Se abre una sola vez por filtro (la `key` del padre recrea este estado al
  // cambiarlo): reconstruir la pantalla no reabre N listeners.
  late final Stream<List<Appointment>> _stream = context
      .read<AppointmentRepository>()
      .watchByBarbershops(widget.barbershopIds);

  @override
  Widget build(BuildContext context) {
    final shopNames = widget.shopNames;
    final showShopName = widget.showShopName;
    return StreamBuilder<List<Appointment>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: ErrorState(title: 'No pudimos cargar las citas'),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: ShimmerList(),
          );
        }
        final appointments = snapshot.data!;
        if (appointments.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Sin citas todavía',
              subtitle: 'Aquí verás las citas agendadas en tus barberías.',
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final appointment = appointments[index];
            final shopName = shopNames[appointment.barbershopId];
            return StaffAppointmentCard(
              appointment: appointment,
              subtitle:
                  '${appointment.clientName} con ${appointment.barberName}'
                  '${showShopName && shopName != null ? ' · $shopName' : ''}',
            );
          },
        );
      },
    );
  }
}

class _ShopChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ShopChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.accent.withValues(alpha: 0.18),
      ),
    );
  }
}
