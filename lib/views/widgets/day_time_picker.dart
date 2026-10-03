import 'package:flutter/material.dart';

import '../../models/barbershop.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../../utils/shop_hours.dart';

/// Selector de día (próximos 14) y de hora (solo horas dentro del horario de
/// la barbería que caben con la duración del servicio).
class DayAndTimePicker extends StatelessWidget {
  final Barbershop shop;
  final int? durationMinutes;
  final DateTime? day;
  final DateTime? dateTime;
  final ValueChanged<DateTime> onDay;
  final ValueChanged<DateTime> onTime;
  final int daysAhead;

  const DayAndTimePicker({
    super.key,
    required this.shop,
    required this.durationMinutes,
    required this.day,
    required this.dateTime,
    required this.onDay,
    required this.onTime,
    this.daysAhead = 14,
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
