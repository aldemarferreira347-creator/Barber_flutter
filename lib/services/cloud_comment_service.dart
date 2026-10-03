import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/comment.dart';
import '../repositories/comment_repository.dart';
import '../repositories/storage_repository.dart';
import 'content_moderation_filter.dart';
import '../utils/shared_stream.dart';

const _maxTextLength = 500;

// Nombre histórico (antes llamaba a submitAppointmentComment/replyToComment,
// Cloud Functions) — sin plan Blaze escribe Firestore directo. La
// moderación (spec 7.3) corre aquí mismo, en el cliente, ANTES de decidir
// el status ('published' vs 'rejected') que se guarda — ver
// firestore.rules para el límite aceptado: las reglas validan que el
// status declarado sea uno de los dos válidos, pero no pueden re-correr el
// propio filtro de moderación, así que un cliente manipulado podría en
// teoría escribir 'published' con texto ofensivo saltándose la app.
class CloudCommentService implements CommentRepository {
  final _shared = SharedStreams();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final StorageRepository _storage;

  CloudCommentService({
    required this._storage,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection('appointments');

  CollectionReference<Map<String, dynamic>> get _comments =>
      _firestore.collection('comments');

  @override
  Future<CommentStatus> submitComment({
    required String appointmentId,
    required String text,
    String? photoUrl,
  }) async {
    final clientId = _auth.currentUser?.uid;
    if (clientId == null) throw Exception('Debes iniciar sesión.');
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > _maxTextLength) {
      throw Exception(
        'El comentario debe tener entre 1 y $_maxTextLength caracteres.',
      );
    }

    final appointmentSnap = await _appointments.doc(appointmentId).get();
    final appointment = appointmentSnap.data();
    if (!appointmentSnap.exists || appointment == null) {
      throw Exception('La cita no existe.');
    }
    if (appointment['clientId'] != clientId) {
      throw Exception('Solo el cliente de esa cita puede comentarla.');
    }
    if (appointment['paid'] != true || appointment['status'] != 'completed') {
      throw Exception(
        'Solo se puede comentar una reserva pagada y completada.',
      );
    }

    final status = containsOffensiveContent(trimmed)
        ? CommentStatus.rejected
        : CommentStatus.published;

    await _comments.doc(appointmentId).set({
      'appointmentId': appointmentId,
      'barbershopId': appointment['barbershopId'],
      'barberId': appointment['barberId'],
      'clientId': clientId,
      'clientName': appointment['clientName'] ?? '',
      'text': trimmed,
      'photoUrl': photoUrl,
      'status': status.value,
      'createdAt': FieldValue.serverTimestamp(),
      'replyText': null,
      'replyAt': null,
      'repliedByBarberId': null,
    });

    return status;
  }

  @override
  Future<void> replyToComment({
    required String commentId,
    required String replyText,
  }) async {
    final barberId = _auth.currentUser?.uid;
    if (barberId == null) throw Exception('Debes iniciar sesión.');
    final trimmed = replyText.trim();
    if (trimmed.isEmpty || trimmed.length > _maxTextLength) {
      throw Exception(
        'La respuesta debe tener entre 1 y $_maxTextLength caracteres.',
      );
    }
    if (containsOffensiveContent(trimmed)) {
      throw Exception('La respuesta contiene lenguaje inapropiado.');
    }

    await _comments.doc(commentId).update({
      'replyText': trimmed,
      'replyAt': FieldValue.serverTimestamp(),
      'repliedByBarberId': barberId,
    });
  }

  /// Reseñas más recientes que se muestran (la pantalla no pagina).
  static const _maxPublished = 100;

  @override
  Stream<List<Comment>> watchPublishedByBarbershop(String barbershopId) {
    return _shared.of<List<Comment>>(
      'watchPublishedByBarbershop:$barbershopId',
      () {
        return _comments
            .where('barbershopId', isEqualTo: barbershopId)
            .where('status', isEqualTo: 'published')
            .orderBy('createdAt', descending: true)
            .limit(_maxPublished)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map((doc) => Comment.fromMap(doc.id, doc.data()))
                  .toList(),
            );
      },
    );
  }

  @override
  Future<String> uploadPhoto({
    required String appointmentId,
    required String fileName,
    required Uint8List bytes,
  }) {
    return _storage.uploadBytes(
      path: 'comments/$appointmentId/$fileName',
      bytes: bytes,
    );
  }
}
