import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../appointment/client_appointments_view.dart';
import '../barbershop/barbershop_catalog_view.dart';
import '../barbershop/my_barbershops_view.dart';
import '../help/help_view.dart';
import '../notification/notifications_view.dart';
import '../product/my_purchases_view.dart';
import '../../services/reminder_planner.dart';
import '../widgets/reminder_sync.dart';
import '../widgets/role_shell.dart';
import '../profile/profile_menu_view.dart';
import 'client_dashboard_tab.dart';

class ClientHomeView extends StatelessWidget {
  const ClientHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ReminderSync(
      audience: ReminderAudience.client,
      child: RoleShell(
        tabs: [
          const RoleTab(
            label: 'Inicio',
            icon: Icons.home_outlined,
            page: ClientDashboardTab(),
          ),
          const RoleTab(
            label: 'Barberías',
            icon: Icons.storefront_outlined,
            page: BarbershopCatalogView(),
          ),
          const RoleTab(
            label: 'Citas',
            icon: Icons.calendar_month_outlined,
            page: ClientAppointmentsView(),
          ),
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
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NotificationsView(uid: uid),
                          ),
                        ),
                      ),
                    ProfileMenuItem(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Mis compras',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MyPurchasesView(),
                        ),
                      ),
                    ),
                    if (uid != null)
                      ProfileMenuItem(
                        icon: Icons.storefront_outlined,
                        label: 'Registrar mi barbería (ser Dueño)',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MyBarbershopsView(),
                          ),
                        ),
                      ),
                    ProfileMenuItem(
                      icon: Icons.help_outline,
                      label: 'Ayuda',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpView()),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
