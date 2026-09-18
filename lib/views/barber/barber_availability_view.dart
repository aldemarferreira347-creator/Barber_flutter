import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/user_controller.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';

/// El barbero marca si está disponible para recibir citas nuevas — "darse
/// de baja" temporalmente sin dejar la barbería (la gestión de horas
/// ocupadas puntuales queda para una fase futura con más datos de citas).
class BarberAvailabilityView extends StatelessWidget {
  const BarberAvailabilityView({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserController>().profile;
    final available = profile?.available ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Disponibilidad')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (available ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(available ? Icons.check_circle_outline : Icons.pause_circle_outline, color: available ? AppColors.success : AppColors.error),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(available ? 'Disponible para citas nuevas' : 'Dado de baja temporalmente', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          available ? 'Los clientes pueden agendar contigo.' : 'No aparecerás para que te agenden citas nuevas.',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: available,
                    onChanged: profile == null ? null : (value) => context.read<UserRepository>().setAvailable(profile.uid, value),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
