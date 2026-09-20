import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/empty_state.dart';

class ManageBarbersView extends StatelessWidget {
  final String barbershopId;

  const ManageBarbersView({super.key, required this.barbershopId});

  Future<void> _hireBarber(BuildContext context) async {
    final repo = context.read<UserRepository>();
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contratar barbero'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Escribe el correo de un cliente ya registrado en BarberFlow para contratarlo como barbero de tu barbería.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo del barbero', prefixIcon: Icon(Icons.mail_outline)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Buscar')),
        ],
      ),
    );
    if (email == null || email.isEmpty || !context.mounted) return;

    try {
      final user = await repo.findByEmail(email);
      if (!context.mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No existe ninguna cuenta con ese correo. Pídele que se registre primero como cliente.'),
          ),
        );
        return;
      }
      if (user.role != UserRole.client) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name.isEmpty ? user.email : user.name} ya tiene otro rol y no se puede contratar.'),
          ),
        );
        return;
      }
      await repo.hireAsBarber(uid: user.uid, barbershopId: barbershopId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${user.name} ahora es barbero de tu barbería.')));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo contratar: $e')));
      }
    }
  }

  Future<void> _release(BuildContext context, AppUser barber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dar de baja'),
        content: Text('¿Quitar a ${barber.name} como barbero de tu barbería? Volverá a ser cliente.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Dar de baja')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<UserRepository>().releaseFromBarbershop(barber.uid);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo dar de baja: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<UserRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Barberos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _hireBarber(context),
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: repo.watchBarbersByBarbershop(barbershopId),
        builder: (context, snapshot) {
          final barbers = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (barbers.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.content_cut,
                title: 'Sin barberos todavía',
                subtitle: 'Contrata a un cliente ya registrado para que trabaje en tu barbería.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: barbers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final barber = barbers[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text(
                        barber.initials,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(barber.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(barber.email, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => _release(context, barber), child: const Text('Dar de baja')),
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
