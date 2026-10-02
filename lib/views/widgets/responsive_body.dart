import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Centra el contenido y limita su ancho en tablet y escritorio, con un
/// margen lateral que crece con la pantalla. En un teléfono no cambia nada.
///
/// Úsalo como `child` de un `ListView`/`SingleChildScrollView` completo, o
/// con [padding] para listas: así los formularios y las listas no se
/// estiran de borde a borde en una pantalla ancha.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.contentWidth,
  });

  /// Margen horizontal según el tamaño de pantalla.
  static double gutter(BuildContext context) => switch (context.screenSize) {
    ScreenSize.compact => AppSpace.lg,
    ScreenSize.medium => AppSpace.xl,
    ScreenSize.expanded => AppSpace.xxl,
  };

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter(context)),
          child: child,
        ),
      ),
    );
  }
}
