import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/user_controller.dart';
import '../../repositories/barber_availability_repository.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';

/// El barbero marca si está disponible para recibir citas nuevas — "darse
/// de baja" temporalmente sin dejar la barbería (la gestión de horas
/// ocupadas puntuales queda para una fase futura con más datos de citas) —
/// y, por separado, marca su salida/regreso físico de la tienda (spec 3.3).
class BarberAvailabilityView extends StatelessWidget {
  const BarberAvailabilityView({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserController>().profile;
    final available = profile?.available ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Disponibilidad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                    color: (available ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    available
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    color: available ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        available
                            ? 'Disponible para citas nuevas'
                            : 'Dado de baja temporalmente',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        available
                            ? 'Los clientes pueden agendar contigo.'
                            : 'No aparecerás para que te agenden citas nuevas.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: available,
                  onChanged: profile == null
                      ? null
                      : (value) => context.read<UserRepository>().setAvailable(
                          profile.uid,
                          value,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (profile != null)
            _AwayControl(
              isAway: profile.isAway,
              awayUntilEstimate: profile.awayUntilEstimate,
            ),
        ],
      ),
    );
  }
}

/// Salida/regreso físico de la tienda: el límite para el aplazamiento
/// automático de reservas pagadas (spec 3.3) sale del propio estimado que
/// el barbero declara aquí — nunca un valor fijo igual para todos.
class _AwayControl extends StatefulWidget {
  final bool isAway;
  final DateTime? awayUntilEstimate;

  const _AwayControl({required this.isAway, required this.awayUntilEstimate});

  @override
  State<_AwayControl> createState() => _AwayControlState();
}

class _AwayControlState extends State<_AwayControl> {
  static const List<int> _presetMinutes = [15, 30, 45, 60, 90];

  int _selectedMinutes = 30;
  bool _busy = false;

  Future<void> _markAway() async {
    setState(() => _busy = true);
    try {
      await context.read<BarberAvailabilityRepository>().markAway(
        _selectedMinutes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo marcar la salida: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markReturned() async {
    setState(() => _busy = true);
    try {
      await context.read<BarberAvailabilityRepository>().markReturned();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo marcar el regreso: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: widget.isAway ? _buildAwayState() : _buildPresentState(),
    );
  }

  Widget _buildAwayState() {
    final estimate = widget.awayUntilEstimate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.directions_walk, color: AppColors.warning),
            SizedBox(width: 10),
            Text(
              'Estás fuera de la tienda',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          estimate == null
              ? 'Estimaste que volverías pronto.'
              : 'Estimaste volver antes de las ${estimate.hour.toString().padLeft(2, '0')}:${estimate.minute.toString().padLeft(2, '0')}.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          'Si no marcas tu regreso a tiempo, tus citas pagadas de hoy se aplazan automáticamente y se invita a tus clientes a reprogramar.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _markReturned,
          icon: const Icon(Icons.check),
          label: const Text('Marcar regreso'),
        ),
      ],
    );
  }

  Widget _buildPresentState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Vas a salir de la tienda?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Indica cuánto tiempo estimas que tardarás — de eso depende hasta cuándo tus clientes siguen esperándote con normalidad.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutes in _presetMinutes)
              ChoiceChip(
                label: Text('$minutes min'),
                selected: _selectedMinutes == minutes,
                onSelected: (_) => setState(() => _selectedMinutes = minutes),
              ),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _busy ? null : _markAway,
          icon: const Icon(Icons.directions_walk),
          label: const Text('Marcar salida'),
        ),
      ],
    );
  }
}
