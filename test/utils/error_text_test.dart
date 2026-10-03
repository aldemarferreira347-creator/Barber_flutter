import 'package:barber/utils/error_text.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('errorText', () {
    test('traduce los códigos de Firebase más comunes', () {
      expect(
        errorText(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        contains('No tienes permiso'),
      );
      expect(
        errorText(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        contains('Sin conexión'),
      );
      expect(
        errorText(
          FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated'),
        ),
        contains('sesión venció'),
      );
    });

    test(
      'reconoce el código aunque llegue envuelto en texto (Flutter web)',
      () {
        expect(
          errorText(
            Exception(
              'Error: Dart exception: [cloud_firestore/permission-denied] Missing or insufficient permissions.',
            ),
          ),
          contains('No tienes permiso'),
        );
      },
    );

    test('un código desconocido usa el mensaje de Firebase o el código', () {
      expect(
        errorText(
          FirebaseException(plugin: 'p', code: 'raro', message: 'Algo pasó'),
        ),
        'Algo pasó',
      );
      expect(
        errorText(FirebaseException(plugin: 'p', code: 'raro')),
        'Ocurrió un error inesperado (raro).',
      );
    });

    test('quita el prefijo técnico de las excepciones propias', () {
      expect(
        errorText(Exception('Ese horario ya no está disponible.')),
        'Ese horario ya no está disponible.',
      );
      expect(errorText(StateError('sin datos')), 'sin datos');
      expect(errorText('texto plano'), 'texto plano');
    });

    test('un error vacío no deja el aviso en blanco', () {
      expect(errorText(Exception('')), 'Ocurrió un error inesperado.');
    });
  });
}
