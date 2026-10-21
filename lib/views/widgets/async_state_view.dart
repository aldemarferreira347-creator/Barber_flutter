import 'dart:async';

import 'package:flutter/material.dart';

import '../../utils/failure.dart';
import 'error_state.dart';
import 'shimmer_box.dart';

/// Pinta un `Stream` con los cuatro estados que toda lista necesita, y los
/// separa con claridad:
///
/// - **cargando**: esqueleto, nunca más de [timeout]; pasado ese tiempo es
///   una falla de conexión con "Reintentar" (no un spinner eterno);
/// - **vacío**: [empty] cuando [isEmpty] dice que no hay datos. Que no
///   exista nada todavía NO es un error;
/// - **error**: solo cuando la consulta falló de verdad, con el texto que
///   corresponde a la causa y un botón para reintentar;
/// - **datos**: [builder].
///
/// [stream] debe poder escucharse más de una vez (los de los repositorios
/// lo son): "Reintentar" vuelve a suscribirse.
class AsyncStateView<T> extends StatefulWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;

  /// Qué datos cuentan como "vacío"; por defecto solo las listas sin
  /// elementos.
  final bool Function(T data)? isEmpty;

  /// Se muestra cuando [isEmpty] es verdadero.
  final Widget? empty;
  final Widget? loading;
  final String errorTitle;
  final Duration timeout;

  const AsyncStateView({
    super.key,
    required this.stream,
    required this.builder,
    this.isEmpty,
    this.empty,
    this.loading,
    this.errorTitle = 'No pudimos cargar esta información',
    this.timeout = const Duration(seconds: 15),
  });

  @override
  State<AsyncStateView<T>> createState() => _AsyncStateViewState<T>();
}

class _AsyncStateViewState<T> extends State<AsyncStateView<T>> {
  int _attempt = 0;
  bool _timedOut = false;
  bool _received = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(AsyncStateView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.stream, widget.stream)) _retry();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, () {
      if (mounted && !_received) setState(() => _timedOut = true);
    });
  }

  void _retry() {
    setState(() {
      _attempt++;
      _timedOut = false;
      _received = false;
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      key: ValueKey(_attempt),
      stream: widget.stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _received = true;
          return Center(
            child: SingleChildScrollView(
              child: ErrorState(
                title: widget.errorTitle,
                error: snapshot.error,
                onRetry: _retry,
              ),
            ),
          );
        }
        // `T` puede ser anulable (p. ej. `Barbershop?`): "sin documento" es un
        // dato válido, no una espera.
        final waiting =
            snapshot.connectionState == ConnectionState.waiting ||
            (!snapshot.hasData && null is! T);
        if (waiting) {
          if (_timedOut) {
            return Center(
              child: SingleChildScrollView(
                child: ErrorState(
                  title: widget.errorTitle,
                  error: const LoadTimeoutException(),
                  onRetry: _retry,
                ),
              ),
            );
          }
          return widget.loading ??
              const Padding(padding: EdgeInsets.all(16), child: ShimmerList());
        }
        _received = true;
        final data = snapshot.data as T;
        final empty = widget.empty;
        if (empty != null && _isEmpty(data, widget.isEmpty)) {
          return Center(child: SingleChildScrollView(child: empty));
        }
        return widget.builder(context, data);
      },
    );
  }

  static bool _isEmpty<T>(T data, bool Function(T)? custom) {
    if (custom != null) return custom(data);
    final value = data;
    if (value == null) return true;
    if (value is Iterable) return value.isEmpty;
    return false;
  }
}

/// `StreamBuilder` que le da a su `builder` una función [retry] para el
/// botón "Reintentar" de un [ErrorState]: vuelve a suscribirse al stream.
/// Para las pantallas que ya arman sus estados a mano y solo necesitan poder
/// reintentar tras un error.
class RetryStreamBuilder<T> extends StatefulWidget {
  final Stream<T> stream;
  final Widget Function(
    BuildContext context,
    AsyncSnapshot<T> snapshot,
    VoidCallback retry,
  )
  builder;

  const RetryStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
  });

  @override
  State<RetryStreamBuilder<T>> createState() => _RetryStreamBuilderState<T>();
}

class _RetryStreamBuilderState<T> extends State<RetryStreamBuilder<T>> {
  int _attempt = 0;

  void _retry() => setState(() => _attempt++);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      key: ValueKey(_attempt),
      stream: widget.stream,
      builder: (context, snapshot) => widget.builder(context, snapshot, _retry),
    );
  }
}
