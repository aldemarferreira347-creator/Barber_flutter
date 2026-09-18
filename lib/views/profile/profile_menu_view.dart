import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final initials = (profile?.name.isNotEmpty ?? false)
        ? profile!.name.trim().split(RegExp(r'\s+')).map((p) => p[0]).take(2).join().toUpperCase()
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
                  child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(profile?.email ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Rol: ${_roleLabel(profile?.role ?? UserRole.client)}', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final item in items) ...[
            ActionListTile(icon: item.icon, label: item.label, onTap: item.onTap),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.read<AuthController>().signOut(),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Cerrar sesión', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
            ),
          ),
        ],
      ),
    );
  }
}
