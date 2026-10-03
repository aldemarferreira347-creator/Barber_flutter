import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/user_controller.dart';
import '../../repositories/barber_availability_repository.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/responsive_body.dart';
import '../../utils/error_text.dart';

/// El barbero marca si está disponible para recibir citas nuevas — "darse
/// de baja" temporalmente sin dejar la barbería — y, por separado, avisa de
/// su salida/regreso físico de la tienda (spec 3.3): los clientes que van a
/// agendar ven que está fuera y a qué hora estima volver.
class BarberAvailabilityView extends StatelessWidget {
  const BarberAvailabilityView({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserController>().profile;
    final available = profile?.available ?? true;
    final text = Theme.of(context).textTheme;
    final tone = available ? AppColors.success : AppColors.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Disponibilidad')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          children: [
            ResponsiveBody(
              maxWidth: AppLayout.formWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpace.md),
                          decoration: BoxDecoration(
                            color: AppColors.tint(tone),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            available
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                            color: AppColors.readable(tone),
                          ),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                available
                                    ? 'Disponible para citas nuevas'
                                    : 'Dado de baja temporalmente',
                                style: text.titleSmall,
                              ),
                              Text(
                                available
                                    ? 'Los clientes pueden agendar contigo.'
                                    : 'No aparecerás para que te agenden citas nuevas.',
                                style: text.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: available,
                          onChanged: profile == null
                              ? null
                              : (value) => context
                                    .read<UserRepository>()
                                    .setAvailable(profile.uid, value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  if (profile != null)
                    _AwayControl(
                      isAway: profile.isAway,
                      awayUntilEstimate: profile.awayUntilEstimate,
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

/// Salida/regreso físico de la tienda. El barbero declara cuánto estima
/// tardar; mientras tanto el cliente lo ve como "fuera de la tienda" al
/// elegirlo para agendar.
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

  void _fail(String action, Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo $action: ${errorText(e)}')),
    );
  }

  Future<void> _markAway() async {
    try {
      await context.read<BarberAvailabilityRepository>().markAway(
        _selectedMinutes,
      );
    } catch (e) {
      _fail('marcar la salida', e);
    }
  }

  Future<void> _markReturned() async {
    try {
      await context.read<BarberAvailabilityRepository>().markReturned();
    } catch (e) {
      _fail('marcar el regreso', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: widget.isAway
          ? _buildAwayState(context)
          : _buildPresentState(context),
    );
  }

  Widget _buildAwayState(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: AppColors.textSecondary);
    final estimate = widget.awayUntilEstimate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.directions_walk,
              color: AppColors.readable(AppColors.warning),
            ),
            const SizedBox(width: AppSpace.sm),
            Text('Estás fuera de la tienda', style: text.titleSmall),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          estimate == null
              ? 'Estimaste volver pronto.'
              : 'Estimaste volver a las ${timeLabel(estimate)}.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          'Tus clientes ven que estás fuera y a qué hora vuelves cuando van '
          'a agendar contigo. Marca tu regreso apenas llegues.',
          style: muted,
        ),
        const SizedBox(height: AppSpace.lg),
        AppButton(
          onPressed: _markReturned,
          icon: Icons.check,
          child: const Text('Marcar regreso'),
        ),
      ],
    );
  }

  Widget _buildPresentState(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Vas a salir de la tienda?', style: text.titleSmall),
        const SizedBox(height: AppSpace.xs),
        Text(
          'Indica cuánto estimas tardar: tus clientes lo verán al agendar.',
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.md),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final minutes in _presetMinutes)
              ChoiceChip(
                label: Text('$minutes min'),
                selected: _selectedMinutes == minutes,
                onSelected: (_) => setState(() => _selectedMinutes = minutes),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        AppButton(
          variant: AppButtonVariant.secondary,
          onPressed: _markAway,
          icon: Icons.directions_walk,
          child: const Text('Marcar salida'),
        ),
      ],
    );
  }
}
