import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/barbershop.dart';
import '../models/platform_settings.dart';
import '../repositories/platform_settings_repository.dart';
import '../utils/shared_stream.dart';

class FirestorePlatformSettingsService implements PlatformSettingsRepository {
  final FirebaseFirestore _firestore;
  final _shared = SharedStreams();

  FirestorePlatformSettingsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('platformSettings').doc('main');

  @override
  Stream<PlatformSettings> watch() => _shared.of<PlatformSettings>(
    'watch',
    () => _doc.snapshots().map((doc) => PlatformSettings.fromMap(doc.data())),
  );

  @override
  Future<void> save({
    required String nequiPhone,
    String? nequiHolder,
    required double monthlyFee,
    required int graceDays,
  }) {
    final phone = normalizeNequiPhone(nequiPhone);
    final holder = nequiHolder?.trim();
    return _doc.set({
      'nequiPhone': phone,
      'nequiHolder': holder == null || holder.isEmpty ? null : holder,
      'monthlyFee': monthlyFee,
      'graceDays': graceDays,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
