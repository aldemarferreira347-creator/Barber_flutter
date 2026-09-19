import 'package:flutter/material.dart';

/// Ícono de marca: un poste de barbería clásico dibujado con [CustomPainter],
/// usado en splash, login, registro y la pantalla de éxito para reforzar la
/// identidad visual sin depender de un asset externo.
class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BarberPolePainter()),
    );
  }
}

class _BarberPolePainter extends CustomPainter {
  static const _stripeColors = [Color(0xFFEF4444), Colors.white, Color(0xFF3B82F6)];

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = Rect.fromLTWH(size.width * 0.28, 0, size.width * 0.44, size.height);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, Radius.circular(size.width * 0.22));

    canvas.save();
    canvas.clipRRect(bodyRRect);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final stripeWidth = size.width * 0.24;
    var offset = -size.height;
    var i = 0;
    while (offset < size.width + size.height) {
      final path = Path()
        ..moveTo(offset, size.height)
        ..lineTo(offset + size.height, 0)
        ..lineTo(offset + size.height + stripeWidth, 0)
        ..lineTo(offset + stripeWidth, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = _stripeColors[i % _stripeColors.length]);
      offset += stripeWidth;
      i++;
    }
    canvas.restore();

    final capPaint = Paint()..color = const Color(0xFF1E293B);
    final capHeight = size.height * 0.16;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.2, 0, size.width * 0.6, capHeight),
        Radius.circular(size.width * 0.1),
      ),
      capPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.2, size.height - capHeight, size.width * 0.6, capHeight),
        Radius.circular(size.width * 0.1),
      ),
      capPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BarberPolePainter oldDelegate) => false;
}
