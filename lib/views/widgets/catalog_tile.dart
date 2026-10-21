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

  /// Etiquetas bajo el nombre (duración, stock...). Cada una es un
  /// [StatusBadge] o similar.
  final List<Widget> badges;

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
    this.badges = const [],
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
              width: 72,
              height: 72,
              decodeWidth: 72,
              borderRadius: radius,
            )
          else
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: radius,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                fallbackIcon,
                size: 30,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.titleSmall),
                if ((detail ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (badges.isNotEmpty ||
                    (onActiveChanged != null && !active)) ...[
                  const SizedBox(height: AppSpace.sm),
                  Wrap(
                    spacing: AppSpace.xs,
                    runSpacing: AppSpace.xs,
                    children: [
                      ...badges,
                      if (onActiveChanged != null && !active)
                        StatusBadge(
                          label: 'Oculto',
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpace.sm),
                // El precio es lo primero que busca el cliente: va en una
                // píldora propia, no suelto al borde de la fila.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: AppSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tint(AppColors.accent),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    priceLabel,
                    style: text.titleSmall?.copyWith(
                      color: AppColors.readable(AppColors.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
