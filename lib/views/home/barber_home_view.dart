import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../appointment/barber_appointments_view.dart';
import '../barber/barber_availability_view.dart';
import '../notification/notifications_view.dart';
import '../product/claim_purchase_view.dart';
import '../service/manage_services_view.dart';
import '../widgets/role_shell.dart';
import '../profile/profile_menu_view.dart';
import 'barber_dashboard_tab.dart';

class BarberHomeView extends StatelessWidget {
  const BarberHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      tabs: [
        const RoleTab(label: 'Inicio', icon: Icons.home_outlined, page: BarberDashboardTab()),
        const RoleTab(label: 'Citas', icon: Icons.calendar_month_outlined, page: BarberAppointmentsView()),
        const RoleTab(label: 'Disponibilidad', icon: Icons.access_time, page: BarberAvailabilityView()),
        RoleTab(
          label: 'Perfil',
          icon: Icons.person_outline,
          page: Builder(
            builder: (context) {
              final profile = context.watch<AuthController>().profile;
              return ProfileMenuView(
                items: [
                  if (profile != null)
                    ProfileMenuItem(
                      icon: Icons.notifications_none,
                      label: 'Notificaciones',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationsView(uid: profile.uid))),
                    ),
                  if (profile?.barbershopId != null) ...[
                    ProfileMenuItem(
                      icon: Icons.content_cut,
                      label: 'Servicios de mi barbería',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ManageServicesView(barbershopId: profile!.barbershopId!),
                      )),
                    ),
                    ProfileMenuItem(
                      icon: Icons.qr_code,
                      label: 'Reclamar compra de producto',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ClaimPurchaseView(barbershopId: profile!.barbershopId!),
                      )),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
