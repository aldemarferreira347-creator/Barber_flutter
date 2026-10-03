import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../models/platform_settings.dart';
import '../../repositories/platform_settings_repository.dart';
import 'owner_barbershop_manage_view.dart';
import 'payment_insight.dart';

/// Avisos de todas las barberías del dueño (revisión pendiente, mensualidad
/// por vencer, vencida o bloqueada), cada uno con el nombre de su barbería y
/// un acceso directo a su gestión. No dibuja nada si todo está en orden.
class OwnerAlertsSection extends StatelessWidget {
  final List<Barbershop> shops;

  const OwnerAlertsSection({super.key, required this.shops});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlatformSettings>(
      stream: context.read<PlatformSettingsRepository>().watch(),
      initialData: PlatformSettings.defaults,
      builder: (context, snapshot) {
        final graceDays =
            (snapshot.data ?? PlatformSettings.defaults).graceDays;
        final banners = <Widget>[
          for (final shop in shops)
            for (final alert in shopAlerts(shop, graceDays: graceDays))
              ShopAlertBanner(
                alert: ShopAlert(
                  title: '${shop.name}: ${alert.title}',
                  message: alert.message,
                  color: alert.color,
                  icon: alert.icon,
                ),
                actionLabel: 'Ver',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        OwnerBarbershopManageView(barbershopId: shop.id),
                  ),
                ),
              ),
        ];
        if (banners.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: banners,
        );
      },
    );
  }
}
