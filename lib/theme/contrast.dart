import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Relación de contraste WCAG 2.x entre dos colores opacos (1 a 21).
/// AA exige ≥ 4.5 para texto normal y ≥ 3 para texto grande e íconos.
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(Color color) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Mezcla [top] (con su alfa) sobre [bottom] opaco.
Color blendOver(Color top, Color bottom) =>
    Color.alphaBlend(top, bottom).withValues(alpha: 1);

/// Devuelve [foreground] ajustado (solo su luminosidad) hasta alcanzar
/// [minRatio] contra [background]: se oscurece sobre fondos claros y se
/// aclara sobre fondos oscuros. Conserva el matiz, así un verde sigue
/// siendo verde.
Color ensureContrast(
  Color foreground,
  Color background, {
  double minRatio = 4.5,
}) {
  if (contrastRatio(foreground, background) >= minRatio) return foreground;
  final towardsBlack = _luminance(background) > 0.5;
  final hsl = HSLColor.fromColor(foreground);
  var lightness = hsl.lightness;
  for (var i = 0; i < 60; i++) {
    lightness = (towardsBlack ? lightness - 0.015 : lightness + 0.015).clamp(
      0.0,
      1.0,
    );
    final candidate = hsl.withLightness(lightness).toColor();
    if (contrastRatio(candidate, background) >= minRatio) return candidate;
  }
  return towardsBlack ? Colors.black : Colors.white;
}
