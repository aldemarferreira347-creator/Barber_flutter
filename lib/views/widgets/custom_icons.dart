import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ícono de corona vectorial personalizado para el rol "Dueño" y elementos
/// destacados de marca, recreando fielmente el diseño del mockup.
class CrownIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CrownIcon({
    super.key,
    this.size = 24,
    this.color = const Color(0xFF0F172A),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CrownPainter(color: color),
    );
  }
}

class _CrownPainter extends CustomPainter {
  final Color color;

  _CrownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, w * 0.085)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Cuerpo de la corona con 3 picos
    final path = Path();
    path.moveTo(w * 0.16, h * 0.74);
    path.lineTo(w * 0.18, h * 0.44);
    path.lineTo(w * 0.36, h * 0.58);
    path.lineTo(w * 0.50, h * 0.30);
    path.lineTo(w * 0.64, h * 0.58);
    path.lineTo(w * 0.82, h * 0.44);
    path.lineTo(w * 0.84, h * 0.74);
    path.close();

    canvas.drawPath(path, strokePaint);

    // Línea base inferior de soporte
    canvas.drawLine(
      Offset(w * 0.16, h * 0.84),
      Offset(w * 0.84, h * 0.84),
      strokePaint,
    );

    // Esferas decorativas en la punta de cada pico
    final dotRadius = math.max(1.3, w * 0.048);
    canvas.drawCircle(Offset(w * 0.18, h * 0.36), dotRadius, dotPaint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.22), dotRadius, dotPaint);
    canvas.drawCircle(Offset(w * 0.82, h * 0.36), dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => oldDelegate.color != color;
}

/// Logo oficial de Google con sus 4 colores distintivos en formato vectorial nítido.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.22;
    final center = Offset(w / 2, h / 2);
    final radius = (w - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    Paint makePaint(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    const pi = math.pi;

    // Arco azul derecho
    final bluePaint = makePaint(const Color(0xFF4285F4));
    canvas.drawArc(rect, -pi / 5, 2 * pi / 5, false, bluePaint);

    // Barra horizontal azul del centro hacia la derecha
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barRect = Rect.fromLTRB(
      w * 0.44,
      h * 0.5 - stroke / 2,
      w * 0.94,
      h * 0.5 + stroke / 2,
    );
    canvas.drawRect(barRect, barPaint);

    // Arco verde inferior
    final greenPaint = makePaint(const Color(0xFF34A853));
    canvas.drawArc(rect, pi / 5, 3 * pi / 5, false, greenPaint);

    // Arco amarillo lateral izquierdo
    final yellowPaint = makePaint(const Color(0xFFFBBC05));
    canvas.drawArc(rect, 4 * pi / 5, 3 * pi / 5, false, yellowPaint);

    // Arco rojo superior
    final redPaint = makePaint(const Color(0xFFEA4335));
    canvas.drawArc(rect, 7 * pi / 5, 3 * pi / 5, false, redPaint);
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
