import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../services/reminder_planner.dart';
import '../../services/reminder_service.dart';

/// Mantiene programados los recordatorios locales de las citas de quien
/// tiene la sesión abierta: cada vez que cambian sus citas vuelve a
/// programar (así una cita cancelada o movida no deja un aviso viejo) y al
/// cerrar sesión los quita. No dibuja nada propio.
class ReminderSync extends StatefulWidget {
  final ReminderAudience audience;
  final Widget child;

  const ReminderSync({super.key, required this.audience, required this.child});

  @override
  State<ReminderSync> createState() => _ReminderSyncState();
}

class _ReminderSyncState extends State<ReminderSync> {
  StreamSubscription<List<Appointment>>? _subscription;
  ReminderScheduler? _scheduler;

  @override
  void initState() {
    super.initState();
    // `ReminderScheduler?` es opcional: sin proveedor (pruebas) no hay avisos.
    _scheduler = context.read<ReminderScheduler?>();
    final uid = context.read<AuthController>().profile?.uid;
    if (_scheduler == null || uid == null) return;
    final repo = context.read<AppointmentRepository>();
    final stream = widget.audience == ReminderAudience.barber
        ? repo.watchByBarber(uid)
        : repo.watchByClient(uid);
    _subscription = stream.listen(
      (appointments) =>
          _scheduler!.sync(appointments, audience: widget.audience),
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    // Al salir de la sesión no deben quedar avisos de la cuenta anterior.
    unawaited(_scheduler?.clear());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
