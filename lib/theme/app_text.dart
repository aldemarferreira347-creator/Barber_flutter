import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Estilos de texto de la app que `TextTheme` no trae de fábrica.
///
/// El estilo por defecto de un `Text` (`bodyMedium`) usa el color principal
/// para que nada quede atenuado sin querer; el texto de apoyo (subtítulos,
/// descripciones) pide [secondary] explícitamente.
extension AppTextStyles on TextTheme {
  /// Texto de apoyo de 14 px en el color secundario.
  TextStyle get secondary => (bodyMedium ?? const TextStyle(fontSize: 14))
      .copyWith(color: AppColors.textSecondary);
}
