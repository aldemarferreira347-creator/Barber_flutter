import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

/// Etiqueta de estado de la app (Activo, En mora, Pendiente…): fondo teñido
/// del color del estado, punto de color y texto con contraste AA garantizado
/// ([AppColors.readable]) — igual que los badges del mockup. Es la única
/// etiqueta de estado: `ApprovalStatusBadge`, el estado de las citas y el
/// de pago delegan en ella.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  factory StatusBadge.active(bool active) {
    return active
        ? const StatusBadge(label: 'Activa', color: AppColors.success)
        : const StatusBadge(label: 'Bloqueada', color: AppColors.error);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tint(color),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.readable(color),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
