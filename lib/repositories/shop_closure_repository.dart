/// Lo que provocaría un cierre, para mostrarlo antes de confirmar.
class ClosureImpact {
  /// Citas pagadas que se aplazan.
  final int paidAppointments;

  /// Citas sin pago (pendientes o aceptadas) que se cancelan.
  final int unpaidAppointments;

  /// Compras de productos sin entregar (por pagar o por reclamar).
  final int purchases;

  const ClosureImpact({
    this.paidAppointments = 0,
    this.unpaidAppointments = 0,
    this.purchases = 0,
  });

  int get total => paidAppointments + unpaidAppointments + purchases;
}

/// Resultado de un cierre ya aplicado.
class ClosureResult {
  final int postponed;
  final int cancelled;
  final int purchasesNotified;

  /// Citas que no se pudieron actualizar (el cierre sí quedó aplicado).
  final int appointmentsFailed;

  /// Avisos que sí quedaron guardados para los clientes.
  final int notificationsSent;

  /// Avisos que no se pudieron guardar (el cierre sí se aplicó).
  final int notificationsFailed;

  const ClosureResult({
    this.postponed = 0,
    this.cancelled = 0,
    this.purchasesNotified = 0,
    this.appointmentsFailed = 0,
    this.notificationsSent = 0,
    this.notificationsFailed = 0,
  });

  int get appointmentsAffected => postponed + cancelled;
}

/// Cierre de tienda por evento externo (spec 3.4): aplaza las reservas
/// pagadas, cancela las que no tenían pago, avisa a cada cliente con una
/// cita o una compra abierta y deja la barbería marcada como cerrada.
///
/// [closedUntil] nulo significa que la barbería no tiene fecha de regreso:
/// queda cerrada hasta que su dueño la reabra con [reopen].
abstract class ShopClosureRepository {
  Future<ClosureImpact> previewImpact({
    required String barbershopId,
    required DateTime closedFrom,
    DateTime? closedUntil,
  });

  Future<ClosureResult> closeForExternalEvent({
    required String barbershopId,
    required DateTime closedFrom,
    DateTime? closedUntil,
    required String reason,
  });

  /// Termina el cierre vigente: la barbería vuelve a recibir reservas.
  Future<void> reopen(String barbershopId);
}
