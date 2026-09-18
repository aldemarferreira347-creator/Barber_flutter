/// Cierre de tienda por evento externo (spec 3.4): aplaza las reservas
/// pagadas afectadas, notifica a cada cliente, y marca la penalización de
/// calificación obligatoria — todo resuelto en el backend.
abstract class ShopClosureRepository {
  Future<int> closeForExternalEvent({
    required String barbershopId,
    required DateTime closedFrom,
    required DateTime closedUntil,
    required String reason,
  });
}
