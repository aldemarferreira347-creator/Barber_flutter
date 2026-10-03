import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/app_user.dart';
import '../../models/appointment.dart';
import '../../models/barbershop.dart';
import '../../models/service.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/service_repository.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../../utils/shop_hours.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/choice_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/nequi_payment_sheet.dart';
import '../widgets/responsive_body.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_box.dart';

/// Reserva de una cita: servicio, barbero, día y hora (solo horas dentro del
/// horario de la barbería) y forma de reserva. Pagar por Nequi bloquea el
/// horario de inmediato; la barbería confirma después que recibió el dinero.
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
  /// Días que se pueden reservar hacia adelante.
  static const _daysAhead = 14;

  late final Stream<Barbershop?> _shop = context
      .read<BarbershopRepository>()
      .watchOne(widget.barbershopId);

  Service? _service;
  AppUser? _barber;
  DateTime? _day;
  DateTime? _dateTime;
  bool _payNow = false;
  bool _saving = false;

  void _pickService(Service service) => setState(() {
    _service = service;
    // La duración cambia qué horas caben: se vuelve a elegir la hora.
    _dateTime = null;
  });

  void _pickDay(DateTime day) => setState(() {
    _day = day;
    _dateTime = null;
  });

  Future<void> _confirm(Barbershop shop) async {
    final profile = context.read<AuthController>().profile;
    final service = _service;
    final barber = _barber;
    final dateTime = _dateTime;
    if (profile == null ||
        service == null ||
        barber == null ||
        dateTime == null) {
      return;
    }

    final payNow = _payNow && shop.acceptsNequi;
    String? reference;
    if (payNow) {
      reference = await showNequiPaymentSheet(
        context,
        title: 'Pagar con Nequi',
        amount: service.price,
        payeeName: shop.name,
        payeePhone: shop.nequiPhone!,
      );
      if (reference == null || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      final repo = context.read<AppointmentRepository>();
      if (payNow) {
        // Reserva pagada (spec 6.1/6.2): el horario se bloquea en una
        // transacción y el pago queda en verificación. Si alguien más ya lo
        // tomó, falla con un error claro en vez de crear la cita.
        await repo.createPaid(
          barbershopId: widget.barbershopId,
          barberId: barber.uid,
          barberName: barber.name,
          serviceId: service.id,
          clientName: profile.name,
          date: dateTime,
          reference: reference!,
        );
      } else {
        await repo.create(
          Appointment(
            id: '',
            barbershopId: widget.barbershopId,
            barberId: barber.uid,
            barberName: barber.name,
            clientId: profile.uid,
            clientName: profile.name,
            serviceId: service.id,
            serviceName: service.name,
            servicePrice: service.price,
            durationMinutes: service.durationMinutes,
            date: dateTime,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            payNow
                ? '¡Horario reservado! ${shop.name} confirmará tu pago en breve.'
                : '¡Cita solicitada! El barbero debe confirmarla.',
          ),
        ),
      );
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
      body: StreamBuilder<Barbershop?>(
        stream: _shop,
        builder: (context, shopSnapshot) {
          final shop = shopSnapshot.data;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
            children: [
              ResponsiveBody(
                maxWidth: AppLayout.formWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(title: '1. Elige un servicio'),
                    StreamBuilder<List<Service>>(
                      stream: serviceRepo.watchByBarbershop(
                        widget.barbershopId,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const ErrorState(
                            title: 'No pudimos cargar los servicios',
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ShimmerList(count: 2, itemHeight: 58);
                        }
                        final services = (snapshot.data ?? [])
                            .where((s) => s.active)
                            .toList();
                        if (services.isEmpty) {
                          return const EmptyState(
                            icon: Icons.content_cut,
                            title: 'Sin servicios disponibles',
                            subtitle:
                                'Esta barbería todavía no publicó servicios.',
                          );
                        }
                        return Column(
                          children: [
                            for (final service in services)
                              ChoiceTile(
                                selected: _service?.id == service.id,
                                title: service.name,
                                subtitle: '${service.durationMinutes} min',
                                trailing: Text(
                                  formatCop(service.price),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                onTap: () => _pickService(service),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpace.xl),
                    const SectionHeader(title: '2. Elige un barbero'),
                    StreamBuilder<List<AppUser>>(
                      stream: userRepo.watchBarbersByBarbershop(
                        widget.barbershopId,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const ErrorState(
                            title: 'No pudimos cargar los barberos',
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ShimmerList(count: 2, itemHeight: 58);
                        }
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
                          children: [
                            for (final barber in barbers)
                              ChoiceTile(
                                selected: _barber?.uid == barber.uid,
                                title: barber.name,
                                onTap: () => setState(() => _barber = barber),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpace.xl),
                    const SectionHeader(title: '3. Elige día y hora'),
                    if (shop == null)
                      const ShimmerList(count: 1, itemHeight: 58)
                    else
                      _DayAndTimePicker(
                        shop: shop,
                        durationMinutes: _service?.durationMinutes,
                        day: _day,
                        dateTime: _dateTime,
                        onDay: _pickDay,
                        onTime: (time) => setState(() => _dateTime = time),
                        daysAhead: _daysAhead,
                      ),
                    const SizedBox(height: AppSpace.xl),
                    const SectionHeader(title: '4. ¿Cómo quieres reservar?'),
                    ChoiceTile(
                      selected: !_payNow || !(shop?.acceptsNequi ?? false),
                      title: 'Pagar en la barbería',
                      subtitle: 'Solicitas la cita; no bloquea el horario hasta que el barbero la acepte.',
                      onTap: () => setState(() => _payNow = false),
                    ),
                    ChoiceTile(
                      selected: _payNow && (shop?.acceptsNequi ?? false),
                      enabled: shop?.acceptsNequi ?? false,
                      title: 'Pagar ahora con Nequi',
                      subtitle: (shop?.acceptsNequi ?? false)
                          ? 'Bloquea el horario de inmediato: nadie más podrá tomarlo.'
                          : 'Esta barbería aún no recibe pagos por Nequi.',
                      onTap: () => setState(() => _payNow = true),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    if (_service != null &&
                        _barber != null &&
                        _dateTime != null)
                      _Summary(
                        service: _service!,
                        barber: _barber!,
                        dateTime: _dateTime!,
                        payNow: _payNow && (shop?.acceptsNequi ?? false),
                      ),
                    const SizedBox(height: AppSpace.lg),
                    AppButton(
                      onPressed:
                          (shop != null &&
                              _service != null &&
                              _barber != null &&
                              _dateTime != null)
                          ? () => _confirm(shop)
                          : null,
                      icon: (_payNow && (shop?.acceptsNequi ?? false))
                          ? Icons.lock_outline
                          : Icons.event_available,
                      loading: _saving,
                      child: Text(
                        (_payNow && (shop?.acceptsNequi ?? false))
                            ? 'Reservar y pagar'
                            : 'Solicitar cita',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Selector de día (próximos 14) y de hora (solo horas dentro del horario de
/// la barbería que caben con la duración del servicio).
class _DayAndTimePicker extends StatelessWidget {
  final Barbershop shop;
  final int? durationMinutes;
  final DateTime? day;
  final DateTime? dateTime;
  final ValueChanged<DateTime> onDay;
  final ValueChanged<DateTime> onTime;
  final int daysAhead;

  const _DayAndTimePicker({
    required this.shop,
    required this.durationMinutes,
    required this.day,
    required this.dateTime,
    required this.onDay,
    required this.onTime,
    required this.daysAhead,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final today = DateTime.now();
    final days = [
      for (var i = 0; i < daysAhead; i++)
        DateTime(today.year, today.month, today.day + i),
    ];
    final duration = durationMinutes;
    final selectedDay = day;
    final slots = (selectedDay == null || duration == null)
        ? const <DateTime>[]
        : availableTimeSlots(
            shop.schedule,
            day: selectedDay,
            durationMinutes: duration,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
            itemBuilder: (context, index) {
              final d = days[index];
              final isSelected =
                  selectedDay != null &&
                  d.year == selectedDay.year &&
                  d.month == selectedDay.month &&
                  d.day == selectedDay.day;
              return ChoiceChip(
                label: Text(dayLabel(d)),
                selected: isSelected,
                onSelected: (_) => onDay(d),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.md),
        if (duration == null)
          Text('Primero elige un servicio.', style: text.secondary)
        else if (selectedDay == null)
          Text('Elige un día para ver las horas.', style: text.secondary)
        else if (slots.isEmpty)
          Text(
            'No hay horas disponibles ese día. Prueba con otro.',
            style: text.secondary,
          )
        else
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final slot in slots)
                ChoiceChip(
                  label: Text(timeLabel(slot)),
                  selected: dateTime == slot,
                  onSelected: (_) => onTime(slot),
                ),
            ],
          ),
        const SizedBox(height: AppSpace.sm),
        Text(
          'Si el horario ya fue tomado por otra reserva pagada, te lo '
          'avisaremos al confirmar.',
          style: text.bodySmall,
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final Service service;
  final AppUser barber;
  final DateTime dateTime;
  final bool payNow;

  const _Summary({
    required this.service,
    required this.barber,
    required this.dateTime,
    required this.payNow,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: AppColors.surfaceRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen', style: text.titleSmall),
          const SizedBox(height: AppSpace.sm),
          Text('${service.name} · ${service.durationMinutes} min'),
          Text('Con ${barber.name}'),
          Text(dateTimeLabel(dateTime)),
          const Divider(height: AppSpace.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  payNow ? 'Total a pagar por Nequi' : 'Total en la barbería',
                  style: text.secondary,
                ),
              ),
              Text(formatCop(service.price), style: text.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}
