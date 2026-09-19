import 'package:flutter/material.dart';

import '../admin/manage_users_view.dart';
import '../barbershop/manage_barbershops_view.dart';
import '../profile/profile_menu_view.dart';
import '../widgets/role_shell.dart';
import 'admin_dashboard_tab.dart';

class AdminHomeView extends StatelessWidget {
  const AdminHomeView({super.key});

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature próximamente')));
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      tabs: [
        const RoleTab(label: 'Inicio', icon: Icons.home_outlined, page: AdminDashboardTab()),
        const RoleTab(label: 'Usuarios', icon: Icons.people_outline, page: ManageUsersView()),
        const RoleTab(
          label: 'Barberías',
          icon: Icons.storefront_outlined,
          page: ManageBarbershopsView(adminControls: true),
        ),
        RoleTab(
          label: 'Ajustes',
          icon: Icons.settings_outlined,
          page: Builder(
            builder: (context) => ProfileMenuView(
              items: [
                ProfileMenuItem(
                  icon: Icons.people_outline,
                  label: 'Usuarios',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageUsersView())),
                ),
                ProfileMenuItem(
                  icon: Icons.storefront_outlined,
                  label: 'Barberías',
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const ManageBarbershopsView(adminControls: true))),
                ),
                ProfileMenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Configuración del sistema',
                  onTap: () => _comingSoon(context, 'La configuración'),
                ),
                ProfileMenuItem(
                  icon: Icons.help_outline,
                  label: 'Ayuda',
                  onTap: () => _comingSoon(context, 'La ayuda'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
