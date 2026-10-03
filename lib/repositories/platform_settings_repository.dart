import '../models/platform_settings.dart';

/// Datos de cobro de la plataforma (Nequi de la mensualidad, tarifa, gracia).
abstract class PlatformSettingsRepository {
  /// Emite [PlatformSettings.defaults] mientras el admin no los configure.
  Stream<PlatformSettings> watch();

  /// Solo el admin (impuesto también en firestore.rules).
  Future<void> save({
    required String nequiPhone,
    String? nequiHolder,
    required double monthlyFee,
    required int graceDays,
  });
}
