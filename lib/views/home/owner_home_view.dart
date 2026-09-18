import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../notification/notifications_view.dart';
import '../widgets/role_shell.dart';
import '../profile/profile_menu_view.dart';
import 'owner_appointments_tab.dart';
import 'owner_dashboard_tab.dart';
import 'owner_products_tab.dart';
import 'owner_refund_requests_tab.dart';
import 'owner_services_tab.dart';

class OwnerHomeView extends StatelessWidget {
  const OwnerHomeView({super.key});

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature próximamente')));
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      tabs: [
        const RoleTab(label: 'Inicio', icon: Icons.home_outlined, page: OwnerDashboardTab()),
        const RoleTab(label: 'Servicios', icon: Icons.content_cut, page: OwnerServicesTab()),
        const RoleTab(label: 'Citas', icon: Icons.calendar_month_outlined, page: OwnerAppointmentsTab()),
        RoleTab(
          label: 'Más',
          icon: Icons.more_horiz,
          page: Builder(
            builder: (context) {
              final uid = context.watch<AuthController>().profile?.uid;
              return ProfileMenuView(
                items: [
                  if (uid != null)
                    ProfileMenuItem(
                      icon: Icons.notifications_none,
                      label: 'Notificaciones',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationsView(uid: uid))),
                    ),
                  ProfileMenuItem(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Gestionar productos',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OwnerProductsTab())),
                  ),
                  ProfileMenuItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Solicitudes de reembolso',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OwnerRefundRequestsTab())),
                  ),
                  ProfileMenuItem(icon: Icons.settings_outlined, label: 'Configuración', onTap: () => _comingSoon(context, 'La configuración')),
                  ProfileMenuItem(icon: Icons.help_outline, label: 'Ayuda', onTap: () => _comingSoon(context, 'La ayuda')),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
