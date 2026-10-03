import 'package:cloud_firestore/cloud_firestore.dart';

import 'day_schedule.dart';

enum PaymentStatus { ok, overdue, blocked }

extension PaymentStatusX on PaymentStatus {
  String get value => name;

  static PaymentStatus fromValue(String value) {
    return PaymentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PaymentStatus.ok,
    );
  }
}

/// Mensualidad por defecto mientras el admin no configure otra en
/// `platformSettings/main` (ver `PlatformSettings`). Mismo valor que
/// MONTHLY_FEE en functions/src/barbershops/subscriptionService.ts y que el
/// valor por defecto de firestore.rules.
const kBarbershopMonthlyFee = 50000.0;

/// Celular Nequi colombiano: 10 dígitos que empiezan en 3. Espejo de
/// `validNequi` en firestore.rules.
final _nequiPattern = RegExp(r'^3[0-9]{9}$');

/// Deja solo dígitos (quita espacios, guiones, "+57"…) de lo que pegó el
/// usuario.
String normalizeNequiPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length == 12 && digits.startsWith('57')
      ? digits.substring(2)
      : digits;
}

/// `3001234567` → `300 123 4567` para mostrarlo legible.
String formatNequiPhone(String phone) {
  final digits = normalizeNequiPhone(phone);
  if (digits.length != 10) return phone;
  return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
}

/// Mensaje de error para un campo de Nequi, o null si es válido. Si
/// [required] es false, vacío es válido.
String? validateNequiPhone(String? raw, {bool required = false}) {
  if ((raw ?? '').trim().isEmpty) {
    return required ? 'Escribe el número Nequi' : null;
  }
  if (!_nequiPattern.hasMatch(normalizeNequiPhone(raw!))) {
    return 'Usa un celular de 10 dígitos que empiece en 3';
  }
  return null;
}

/// `50000` → `$50.000` (pesos colombianos, sin decimales).
String formatCop(double amount) {
  final digits = amount.round().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '\$$grouped';
}

/// Tope de borradores por dueño: evita que se llene la base de datos con
/// barberías falsas sin pagar. Espejo del rango de slots `_1.._5` que
/// impone firestore.rules sobre `barbershopDrafts/{uid}_{n}`.
const kMaxBarbershopDrafts = 5;

/// Ciclo de vida de una barbería:
/// - `draft`: borrador del dueño, sin pagar ni enviar. Vive en la colección
///   `barbershopDrafts` (nunca en `barbershops`) y no es visible para nadie
///   más.
/// - `pending`: ya pagada y enviada; espera la revisión del administrador
///   (spec 12.1).
/// - `approved` / `rejected`: solo el admin las asigna — nunca el propio
///   dueño.
enum BarbershopApprovalStatus { draft, pending, approved, rejected }

extension BarbershopApprovalStatusX on BarbershopApprovalStatus {
  String get value => name;

  static BarbershopApprovalStatus fromValue(String value) {
    return BarbershopApprovalStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BarbershopApprovalStatus.pending,
    );
  }
}

class Barbershop {
  final String id;
  final String name;
  final String ownerId;
  final String? address;
  final GeoPoint? location;
  final String? phone;
  final String? email;
  final String? description;
  final String? photoUrl;

  /// Nequi al que el cliente transfiere citas y productos. Sin él la
  /// barbería no ofrece pago en la app (la cita se paga en el local).
  final String? nequiPhone;

  /// Pago Nequi con el que se registró la barbería (primera mensualidad).
  /// Solo se lee: lo escribe el alta (`createPaid`/`publishDraft`).
  final String? paymentId;

  /// Visibilidad/operación general: si está en false, la barbería y sus
  /// barberos quedan bloqueados y desaparecen del catálogo (spec 12.6),
  /// sea porque aún no fue aprobada o porque se bloqueó por mensualidad.
  final bool active;
  final BarbershopApprovalStatus approvalStatus;
  final PaymentStatus paymentStatus;
  final DateTime? paymentDueDate;
  final Map<String, DaySchedule> schedule;

  /// Suma y cantidad de calificaciones recibidas (spec 7.1) — solo los
  /// escribe submitAppointmentRating en el backend. El promedio ya incluye
  /// el descuento obligatorio por cierres de tienda (spec 3.4).
  final int ratingSum;
  final int ratingCount;

