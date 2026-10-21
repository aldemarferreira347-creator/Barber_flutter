import 'package:barber/utils/image_content_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('imageContentType', () {
    test('deduce el tipo por la extensión, sin importar mayúsculas', () {
      expect(imageContentType('a.PNG'), 'image/png');
      expect(imageContentType('a.webp'), 'image/webp');
      expect(imageContentType('a.heic'), 'image/heic');
      expect(imageContentType('barbershops/s1/products/a.jpg'), 'image/jpeg');
    });

    test('sin extensión o desconocida cae en JPEG, nunca en octet-stream', () {
      expect(imageContentType('image_picker_123'), 'image/jpeg');
      expect(imageContentType('foto.xyz'), 'image/jpeg');
    });
  });

  group('safeFileName', () {
    test('quita espacios, tildes y símbolos pero conserva la extensión', () {
      expect(safeFileName('Mi foto (1) ñandú.png'), 'Mi_foto_1_and_.png');
    });

    test('un nombre vacío no deja la ruta rota', () {
      expect(safeFileName(''), 'foto.jpg');
    });
  });
}
