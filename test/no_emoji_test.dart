import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// La interfaz no usa emojis: para eso están los íconos de la app (Material
// Icons y los dibujados con CustomPainter). Un emoji se ve distinto en cada
// teléfono, no sigue el tema y rompe el tono sobrio del diseño. Este test
// recorre el código de la app y el de los mensajes del backend.
void main() {
  // Pictogramas y emoji: bloques de emoji, símbolos y dingbats (incluye ✓ ✔ ✗),
  // estrellas, el selector de variación y la unión. Las flechas tipográficas
  // de los comentarios no cuentan.
  final emoji = RegExp(
    '[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B50}\u{2B55}\u{FE0F}\u{200D}]',
    unicode: true,
  );

  void scan(String root, bool Function(String path) include) {
    final offenders = <String>[];
    final dir = Directory(root);
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !include(entity.path.replaceAll('\\', '/'))) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (emoji.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Usa un ícono en vez de un emoji:\n${offenders.join('\n')}',
    );
  }

  test('la app no contiene emojis', () {
    scan('lib', (path) => path.endsWith('.dart'));
  });

  test('los mensajes del backend no contienen emojis', () {
    scan('functions/src', (path) => path.endsWith('.ts'));
  });
}
