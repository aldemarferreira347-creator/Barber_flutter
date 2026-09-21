import 'package:flutter/material.dart';

import '../admin/manage_users_view.dart';
import '../barbershop/manage_barbershops_view.dart';
import '../help/help_view.dart';
import '../profile/profile_menu_view.dart';
import '../widgets/role_shell.dart';
import 'admin_dashboard_tab.dart';

class AdminHomeView extends StatelessWidget {
  const AdminHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      tabs: [
        const RoleTab(
          label: 'Inicio',
          icon: Icons.home_outlined,
          page: AdminDashboardTab(),
        ),
        const RoleTab(
          label: 'Usuarios',
          icon: Icons.people_outline,
          page: ManageUsersView(),
        ),
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
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ManageUsersView()),
                  ),
                ),
                ProfileMenuItem(
                  icon: Icons.storefront_outlined,
                  label: 'Barberías',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const ManageBarbershopsView(adminControls: true),
                    ),
                  ),
                ),
                ProfileMenuItem(
                  icon: Icons.help_outline,
                  label: 'Ayuda',
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const HelpView())),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
