import 'package:cloud_firestore/cloud_firestore.dart';

enum CommentStatus { published, rejected }

extension CommentStatusX on CommentStatus {
  String get value => name;

  static CommentStatus fromValue(String value) {
    return CommentStatus.values.firstWhere((s) => s.name == value, orElse: () => CommentStatus.rejected);
  }
}

/// Comentario sobre el servicio de una cita pagada y completada (spec 7.2),
/// con respuesta opcional del personal de la barbería. El id del documento
/// ES el appointmentId (un comentario por cita) — solo lo escribe el
/// backend, que también corre la moderación (spec 7.3) antes de guardarlo.
class Comment {
  final String appointmentId;
  final String barbershopId;
  final String barberId;
  final String clientId;
  final String clientName;
  final String text;
  final String? photoUrl;
  final CommentStatus status;
  final DateTime? createdAt;
  final String? replyText;
  final DateTime? replyAt;

  const Comment({
    required this.appointmentId,
    required this.barbershopId,
    required this.barberId,
    required this.clientId,
    required this.clientName,
    required this.text,
    this.photoUrl,
    this.status = CommentStatus.published,
    this.createdAt,
    this.replyText,
    this.replyAt,
  });

  bool get hasReply => replyText != null && replyText!.isNotEmpty;

  factory Comment.fromMap(String appointmentId, Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];
    final replyAtValue = map['replyAt'];
    return Comment(
      appointmentId: appointmentId,
      barbershopId: map['barbershopId'] as String? ?? '',
      barberId: map['barberId'] as String? ?? '',
      clientId: map['clientId'] as String? ?? '',
      clientName: map['clientName'] as String? ?? '',
      text: map['text'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      status: CommentStatusX.fromValue(map['status'] as String? ?? CommentStatus.rejected.value),
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : null,
      replyText: map['replyText'] as String?,
      replyAt: replyAtValue is Timestamp ? replyAtValue.toDate() : null,
    );
  }
}
