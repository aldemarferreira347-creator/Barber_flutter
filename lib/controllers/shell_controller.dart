/// Recuerda qué pestaña del `RoleShell` está abierta.
///
/// Vive por encima de `MaterialApp` a propósito: al cambiar de tema la app
/// reconstruye todo el árbol (casi toda la UI lee `AppColors` directamente),
/// y sin este controlador el usuario volvería a la primera pestaña cada vez
/// que activa o desactiva el modo oscuro desde su Perfil.
class ShellController {
  int index = 0;

  /// Se llama al cerrar sesión: el siguiente usuario empieza en Inicio.
  void reset() => index = 0;
}
