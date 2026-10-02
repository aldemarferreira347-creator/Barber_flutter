import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'app_network_image.dart';

/// Miniatura cuadrada de una barbería: su foto de portada o, si no tiene,
/// un ícono de tienda sobre el color de marca.
class ShopAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;

  const ShopAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      return AppNetworkImage(
        url: url,
        semanticLabel: 'Foto de $name',
        width: size,
        height: size,
        borderRadius: radius,
        decodeWidth: size.round(),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: radius),
      child: Icon(
        Icons.storefront,
        color: AppColors.onColor,
        size: size * 0.48,
        semanticLabel: 'Barbería $name',
      ),
    );
  }
}
