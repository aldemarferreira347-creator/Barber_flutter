import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'shimmer_box.dart';

/// Imagen de red con caché en disco (no se vuelve a descargar en cada
/// arranque), esqueleto mientras carga e ícono si falla. Siempre lleva
/// [semanticLabel] para lectores de pantalla; si la imagen es decorativa,
/// pásalo vacío.
class AppNetworkImage extends StatelessWidget {
  final String url;
  final String semanticLabel;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Ancho aproximado en píxeles lógicos, para decodificar la imagen a ese
  /// tamaño y no en su resolución original.
  final int? decodeWidth;

  const AppNetworkImage({
    super.key,
    required this.url,
    required this.semanticLabel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.decodeWidth,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: decodeWidth == null ? null : (decodeWidth! * dpr).round(),
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) =>
          ShimmerBox(width: width ?? double.infinity, height: height ?? 120),
      errorWidget: (_, _, _) => Container(
        width: width,
        height: height,
        color: AppColors.surfaceRaised,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.textSecondary,
        ),
      ),
    );

    return Semantics(
      image: true,
      label: semanticLabel.isEmpty ? null : semanticLabel,
      excludeSemantics: semanticLabel.isEmpty,
      child: borderRadius == null
          ? image
          : ClipRRect(borderRadius: borderRadius!, child: image),
    );
  }
}
