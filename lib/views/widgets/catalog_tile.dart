import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'app_card.dart';
import 'app_network_image.dart';
import 'status_badge.dart';

/// Fila de catálogo (servicio o producto): foto o ícono, nombre, detalle,
/// precio y, para quien administra, el estado visible/oculto con su
/// interruptor. Si recibe [onTap] toda la fila es tocable (editar o comprar).
class CatalogTile extends StatelessWidget {
  final String name;
  final String? detail;
  final String priceLabel;
  final String? photoUrl;
  final IconData fallbackIcon;
  final bool active;

  /// Muestra el interruptor visible/oculto (solo quien administra).
  final ValueChanged<bool>? onActiveChanged;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const CatalogTile({
    super.key,
    required this.name,
    required this.priceLabel,
    required this.fallbackIcon,
    this.detail,
    this.photoUrl,
    this.active = true,
    this.onActiveChanged,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppRadius.md);
    final url = photoUrl;
    return AppCard(
      onTap: onTap,
      semanticLabel: semanticLabel ?? name,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          if (url != null && url.isNotEmpty)
            AppNetworkImage(
              url: url,
              semanticLabel: 'Foto de $name',
              width: 56,
              height: 56,
              decodeWidth: 56,
              borderRadius: radius,
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: radius,
              ),
              child: Icon(fallbackIcon, color: AppColors.textSecondary),
            ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.titleSmall),
                if ((detail ?? '').isNotEmpty)
                  Text(
                    detail!,
                    style: text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (onActiveChanged != null && !active) ...[
                  const SizedBox(height: AppSpace.xs),
                  StatusBadge(label: 'Oculto', color: AppColors.textSecondary),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Text(priceLabel, style: text.titleSmall),
          if (onActiveChanged != null)
            Semantics(
              label: active ? 'Ocultar $name' : 'Mostrar $name',
              child: Switch(value: active, onChanged: onActiveChanged),
            ),
        ],
      ),
    );
  }
}
