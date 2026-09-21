import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../models/day_schedule.dart';
import '../../models/user_role.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../appointment/book_appointment_view.dart';
import '../product/manage_products_view.dart';
import '../service/manage_services_view.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/status_badge.dart';
import 'barbershop_reviews_view.dart';

Future<void> _openInGoogleMaps(
  BuildContext context,
  double lat,
  double lng,
) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
  );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir Google Maps')),
    );
  }
}

class BarbershopDetailView extends StatelessWidget {
  final String barbershopId;

  const BarbershopDetailView({super.key, required this.barbershopId});

  String _paymentLabel(PaymentStatus status) => switch (status) {
    PaymentStatus.ok => 'Al día',
    PaymentStatus.overdue => 'Pago pendiente',
    PaymentStatus.blocked => 'Bloqueada',
  };

  Color _paymentColor(PaymentStatus status) => switch (status) {
    PaymentStatus.ok => AppColors.success,
    PaymentStatus.overdue => AppColors.warning,
    PaymentStatus.blocked => AppColors.error,
  };

  @override
  Widget build(BuildContext context) {
    final service = context.read<BarbershopRepository>();
    final role = context.watch<AuthController>().profile?.role;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de barbería')),
      body: StreamBuilder<Barbershop?>(
        stream: service.watchOne(barbershopId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: ErrorState(
                title: 'No pudimos cargar la barbería',
                subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ShimmerBox(
                  height: 160,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                SizedBox(height: 16),
                ShimmerBox(height: 24, width: 180),
                SizedBox(height: 16),
                ShimmerList(count: 3, itemHeight: 20),
              ],
            );
          }
          final shop = snapshot.data;
          if (shop == null) {
            return Center(
              child: Text(
                'Esta barbería ya no existe',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return Scaffold(
            floatingActionButton: role == UserRole.client
                ? FloatingActionButton.extended(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookAppointmentView(
                          barbershopId: shop.id,
                          barbershopName: shop.name,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Agendar cita'),
                  )
                : null,
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Semantics(
                      image: true,
                      label: shop.photoUrl != null
                          ? 'Foto de portada de ${shop.name}'
                          : 'Sin foto de portada',
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                          image: shop.photoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(shop.photoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: shop.photoUrl == null
                            ? const Icon(
                                Icons.storefront,
                                color: Colors.white,
                                size: 48,
                              )
                            : null,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 380.ms)
                    .scaleXY(begin: 0.96, end: 1, curve: Curves.easeOutCubic),
                const SizedBox(height: 16),
                Row(
                      children: [
                        Expanded(
                          child: Text(
                            shop.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusBadge.active(shop.active),
                      ],
                    )
                    .animate(delay: 80.ms)
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: -0.05, end: 0, curve: Curves.easeOutCubic),
                if (shop.ratingCount > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star, color: AppColors.primary, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${shop.averageRating.toStringAsFixed(1)} (${shop.ratingCount})',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: shop.address ?? 'Sin dirección',
                ),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: shop.phone ?? 'Sin teléfono',
                ),
                _InfoRow(
                  icon: Icons.mail_outline,
                  label: shop.email ?? 'Sin correo de contacto',
                ),
                if (shop.location != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openInGoogleMaps(
                      context,
                      shop.location!.latitude,
                      shop.location!.longitude,
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Ver ubicación en Google Maps'),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ManageServicesView(barbershopId: shop.id),
                    ),
                  ),
                  icon: const Icon(Icons.content_cut),
                  label: const Text('Ver servicios'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ManageProductsView(barbershopId: shop.id),
                    ),
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Ver productos'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          BarbershopReviewsView(barbershopId: shop.id),
                    ),
                  ),
                  icon: const Icon(Icons.reviews_outlined),
                  label: const Text('Ver reseñas'),
                ),
                const SizedBox(height: 16),
                Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: _paymentColor(shop.paymentStatus)
                                .withValues(alpha: 0.1),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estado de pago',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _paymentLabel(shop.paymentStatus),
                                  style: TextStyle(
                                    color: _paymentColor(shop.paymentStatus),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (shop.paymentDueDate != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Fecha de vencimiento',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${shop.paymentDueDate!.year}-${shop.paymentDueDate!.month.toString().padLeft(2, '0')}-${shop.paymentDueDate!.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 320.ms)
                    .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                if ((shop.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Información general',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    shop.description!,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
                if (shop.schedule.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Horarios',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        for (final day in kWeekdays)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    day[0].toUpperCase() + day.substring(1),
                                  ),
                                ),
                                Text(
                                  shop.schedule[day]!.isOpen
                                      ? '${shop.schedule[day]!.openTime} – ${shop.schedule[day]!.closeTime}'
                                      : 'Cerrado',
                                  style: TextStyle(
                                    color: shop.schedule[day]!.isOpen
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
