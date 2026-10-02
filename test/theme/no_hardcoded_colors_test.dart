import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Los colores viven en `AppColors`. Una vista con un color fijo se rompe en
// el otro modo (claro/oscuro): así era el login, con texto oscuro sobre fondo
// oscuro. Este test impide que reaparezcan.
void main() {
  // Archivos donde un color fijo es legítimo: la paleta misma y los logos
  // dibujados con CustomPainter (colores de marca de Google, corona).
  const allowed = {
    'lib/theme/app_colors.dart',
    'lib/theme/contrast.dart', // negro/blanco puros como último recurso de contraste
    'lib/views/widgets/custom_icons.dart',
  };

  final forbidden = RegExp(
    r'(?<![A-Za-z])Colors\.(?!transparent)[a-zA-Z]+|Color\(0x|Color\.fromARGB|Color\.fromRGBO',
  );

  test('ninguna vista usa colores fijos fuera de AppColors', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (allowed.contains(path)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (forbidden.hasMatch(line)) {
          offenders.add('$path:${i + 1}  ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Usa un token de AppColors en vez de un color fijo:\n${offenders.join('\n')}',
    );
  });
}
