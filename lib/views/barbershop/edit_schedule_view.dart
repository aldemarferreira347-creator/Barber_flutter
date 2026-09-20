import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/day_schedule.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/gradient_button.dart';

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
  bool _saving = false;

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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<BarbershopRepository>().updateSchedule(
        widget.barbershopId,
        _schedule,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Horarios de atención')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in kWeekdays.indexed) ...[
            Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          entry.$2[0].toUpperCase() + entry.$2.substring(1),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Switch(
                        value: _schedule[entry.$2]!.isOpen,
                        onChanged: (value) => setState(
                          () => _schedule[entry.$2] = _schedule[entry.$2]!
                              .copyWith(isOpen: value),
                        ),
                      ),
                      if (_schedule[entry.$2]!.isOpen) ...[
                        TextButton(
                          onPressed: () => _pickTime(entry.$2, true),
                          child: Text(_schedule[entry.$2]!.openTime),
                        ),
                        Text(
                          '–',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        TextButton(
                          onPressed: () => _pickTime(entry.$2, false),
                          child: Text(_schedule[entry.$2]!.closeTime),
                        ),
                      ] else
                        Expanded(
                          child: Text(
                            'Cerrado',
                            textAlign: TextAlign.end,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                )
                .animate(delay: (entry.$1 * 40).ms)
                .fadeIn(duration: 260.ms)
                .slideX(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          GradientButton(
            onPressed: _saving ? null : _save,
            icon: _saving ? null : Icons.check_circle_outline,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Guardar horarios'),
          ),
        ],
      ),
    );
  }
}
