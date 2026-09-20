import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/notification_tone.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../widgets/action_list_tile.dart';

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
          ),
          const SizedBox(height: 18),
          ActionListTile(
            icon: Icons.tune,
            label: 'Tono de notificaciones',
            onTap: () => _showToneDialog(context),
          ),
          const SizedBox(height: 10),
          Consumer<ThemeController>(
            builder: (context, themeController, _) => Material(
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
                      onChanged: (value) => themeController.setDark(value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items) ...[
            ActionListTile(
              icon: item.icon,
              label: item.label,
              onTap: item.onTap,
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
          ),
        ],
      ),
    );
  }
}
