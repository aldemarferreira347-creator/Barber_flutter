import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/app_user.dart';
import '../../models/appointment.dart';
import '../../models/service.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/service_repository.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/empty_state.dart';

class BookAppointmentView extends StatefulWidget {
  final String barbershopId;
  final String barbershopName;

  const BookAppointmentView({
    super.key,
    required this.barbershopId,
    required this.barbershopName,
  });

  @override
  State<BookAppointmentView> createState() => _BookAppointmentViewState();
}

class _BookAppointmentViewState extends State<BookAppointmentView> {
  Service? _service;
  AppUser? _barber;
  DateTime? _dateTime;
  bool _payNow = false;
  bool _saving = false;

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(
      () => _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _confirm() async {
    final profile = context.read<AuthController>().profile;
    if (profile == null ||
        _service == null ||
        _barber == null ||
        _dateTime == null)
      return;

    setState(() => _saving = true);
    try {
      final repo = context.read<AppointmentRepository>();
      if (_payNow) {
        // Reserva pagada (spec 6.1/6.2): el backend bloquea el horario en
        // una transacción antes de cobrar — si alguien más ya lo tomó,
        // lanza un error claro en vez de crear la cita.
        await repo.createPaid(
          barbershopId: widget.barbershopId,
          barberId: _barber!.uid,
          barberName: _barber!.name,
          serviceId: _service!.id,
          clientName: profile.name,
          date: _dateTime!,
        );
      } else {
        await repo.create(
          Appointment(
            id: '',
            barbershopId: widget.barbershopId,
            barberId: _barber!.uid,
            barberName: _barber!.name,
            clientId: profile.uid,
            clientName: profile.name,
            serviceId: _service!.id,
            serviceName: _service!.name,
            servicePrice: _service!.price,
            durationMinutes: _service!.durationMinutes,
            date: _dateTime!,
          ),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _payNow
                  ? '¡Cita pagada y horario reservado!'
                  : '¡Cita solicitada! El barbero debe confirmarla.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo agendar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceRepo = context.read<ServiceRepository>();
    final userRepo = context.read<UserRepository>();

    return Scaffold(
      appBar: AppBar(title: Text('Agendar en ${widget.barbershopName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '1. Elige un servicio',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Service>>(
            stream: serviceRepo.watchByBarbershop(widget.barbershopId),
            builder: (context, snapshot) {
              final services = (snapshot.data ?? [])
                  .where((s) => s.active)
                  .toList();
              if (services.isEmpty) {
                return const EmptyState(
                  icon: Icons.content_cut,
                  title: 'Sin servicios disponibles',
                  subtitle: 'Esta barbería todavía no publicó servicios.',
                );
              }
              return Column(
                children: services
                    .map(
                      (service) => _SelectableTile(
                        selected: _service?.id == service.id,
                        title: service.name,
                        subtitle:
                            '${service.durationMinutes} min · \$${service.price.toStringAsFixed(0)}',
                        onTap: () => setState(() => _service = service),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            '2. Elige un barbero',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<AppUser>>(
            stream: userRepo.watchBarbersByBarbershop(widget.barbershopId),
            builder: (context, snapshot) {
              final barbers = (snapshot.data ?? [])
                  .where((b) => b.available)
                  .toList();
              if (barbers.isEmpty) {
                return const EmptyState(
                  icon: Icons.person_outline,
                  title: 'Sin barberos disponibles',
                  subtitle: 'Esta barbería todavía no tiene barberos activos.',
                );
              }
              return Column(
                children: barbers
                    .map(
                      (barber) => _SelectableTile(
                        selected: _barber?.uid == barber.uid,
                        title: barber.name,
                        onTap: () => setState(() => _barber = barber),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            '3. Elige fecha y hora',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickDateTime,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              _dateTime == null
                  ? 'Elegir fecha y hora'
                  : _dateTime.toString().substring(0, 16),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '4. ¿Cómo quieres reservar?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _SelectableTile(
            selected: !_payNow,
            title: 'Sin pago',
            subtitle: 'Solo indicas tu intención de asistir. No bloquea el horario para otros clientes.',
            onTap: () => setState(() => _payNow = false),
          ),
          _SelectableTile(
            selected: _payNow,
            title: 'Pagar ahora con Nequi',
            subtitle:
                'Bloquea el horario de inmediato: nadie más podrá tomarlo.',
            onTap: () => setState(() => _payNow = true),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed:
                (_service != null &&
                    _barber != null &&
                    _dateTime != null &&
                    !_saving)
                ? _confirm
                : null,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_payNow ? 'Pagar y reservar' : 'Solicitar cita'),
          ),
        ],
      ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SelectableTile({
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? AppColors.accent : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
