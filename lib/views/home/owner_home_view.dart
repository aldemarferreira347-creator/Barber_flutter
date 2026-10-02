import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../appointment/client_appointments_view.dart';
import '../barbershop/barbershop_catalog_view.dart';
import '../barbershop/my_barbershops_view.dart';
import '../help/help_view.dart';
import '../notification/notifications_view.dart';
import '../profile/profile_menu_view.dart';
import '../widgets/role_shell.dart';
import 'owner_appointments_tab.dart';
import 'owner_dashboard_tab.dart';

/// Vista del rol Dueño (spec 12): gestión de SUS barberías (Mis barberías,
/// Mis citas) más las mismas vistas del Cliente (Explorar para reservar en
/// otras barberías, y sus propias reservas desde Más).
class OwnerHomeView extends StatelessWidget {
  const OwnerHomeView({super.key});

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature próximamente')));
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      tabs: [
        const RoleTab(
          label: 'Inicio',
          icon: Icons.home_outlined,
          page: OwnerDashboardTab(),
        ),
        const RoleTab(
          label: 'Mis barberías',
          icon: Icons.storefront_outlined,
          page: MyBarbershopsView(),
        ),
        const RoleTab(
          label: 'Mis citas',
          icon: Icons.calendar_month_outlined,
          page: OwnerAppointmentsTab(),
        ),
        const RoleTab(
          label: 'Explorar',
          icon: Icons.search,
          page: BarbershopCatalogView(),
        ),
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
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NotificationsView(uid: uid),
                        ),
                      ),
                    ),
                  ProfileMenuItem(
                    icon: Icons.event_note_outlined,
                    label: 'Mis reservas como cliente',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ClientAppointmentsView(),
                      ),
                    ),
                  ),
                  ProfileMenuItem(
                    icon: Icons.settings_outlined,
                    label: 'Configuración',
                    onTap: () => _comingSoon(context, 'La configuración'),
                  ),
                  ProfileMenuItem(
                    icon: Icons.help_outline,
                    label: 'Ayuda',
                    onTap: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => const HelpView())),
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