  const Barbershop({
    required this.id,
    required this.name,
    required this.ownerId,
    this.address,
    this.location,
    this.phone,
    this.email,
    this.description,
    this.photoUrl,
    this.nequiPhone,
    this.paymentId,
    this.active = false,
    this.approvalStatus = BarbershopApprovalStatus.pending,
    this.paymentStatus = PaymentStatus.ok,
    this.paymentDueDate,
    this.schedule = const {},
    this.ratingSum = 0,
    this.ratingCount = 0,
  });

  bool get acceptsNequi => nequiPhone != null && nequiPhone!.isNotEmpty;

  /// 0 si nadie ha calificado todavía — nunca un promedio inventado.
  double get averageRating => ratingCount == 0 ? 0 : ratingSum / ratingCount;

  bool get isDraft => approvalStatus == BarbershopApprovalStatus.draft;

  /// Solo aparece en el catálogo del cliente si el admin ya la aprobó y no
  /// está bloqueada (spec 12.1/12.6).
  bool get isVisibleInCatalog =>
      active && approvalStatus == BarbershopApprovalStatus.approved;

  /// Puede recibir citas y compras: visible en el catálogo y con la
  /// mensualidad vigente o dentro de los [graceDays] de gracia. Es el mismo
  /// criterio que aplica `shopOperational` en firestore.rules, derivado de
  /// la fecha de vencimiento (no depende de que un proceso del servidor haya
  /// actualizado `paymentStatus`).
  bool isOperational({required int graceDays, DateTime? now}) {
    if (!isVisibleInCatalog) return false;
    final due = paymentDueDate;
    if (due == null) return true;
    return due.add(Duration(days: graceDays)).isAfter(now ?? DateTime.now());
  }

  factory Barbershop.fromMap(String id, Map<String, dynamic> map) {
    final dueDateValue = map['paymentDueDate'];
    return Barbershop(
      id: id,
      name: map['name'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      address: map['address'] as String?,
      location: map['location'] as GeoPoint?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      description: map['description'] as String?,
      photoUrl: map['photoUrl'] as String?,
      nequiPhone: map['nequiPhone'] as String?,
      paymentId: map['paymentId'] as String?,
      active: map['active'] as bool? ?? true,
      approvalStatus: BarbershopApprovalStatusX.fromValue(
        map['approvalStatus'] as String? ??
            BarbershopApprovalStatus.pending.value,
      ),
      paymentStatus: PaymentStatusX.fromValue(
        map['paymentStatus'] as String? ?? PaymentStatus.ok.value,
      ),
      paymentDueDate: dueDateValue is Timestamp ? dueDateValue.toDate() : null,
      schedule: weekScheduleFromMap(map['schedule'] as Map<String, dynamic>?),
      ratingSum: (map['ratingSum'] as num?)?.toInt() ?? 0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Documento de borrador (`barbershopDrafts`): solo los datos que el
  /// dueño llena en el formulario — sin estados de aprobación ni de pago,
  /// que solo existen una vez pagada la barbería. Las claves están
  /// restringidas por firestore.rules.
  Map<String, dynamic> toDraftMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'address': address,
      'location': location,
      'phone': phone,
      'email': email,
      'description': description,
      'photoUrl': photoUrl,
      'nequiPhone': nequiPhone,
      'schedule': schedule.isEmpty
          ? weekScheduleToMap(weekScheduleFromMap(null))
          : weekScheduleToMap(schedule),
    };
  }

  /// Lee un documento de `barbershopDrafts`.
  factory Barbershop.fromDraftMap(String id, Map<String, dynamic> map) {
    return Barbershop.fromMap(id, {
      ...map,
      'active': false,
      'approvalStatus': BarbershopApprovalStatus.draft.value,
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'address': address,
      'location': location,
      'phone': phone,
      'email': email,
      'description': description,
      'photoUrl': photoUrl,
      'nequiPhone': nequiPhone,
      'active': active,
      'approvalStatus': approvalStatus.value,
      'paymentStatus': paymentStatus.value,
      'paymentDueDate': paymentDueDate == null
          ? null
          : Timestamp.fromDate(paymentDueDate!),
      'schedule': schedule.isEmpty
          ? weekScheduleToMap(weekScheduleFromMap(null))
          : weekScheduleToMap(schedule),
    };
  }
}
