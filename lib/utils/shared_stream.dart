import 'dart:async';

/// Comparte una sola consulta en vivo entre todas las pantallas que piden lo
/// mismo. Cada servicio de datos tiene su propia instancia.
///
/// Sin esto, cada `build()` que escribe `repo.watchX(id)` abre una consulta
/// NUEVA: el `StreamBuilder` vuelve a "cargando" (parpadeo del esqueleto con
/// cada cambio de estado) y se abren listeners duplicados. Con
/// [SharedStreams.of] la misma clave devuelve SIEMPRE el mismo `Stream`:
/// se abre la consulta al primer oyente, el último valor se entrega al
/// instante a los siguientes y la consulta se cierra [grace] después de que
/// se va el último, de modo que volver a una pantalla recién cerrada no
/// recarga desde cero.
class SharedStreams {
  /// Tiempo que sigue abierta una consulta sin oyentes.
  static const grace = Duration(seconds: 20);

  static final Set<SharedStreams> _instances = {};

  /// Cada servicio tiene su propio registro: dos servicios (o dos pruebas)
  /// con la misma clave nunca comparten consultas.
  SharedStreams() {
    _instances.add(this);
  }

  final Map<String, _SharedEntry<Object?>> _entries = {};

  /// El stream compartido de [key]; [create] solo se llama la primera vez (o
  /// si la consulta ya se cerró). La clave debe identificar la consulta
  /// completa (colección, filtros y argumentos) y el tipo [T] debe ser el
  /// mismo para una misma clave.
  Stream<T> of<T>(String key, Stream<T> Function() create) {
    final entry = _entries.putIfAbsent(
      key,
      () => _SharedEntry<T>(this, key, create),
    );
    return (entry as _SharedEntry<T>).stream;
  }

  /// Cierra las consultas de este registro y olvida sus valores.
  void reset() {
    for (final entry in _entries.values.toList()) {
      entry.dispose();
    }
    _entries.clear();
  }

  /// Cierra TODAS las consultas compartidas de la app. Se llama al cerrar
  /// sesión: nada de una cuenta debe servirse a la siguiente.
  static void resetAll() {
    for (final instance in _instances) {
      instance.reset();
    }
  }

  /// Cantidad de consultas compartidas vivas en este registro (pruebas).
  int get activeCount => _entries.length;
}

class _SharedEntry<T> {
  final SharedStreams _owner;
  final String key;
  final Stream<T> Function() _create;
  late final Stream<T> stream = Stream<T>.multi(_onListen);

  final List<MultiStreamController<T>> _listeners = [];
  StreamSubscription<T>? _source;
  Timer? _closeTimer;
  bool _hasValue = false;
  T? _last;
  bool _disposed = false;

  _SharedEntry(this._owner, this.key, this._create);

  void _onListen(MultiStreamController<T> listener) {
    _closeTimer?.cancel();
    _closeTimer = null;
    _listeners.add(listener);
    if (_hasValue) listener.add(_last as T);
    listener.onCancel = () {
      _listeners.remove(listener);
      if (_listeners.isEmpty) _scheduleClose();
    };
    _source ??= _create().listen(
      (value) {
        _hasValue = true;
        _last = value;
        for (final l in _listeners.toList()) {
          l.add(value);
        }
      },
      onError: (Object error, StackTrace stack) {
        for (final l in _listeners.toList()) {
          l.addError(error, stack);
        }
      },
      onDone: () {
        for (final l in _listeners.toList()) {
          l.close();
        }
        _source = null;
      },
    );
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(SharedStreams.grace, _closeSource);
  }

  /// Cierra la consulta de origen y la saca del registro: el siguiente
  /// oyente abre una nueva (con valores frescos).
  void _closeSource() {
    if (_listeners.isNotEmpty) return;
    dispose();
    _owner._entries.remove(key);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _closeTimer?.cancel();
    _source?.cancel();
    _source = null;
    _hasValue = false;
    _last = null;
    for (final l in _listeners.toList()) {
      l.close();
    }
    _listeners.clear();
  }
}
