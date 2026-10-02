import 'package:flutter/material.dart';

import '../../models/barbershop.dart';
import '../../theme/app_colors.dart';
import '../widgets/status_badge.dart';

/// Etiqueta del estado de aprobación de una barbería (borrador, pendiente,
/// aprobada o rechazada) — compartida por la gestión del dueño y la del admin.
class ApprovalStatusBadge extends StatelessWidget {
  final BarbershopApprovalStatus status;

  const ApprovalStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BarbershopApprovalStatus.draft => ('Borrador', AppColors.textSecondary),
      BarbershopApprovalStatus.pending => ('Pendiente', AppColors.warning),
      BarbershopApprovalStatus.approved => ('Aprobada', AppColors.success),
      BarbershopApprovalStatus.rejected => ('Rechazada', AppColors.error),
    };
    return StatusBadge(label: label, color: color);
  }
}
