import 'dart:async';

/// Combina dos streams: emite `combine(a, b)` cada vez que cualquiera de los
/// dos emite, una vez que ambos ya tienen un valor. Se cierra cuando se
/// cierran los dos y cancela ambas suscripciones al cancelarse. Los errores
/// de cualquiera de los dos se propagan.
Stream<R> combineLatest2<A, B, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  R Function(A a, B b) combine,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;
  var doneA = false;
  var doneB = false;

  void emit() {
    if (hasA && hasB) controller.add(combine(latestA as A, latestB as B));
  }

  void closeIfDone() {
    if (doneA && doneB) controller.close();
  }

  controller = StreamController<R>(
    onListen: () {
      subA = streamA.listen(
        (value) {
          latestA = value;
          hasA = true;
          emit();
        },
        onError: controller.addError,
        onDone: () {
          doneA = true;
          closeIfDone();
        },
      );
      subB = streamB.listen(
        (value) {
          latestB = value;
          hasB = true;
          emit();
        },
        onError: controller.addError,
        onDone: () {
          doneB = true;
          closeIfDone();
        },
      );
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}
