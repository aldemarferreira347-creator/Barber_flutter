import 'dart:async';

import 'package:barber/utils/stream_combine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emite cuando ambos tienen valor y re-emite con cada cambio', () async {
    final a = StreamController<int>();
    final b = StreamController<String>();
    final results = <String>[];
    final sub = combineLatest2<int, String, String>(
      a.stream,
      b.stream,
      (x, y) => '$x$y',
    ).listen(results.add);

    a.add(1);
    await Future<void>.delayed(Duration.zero);
    expect(results, isEmpty, reason: 'falta el valor de b');

    b.add('a');
    await Future<void>.delayed(Duration.zero);
    a.add(2);
    b.add('b');
    await Future<void>.delayed(Duration.zero);

    expect(results, ['1a', '2a', '2b']);
    await sub.cancel();
    await a.close();
    await b.close();
  });

  test('propaga errores y se cierra cuando ambos terminan', () async {
    final a = StreamController<int>();
    final b = StreamController<int>();
    final errors = <Object>[];
    var done = false;
    combineLatest2<int, int, int>(
      a.stream,
      b.stream,
      (x, y) => x + y,
    ).listen((_) {}, onError: errors.add, onDone: () => done = true);

    a.addError(StateError('x'));
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(1));

    await a.close();
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);
    await b.close();
    await Future<void>.delayed(Duration.zero);
    expect(done, isTrue);
  });

  test('cancelar la suscripción cancela las dos de origen', () async {
    var cancelledA = false;
    var cancelledB = false;
    final a = StreamController<int>(onCancel: () => cancelledA = true);
    final b = StreamController<int>(onCancel: () => cancelledB = true);
    final sub = combineLatest2<int, int, int>(
      a.stream,
      b.stream,
      (x, y) => x + y,
    ).listen((_) {});

    await sub.cancel();

    expect(cancelledA, isTrue);
    expect(cancelledB, isTrue);
  });
}
