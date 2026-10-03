import 'dart:async';

import 'package:barber/utils/shared_stream.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SharedStreams shared;

  setUp(() => shared = SharedStreams());
  tearDown(() => shared.reset());

  /// Fuente de prueba que cuenta cuántas veces se abrió y se cerró.
  ({
    Stream<int> Function() create,
    StreamController<int> Function() current,
    int Function() opened,
    int Function() closed,
  })
  source() {
    var opened = 0;
    var closed = 0;
    late StreamController<int> controller;
    return (
      create: () {
        opened++;
        controller = StreamController<int>(onCancel: () => closed++);
        return controller.stream;
      },
      current: () => controller,
      opened: () => opened,
      closed: () => closed,
    );
  }

  test(
    'la misma clave devuelve el mismo Stream y abre una sola consulta',
    () async {
      final src = source();

      final a = shared.of('k', src.create);
      final b = shared.of('k', src.create);
      expect(identical(a, b), isTrue);

      final seenA = <int>[];
      final seenB = <int>[];
      final subA = a.listen(seenA.add);
      final subB = b.listen(seenB.add);
      src.current().add(1);
      await Future<void>.delayed(Duration.zero);

      expect(src.opened(), 1);
      expect(seenA, [1]);
      expect(seenB, [1]);
      await subA.cancel();
      await subB.cancel();
    },
  );

  test('un oyente nuevo recibe de inmediato el último valor', () async {
    final src = source();
    final stream = shared.of('k', src.create);
    final first = stream.listen((_) {});
    src.current().add(7);
    await Future<void>.delayed(Duration.zero);

    final late = <int>[];
    final second = stream.listen(late.add);
    await Future<void>.delayed(Duration.zero);

    expect(late, [7]);
    expect(src.opened(), 1);
    await first.cancel();
    await second.cancel();
  });

  test('claves distintas son consultas distintas', () async {
    final a = source();
    final b = source();
    final subA = shared.of('a', a.create).listen((_) {});
    final subB = shared.of('b', b.create).listen((_) {});

    expect(a.opened(), 1);
    expect(b.opened(), 1);
    expect(shared.activeCount, 2);
    await subA.cancel();
    await subB.cancel();
  });

  test(
    'sin oyentes la consulta sigue abierta durante la gracia y luego se cierra',
    () {
      fakeAsync((async) {
        final src = source();
        final stream = shared.of('k', src.create);
        final sub = stream.listen((_) {});
        sub.cancel();

        async.elapse(SharedStreams.grace - const Duration(seconds: 1));
        expect(src.closed(), 0, reason: 'aún dentro de la gracia');

        // Volver dentro de la gracia reutiliza la misma consulta.
        final again = shared.of('k', src.create).listen((_) {});
        expect(src.opened(), 1);
        again.cancel();

        async.elapse(SharedStreams.grace + const Duration(seconds: 1));
        expect(src.closed(), 1);
        expect(shared.activeCount, 0);

        // Pasada la gracia se abre una consulta nueva con datos frescos.
        final fresh = shared.of('k', src.create).listen((_) {});
        expect(src.opened(), 2);
        fresh.cancel();
      });
    },
  );

  test('los errores llegan a todos los oyentes', () async {
    final src = source();
    final stream = shared.of('k', src.create);
    final errorsA = <Object>[];
    final errorsB = <Object>[];
    final subA = stream.listen((_) {}, onError: errorsA.add);
    final subB = stream.listen((_) {}, onError: errorsB.add);

    src.current().addError(StateError('sin permiso'));
    await Future<void>.delayed(Duration.zero);

    expect(errorsA, hasLength(1));
    expect(errorsB, hasLength(1));
    await subA.cancel();
    await subB.cancel();
  });

  test(
    'reset cierra las consultas y olvida los valores (cierre de sesión)',
    () async {
      final src = source();
      final done = Completer<void>();
      final sub = shared
          .of('k', src.create)
          .listen((_) {}, onDone: done.complete);
      src.current().add(1);
      await Future<void>.delayed(Duration.zero);

      shared.reset();
      await done.future;

      expect(src.closed(), 1);
      expect(shared.activeCount, 0);
      // La siguiente consulta no recibe el valor de la cuenta anterior.
      final seen = <int>[];
      final next = shared.of('k', src.create).listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty);
      expect(src.opened(), 2);
      await next.cancel();
      await sub.cancel();
    },
  );

  test('dos registros con la misma clave no comparten consultas', () async {
    final other = SharedStreams();
    final a = source();
    final b = source();
    final subA = shared.of('k', a.create).listen((_) {});
    final subB = other.of('k', b.create).listen((_) {});

    expect(a.opened(), 1);
    expect(b.opened(), 1);
    await subA.cancel();
    await subB.cancel();
    other.reset();
  });

  test('resetAll cierra las consultas de todos los registros', () async {
    final other = SharedStreams();
    final a = source();
    final b = source();
    final subA = shared.of('k', a.create).listen((_) {});
    final subB = other.of('k', b.create).listen((_) {});

    SharedStreams.resetAll();

    expect(a.closed(), 1);
    expect(b.closed(), 1);
    await subA.cancel();
    await subB.cancel();
  });
}
