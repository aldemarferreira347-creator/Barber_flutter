abstract class RatingRepository {
  /// Envía la calificación de una cita pagada y completada (spec 7.1). El
  /// backend valida que la cita sea del cliente autenticado, esté pagada y
  /// completada, y que no se haya calificado antes.
  Future<void> submitRating({required String appointmentId, required int barberStars, required int shopStars});

  /// Ids de citas que [clientId] ya calificó — para no ofrecer calificar
  /// dos veces la misma cita en la UI.
  Stream<Set<String>> watchRatedAppointmentIds(String clientId);
}
