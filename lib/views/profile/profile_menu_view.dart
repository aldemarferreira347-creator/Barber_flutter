import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/notification_tone.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/brand_mark.dart';

class ProfileMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const ProfileMenuItem({required this.icon, required this.label, this.onTap});
}

/// Pantalla de perfil/menú reutilizada por los 4 roles con distintos items.
class ProfileMenuView extends StatelessWidget {
  final List<ProfileMenuItem> items;

  const ProfileMenuView({super.key, required this.items});

  String _roleLabel(UserRole role) => switch (role) {
    UserRole.admin => 'Administrador',
    UserRole.owner => 'Dueño',
    UserRole.barber => 'Barbero',
    UserRole.client => 'Cliente',
  };

  Future<void> _showToneDialog(BuildContext context) async {
    final authController = context.read<AuthController>();
    final current = authController.profile?.notificationTone;
    final tone = await showDialog<NotificationTone>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Tono de notificaciones'),
        children: [
          for (final option in NotificationTone.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(option),
              child: Row(
                children: [
                  Icon(
                    option == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: option == current
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(option.label),
                ],
              ),
            ),
        ],
      ),
    );
    if (tone == null || tone == current || !context.mounted) return;
    final ok = await authController.chooseNotificationTone(tone);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authController.errorMessage ?? 'No se pudo actualizar el tono',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final initials = (profile?.name.isNotEmpty ?? false)
        ? profile!.name
              .trim()
              .split(RegExp(r'\s+'))
              .map((p) => p[0])
              .take(2)
              .join()
              .toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile?.email ?? '',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rol: ${_roleLabel(profile?.role ?? UserRole.client)}',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 320.ms)
              .slideY(begin: -0.06, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 18),
          ActionListTile(
            icon: Icons.tune,
            label: 'Tono de notificaciones',
            animationIndex: 0,
            onTap: () => _showToneDialog(context),
          ),
          const SizedBox(height: 10),
          Consumer<ThemeController>(
            builder: (context, themeController, _) =>
                Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.dark_mode_outlined,
                                color: AppColors.accent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Modo oscuro',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Switch(
                              value: themeController.isDark,
                              onChanged: (value) =>
                                  themeController.setDark(value),
                            ),
                          ],
                        ),
                      ),
                    )
                    .animate(delay: 60.ms)
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
          ),
          const SizedBox(height: 10),
          for (final entry in items.indexed) ...[
            ActionListTile(
              icon: entry.$2.icon,
              label: entry.$2.label,
              animationIndex: entry.$1 + 2,
              onTap: entry.$2.onTap,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.read<AuthController>().signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
          const SizedBox(height: 28),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandMark(
                  size: 32,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  spin: false,
                ),
                const SizedBox(height: 6),
                Text(
                  'BarberFlow v1.0.0',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ).animate(delay: 250.ms).fadeIn(duration: 300.ms),
        ],
      ),
    );
  }
}
