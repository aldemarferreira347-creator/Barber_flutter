import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/notification_tone.dart';
import '../../theme/app_colors.dart';
import '../widgets/gradient_button.dart';

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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                    '¿Cómo prefieres que te hablemos?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  )
                  .animate()
                  .fadeIn(duration: 320.ms)
                  .slideY(begin: -0.08, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),
              Text(
                'Elige el tono de tus notificaciones. Puedes cambiarlo cuando quieras desde tu perfil.',
                style: TextStyle(color: AppColors.textSecondary),
              ).animate(delay: 80.ms).fadeIn(duration: 300.ms),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: NotificationTone.values.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tone = NotificationTone.values[index];
                    final selected = tone == _selected;
                    return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _selected = tone),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.accent.withValues(alpha: 0.08)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.border,
                                width: selected ? 2 : 1,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.accent.withValues(
                                          alpha: 0.15,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: selected
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  tone.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate(delay: (index * 60).ms)
                        .fadeIn(duration: 300.ms)
                        .slideX(
                          begin: 0.08,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        );
                  },
                ),
              ),
              const SizedBox(height: 12),
              GradientButton(
                onPressed: _selected == null || _saving ? null : _confirm,
                icon: _saving ? null : Icons.arrow_forward,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
