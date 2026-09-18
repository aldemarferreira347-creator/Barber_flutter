import 'dart:typed_data';

import '../models/comment.dart';

abstract class CommentRepository {
  /// Envía el comentario (opcional, spec 7.2) de una cita pagada y
  /// completada; pasa por moderación en el backend antes de publicarse
  /// (spec 7.3) — devuelve si quedó publicado o rechazado.
  Future<CommentStatus> submitComment({required String appointmentId, required String text, String? photoUrl});

  /// El personal de la barbería responde un comentario publicado (spec 7.2).
  Future<void> replyToComment({required String commentId, required String replyText});

  /// Comentarios PUBLICADOS de la barbería, más recientes primero.
  Stream<List<Comment>> watchPublishedByBarbershop(String barbershopId);

  Future<String> uploadPhoto({required String appointmentId, required String fileName, required Uint8List bytes});
}
