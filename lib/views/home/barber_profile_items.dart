import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../help/help_view.dart';
import '../notification/notifications_view.dart';
import '../product/claim_purchase_view.dart';
import '../profile/profile_menu_view.dart';
import '../service/manage_services_view.dart';

/// Items del menú de perfil del barbero, compartidos entre la pestaña
/// "Perfil" del bottom nav y el acceso rápido del panel de inicio.
List<ProfileMenuItem> buildBarberProfileItems(
  BuildContext context,
  AppUser? profile,
) {
  return [
    if (profile != null)
      ProfileMenuItem(
        icon: Icons.notifications_none,
        label: 'Notificaciones',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationsView(uid: profile.uid),
          ),
        ),
      ),
    if (profile?.barbershopId != null) ...[
      ProfileMenuItem(
        icon: Icons.content_cut,
        label: 'Servicios de mi barbería',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ManageServicesView(barbershopId: profile!.barbershopId!),
          ),
        ),
      ),
      ProfileMenuItem(
        icon: Icons.qr_code,
        label: 'Reclamar compra de producto',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ClaimPurchaseView(barbershopId: profile!.barbershopId!),
          ),
        ),
      ),
    ],
    ProfileMenuItem(
      icon: Icons.help_outline,
      label: 'Ayuda',
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const HelpView())),
    ),
  ];
}
