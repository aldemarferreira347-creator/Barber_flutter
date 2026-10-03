import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/notification_tone.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/choice_tile.dart';
import '../widgets/responsive_body.dart';

/// Paso obligatorio del primer inicio de sesión (spec 3.5): el usuario debe
/// elegir un tono antes de entrar a la app. AuthGate es quien decide cuándo
/// mostrar esta vista (mientras `profile.notificationTone == null`).
class ChooseNotificationToneView extends StatefulWidget {
  const ChooseNotificationToneView({super.key});

  @override
  State<ChooseNotificationToneView> createState() =>
      _ChooseNotificationToneViewState();
}

class _ChooseNotificationToneViewState
    extends State<ChooseNotificationToneView> {
  NotificationTone? _selected;
  bool _saving = false;

  Future<void> _confirm() async {
    final tone = _selected;
    if (tone == null) return;
    setState(() => _saving = true);
    final ok = await context.read<AuthController>().chooseNotificationTone(
      tone,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      final error =
          context.read<AuthController>().errorMessage ??
          'No se pudo guardar tu preferencia';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: AppLayout.formWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpace.md),
              Semantics(
                header: true,
                child: Text(
                  '¿Cómo prefieres que te hablemos?',
                  style: text.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                'Elige el tono de tus notificaciones. Puedes cambiarlo cuando quieras desde tu perfil.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              Expanded(
                child: ListView(
                  children: [
                    for (final tone in NotificationTone.values)
                      ChoiceTile(
                        selected: tone == _selected,
                        title: tone.label,
                        onTap: () => setState(() => _selected = tone),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.md),
              AppButton(
                onPressed: _selected == null || _saving ? null : _confirm,
                icon: Icons.arrow_forward,
                loading: _saving,
                child: const Text('Continuar'),
              ),
              const SizedBox(height: AppSpace.md),
            ],
          ),
        ),
      ),
    );
  }
}
