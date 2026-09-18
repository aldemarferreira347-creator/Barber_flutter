import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../appointment/client_appointments_view.dart';
import '../barbershop/manage_barbershops_view.dart';
import '../notification/notifications_view.dart';
import '../widgets/role_shell.dart';
import '../profile/profile_menu_view.dart';
import 'client_dashboard_tab.dart';

class ClientHomeView extends StatelessWidget {
  const ClientHomeView({super.key});

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature próximamente')));
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      tabs: [
        const RoleTab(label: 'Inicio', icon: Icons.home_outlined, page: ClientDashboardTab()),
        const RoleTab(label: 'Barberías', icon: Icons.storefront_outlined, page: ManageBarbershopsView()),
        const RoleTab(label: 'Citas', icon: Icons.calendar_month_outlined, page: ClientAppointmentsView()),
        RoleTab(
          label: 'Perfil',
          icon: Icons.person_outline,
          page: Builder(
            builder: (context) {
              final uid = context.watch<AuthController>().profile?.uid;
              return ProfileMenuView(
                items: [
                  if (uid != null)
                    ProfileMenuItem(
                      icon: Icons.notifications_none,
                      label: 'Notificaciones',
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationsView(uid: uid))),
                    ),
                  ProfileMenuItem(
                    icon: Icons.payment_outlined,
                    label: 'Métodos de pago',
                    onTap: () => _comingSoon(context, 'Los métodos de pago'),
                  ),
                  if (uid != null)
                    ProfileMenuItem(
                      icon: Icons.storefront_outlined,
                      label: 'Registrar mi barbería (ser Dueño)',
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => ManageBarbershopsView(ownerId: uid, canAdd: true))),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
