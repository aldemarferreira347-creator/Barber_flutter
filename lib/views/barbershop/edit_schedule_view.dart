import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/day_schedule.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/responsive_body.dart';
import '../../utils/error_text.dart';

class EditScheduleView extends StatefulWidget {
  final String barbershopId;
  final Map<String, DaySchedule> initialSchedule;

  const EditScheduleView({
    super.key,
    required this.barbershopId,
    required this.initialSchedule,
  });

  @override
  State<EditScheduleView> createState() => _EditScheduleViewState();
}

class _EditScheduleViewState extends State<EditScheduleView> {
  late Map<String, DaySchedule> _schedule;

  @override
  void initState() {
    super.initState();
    _schedule = Map.of(
      widget.initialSchedule.isEmpty
          ? weekScheduleFromMap(null)
          : widget.initialSchedule,
    );
  }

  Future<void> _pickTime(String day, bool isOpenTime) async {
    final current = _schedule[day]!;
    final currentValue = isOpenTime ? current.openTime : current.closeTime;
    final parts = currentValue.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      _schedule[day] = isOpenTime
          ? current.copyWith(openTime: formatted)
          : current.copyWith(closeTime: formatted);
    });
  }

  static int _minutes(String hhmm) {
    final parts = hhmm.split(':');
    return (int.tryParse(parts[0]) ?? 0) * 60 +
        (int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
  }

  /// Días abiertos cuyo cierre no es posterior a la apertura.
  List<String> get _invalidDays => [
    for (final day in kWeekdays)
      if (_schedule[day]!.isOpen &&
          _minutes(_schedule[day]!.closeTime) <=
              _minutes(_schedule[day]!.openTime))
        day,
  ];

  Future<void> _save() async {
    final invalid = _invalidDays;
    if (invalid.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La hora de cierre debe ser posterior a la de apertura '
            '(${invalid.join(', ')}).',
          ),
        ),
      );
      return;
    }
    try {
      await context.read<BarbershopRepository>().updateSchedule(
        widget.barbershopId,
        _schedule,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: ${errorText(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invalid = _invalidDays.toSet();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Horarios de atención')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          children: [
            ResponsiveBody(
              maxWidth: AppLayout.formWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final day in kWeekdays) ...[
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                        vertical: AppSpace.xs,
                      ),
                      borderColor: invalid.contains(day)
                          ? AppColors.error
                          : null,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              day[0].toUpperCase() + day.substring(1),
                              style: text.titleSmall,
                            ),
                          ),
                          Switch(
                            value: _schedule[day]!.isOpen,
                            onChanged: (value) => setState(
                              () => _schedule[day] = _schedule[day]!.copyWith(
                                isOpen: value,
                              ),
                            ),
                          ),
                          if (_schedule[day]!.isOpen) ...[
                            TextButton(
                              onPressed: () => _pickTime(day, true),
                              child: Text(_schedule[day]!.openTime),
                            ),
                            Text(
                              '–',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            TextButton(
                              onPressed: () => _pickTime(day, false),
                              child: Text(_schedule[day]!.closeTime),
                            ),
                          ] else
                            Expanded(
                              child: Text(
                                'Cerrado',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                  const SizedBox(height: AppSpace.lg),
                  AppButton(
                    onPressed: _save,
                    icon: Icons.check_circle_outline,
                    child: const Text('Guardar horarios'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
