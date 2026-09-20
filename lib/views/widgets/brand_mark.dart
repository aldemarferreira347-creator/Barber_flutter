import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Ícono de marca: silueta de un caballero con barba y tijeras, siguiendo el
/// logo de referencia entregado por el cliente. El color se adapta al fondo
/// de cada pantalla (blanco sobre fondo oscuro, azul marino sobre fondo
/// claro) reutilizando los tokens existentes de [AppColors] — no introduce
/// colores nuevos. Las tijeras "cortan" en un loop sutil para que el logo
/// nunca se sienta estático.
class BrandMark extends StatefulWidget {
  final double size;
  final Color? color;
  final bool spin;

  const BrandMark({super.key, this.size = 32, this.color, this.spin = true});

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.spin) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedColor = widget.color ?? AppColors.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _BarberFacePainter(resolvedColor, _controller.value),
        ),
      ),
    );
  }
}

class _BarberFacePainter extends CustomPainter {
  final Color color;
  final double snip;

  _BarberFacePainter(this.color, this.snip);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Cabello: mechón peinado hacia atrás sobre la frente.
    final hair = Path()
      ..moveTo(w * 0.27, h * 0.34)
      ..cubicTo(w * 0.22, h * 0.16, w * 0.34, h * 0.03, w * 0.53, h * 0.02)
      ..cubicTo(w * 0.72, h * 0.01, w * 0.82, h * 0.14, w * 0.79, h * 0.30)
      ..cubicTo(w * 0.75, h * 0.20, w * 0.68, h * 0.13, w * 0.60, h * 0.15)
      ..cubicTo(w * 0.55, h * 0.10, w * 0.45, h * 0.10, w * 0.40, h * 0.16)
      ..cubicTo(w * 0.33, h * 0.18, w * 0.28, h * 0.25, w * 0.27, h * 0.34)
      ..close();
    canvas.drawPath(hair, fill);

    // Cabeza (óvalo del rostro).
    canvas.drawOval(
      Rect.fromLTWH(w * 0.29, h * 0.15, w * 0.42, h * 0.40),
      fill,
    );

    // Barba y bigote, siguiendo el contorno inferior del rostro.
    final beard = Path()
      ..moveTo(w * 0.295, h * 0.40)
      ..cubicTo(w * 0.27, h * 0.58, w * 0.32, h * 0.72, w * 0.50, h * 0.76)
      ..cubicTo(w * 0.68, h * 0.72, w * 0.73, h * 0.58, w * 0.705, h * 0.40)
      ..cubicTo(w * 0.68, h * 0.50, w * 0.60, h * 0.55, w * 0.50, h * 0.55)
      ..cubicTo(w * 0.40, h * 0.55, w * 0.32, h * 0.50, w * 0.295, h * 0.40)
      ..close();
    canvas.drawPath(beard, fill);

    // Hombros / busto.
    final bust = Path()
      ..moveTo(w * 0.06, h)
      ..cubicTo(w * 0.09, h * 0.80, w * 0.20, h * 0.70, w * 0.34, h * 0.70)
      ..lineTo(w * 0.66, h * 0.70)
      ..cubicTo(w * 0.80, h * 0.70, w * 0.91, h * 0.80, w * 0.94, h)
      ..close();
    canvas.drawPath(bust, fill);

    // Tijeras superpuestas en la barba, con un leve efecto de "corte".
    final scissorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round;
    final angle = 0.34 + (snip * 0.16);
    final origin = Offset(w * 0.635, h * 0.615);
    for (final dir in [1.0, -1.0]) {
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(dir * angle);
      canvas.drawLine(Offset.zero, Offset(w * 0.24, 0), scissorPaint);
      canvas.drawCircle(Offset(w * 0.27, 0), w * 0.055, scissorPaint);
      canvas.restore();
    }
    canvas.drawCircle(origin, w * 0.025, fill);
  }

  @override
  bool shouldRepaint(covariant _BarberFacePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.snip != snip;
}
