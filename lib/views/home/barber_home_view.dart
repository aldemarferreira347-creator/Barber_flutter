import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../appointment/barber_appointments_view.dart';
import '../barber/barber_availability_view.dart';
import '../widgets/role_shell.dart';
import '../profile/profile_menu_view.dart';
import 'barber_dashboard_tab.dart';
import 'barber_profile_items.dart';

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
              return ProfileMenuView(items: buildBarberProfileItems(context, profile));
            },
          ),
        ),
      ],
    );
  }
}
