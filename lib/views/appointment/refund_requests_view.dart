import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/refund_request.dart';
import '../../repositories/refund_request_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/empty_state.dart';

/// Panel del dueño para aprobar/rechazar solicitudes de cancelación con
/// justificación de citas pagadas (spec 6.3, 6.5).
class RefundRequestsView extends StatelessWidget {
  final String barbershopId;

  const RefundRequestsView({super.key, required this.barbershopId});

  Color _statusColor(RefundRequestStatus status) => switch (status) {
    RefundRequestStatus.pending => AppColors.warning,
    RefundRequestStatus.approved => AppColors.success,
    RefundRequestStatus.rejected => AppColors.error,
  };

  Future<void> _resolve(BuildContext context, RefundRequest request, bool approve) async {
    try {
      await context.read<RefundRequestRepository>().resolve(request.id, approve: approve);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(approve ? 'Reembolso aprobado y procesado.' : 'Solicitud rechazada.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo resolver: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<RefundRequestRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de reembolso')),
      body: StreamBuilder<List<RefundRequest>>(
        stream: repo.watchByBarbershop(barbershopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Sin solicitudes',
                subtitle: 'Cuando un cliente pida cancelar una cita pagada, aparecerá aquí.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final request = requests[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(request.status).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            request.status.label,
                            style: TextStyle(
                              color: _statusColor(request.status),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(request.reason, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (request.purchaseId != null) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Incluye productos por reembolsar',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                    if (request.status == RefundRequestStatus.pending) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _resolve(context, request, false),
                            child: const Text('Rechazar', style: TextStyle(color: AppColors.error)),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _resolve(context, request, true),
                            child: const Text('Aprobar reembolso'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
