import 'package:barber/utils/error_text.dart';
import 'package:barber/utils/failure.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

FirebaseException _fb(String code, [String plugin = 'cloud_firestore']) =>
    FirebaseException(plugin: plugin, code: code);

void main() {
  group('classifyFailure', () {
    test('sin red, servidor caído y tiempo agotado son de conexión', () {
      expect(classifyFailure(_fb('unavailable')), FailureKind.network);
      expect(classifyFailure(_fb('deadline-exceeded')), FailureKind.network);
      expect(
        classifyFailure(const LoadTimeoutException()),
        FailureKind.network,
      );
    });

    test('permisos y sesión son de acceso', () {
      expect(classifyFailure(_fb('permission-denied')), FailureKind.access);
      expect(classifyFailure(_fb('unauthenticated')), FailureKind.access);
      expect(
        classifyFailure(_fb('unauthorized', 'firebase_storage')),
        FailureKind.access,
      );
    });

    test('un índice que falta es de configuración', () {
      expect(classifyFailure(_fb('failed-precondition')), FailureKind.config);
    });

    test('reconoce el código aunque llegue envuelto en texto (web)', () {
      expect(
        classifyFailure(Exception('[cloud_firestore/permission-denied] x')),
        FailureKind.access,
      );
    });

    test('lo demás es desconocido', () {
      expect(classifyFailure(StateError('x')), FailureKind.unknown);
    });
  });

  group('errorText de Storage', () {
    test('object-not-found explica que la foto no se subió', () {
      expect(
        errorText(_fb('object-not-found', 'firebase_storage')),
        contains('foto'),
      );
    });

    test('unauthorized habla de permiso para subir', () {
      expect(
        errorText(_fb('unauthorized', 'firebase_storage')),
        contains('subir'),
      );
    });
  });
}
