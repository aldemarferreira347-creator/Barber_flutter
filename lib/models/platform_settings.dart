import 'barbershop.dart';

/// Datos de cobro de la plataforma que configura el admin
/// (`platformSettings/main`): a qué Nequi paga el dueño su mensualidad,
/// cuánto, y cuántos días de gracia tiene tras vencerse antes del bloqueo.
class PlatformSettings {
  /// Nequi de la plataforma; null mientras el admin no lo configure (el
  /// dueño no puede pagar hasta entonces).
  final String? nequiPhone;
  final String? nequiHolder;
  final double monthlyFee;
  final int graceDays;

  const PlatformSettings({
    this.nequiPhone,
    this.nequiHolder,
    this.monthlyFee = kBarbershopMonthlyFee,
    this.graceDays = kDefaultGraceDays,
  });

  /// Valores mientras `platformSettings/main` no exista.
  static const defaults = PlatformSettings();

  /// Días de gracia por defecto tras vencerse la mensualidad.
  static const kDefaultGraceDays = 4;

  bool get canCharge => nequiPhone != null && nequiPhone!.isNotEmpty;

  factory PlatformSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return defaults;
    return PlatformSettings(
      nequiPhone: map['nequiPhone'] as String?,
      nequiHolder: map['nequiHolder'] as String?,
      monthlyFee:
          (map['monthlyFee'] as num?)?.toDouble() ?? kBarbershopMonthlyFee,
      graceDays: (map['graceDays'] as num?)?.toInt() ?? kDefaultGraceDays,
    );
  }
}
