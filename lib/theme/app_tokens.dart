import 'package:flutter/material.dart';

/// Escala de espaciado: todo margen/padding de la app sale de aquí, así las
/// pantallas comparten el mismo ritmo vertical y horizontal.
class AppSpace {
  AppSpace._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Radios de esquina.
class AppRadius {
  AppRadius._();

  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

/// Anchos máximos de contenido según el tipo de pantalla.
class AppLayout {
  AppLayout._();

  /// Formularios y lecturas: una columna cómoda.
  static const formWidth = 560.0;

  /// Listas y paneles.
  static const contentWidth = 960.0;
}

/// Tamaños de pantalla por ancho (Material 3): compacto (teléfono),
/// medio (tablet / teléfono apaisado) y expandido (escritorio).
enum ScreenSize {
  compact,
  medium,
  expanded;

  static const mediumFrom = 600.0;
  static const expandedFrom = 1024.0;

  static ScreenSize of(double width) {
    if (width >= expandedFrom) return ScreenSize.expanded;
    if (width >= mediumFrom) return ScreenSize.medium;
    return ScreenSize.compact;
  }
}

extension ScreenSizeContext on BuildContext {
  ScreenSize get screenSize => ScreenSize.of(MediaQuery.sizeOf(this).width);
  bool get isCompact => screenSize == ScreenSize.compact;
}
