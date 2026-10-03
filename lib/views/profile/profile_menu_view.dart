import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/notification_tone.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_controller.dart';
import '../../theme/app_tokens.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/brand_mark.dart';
import '../widgets/choice_tile.dart';
import '../widgets/responsive_body.dart';

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
    final tone = await AppBottomSheet.show<NotificationTone>(
      context,
      title: 'Tono de notificaciones',
      child: Builder(
        builder: (sheetContext) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in NotificationTone.values)
              ChoiceTile(
                selected: option == current,
                title: option.label,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
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

  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = context.read<AuthController>();
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Cerrar sesión',
      message: '¿Quieres salir de tu cuenta en este dispositivo?',
      confirmLabel: 'Cerrar sesión',
    );
    if (confirmed) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final text = Theme.of(context).textTheme;
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
      body: ResponsiveBody(
        maxWidth: AppLayout.formWidth,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpace.xxl),
          children: [
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: AppColors.onColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile?.name ?? '', style: text.titleMedium),
                        const SizedBox(height: 2),
                        Text(profile?.email ?? '', style: text.secondary),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          _roleLabel(profile?.role ?? UserRole.client),
                          style: text.labelMedium?.copyWith(
                            color: AppColors.readable(AppColors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            ActionListTile(
              icon: Icons.tune,
              label: 'Tono de notificaciones',
              subtitle: profile?.notificationTone?.label,
              onTap: () => _showToneDialog(context),
            ),
            const SizedBox(height: AppSpace.sm),
            Consumer<ThemeController>(
              builder: (context, themeController, _) => AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: AppSpace.xs,
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.dark_mode_outlined,
                    color: AppColors.accent,
                  ),
                  title: Text('Modo oscuro', style: text.titleSmall),
                  value: themeController.isDark,
                  onChanged: themeController.setDark,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            for (final item in items) ...[
              ActionListTile(
                icon: item.icon,
                label: item.label,
                onTap: item.onTap,
              ),
              const SizedBox(height: AppSpace.sm),
            ],
            const SizedBox(height: AppSpace.md),
            AppButton(
              variant: AppButtonVariant.secondary,
              icon: Icons.logout,
              onPressed: () => _confirmSignOut(context),
              child: const Text('Cerrar sesión'),
            ),
            const SizedBox(height: AppSpace.xxl),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 32, spin: false),
                  const SizedBox(height: AppSpace.sm),
                  Text('BarberFlow v1.0.0', style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
