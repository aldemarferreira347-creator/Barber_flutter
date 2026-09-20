import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/appointment.dart';
import '../../theme/app_colors.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final String subtitle;
  final List<Widget> actions;
  final int animationIndex;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.subtitle,
    this.actions = const [],
    this.animationIndex = 0,
  });

  Color get _statusColor => switch (appointment.status) {
    AppointmentStatus.pending => AppColors.warning,
    AppointmentStatus.accepted => AppColors.success,
    AppointmentStatus.rejected => AppColors.error,
    AppointmentStatus.cancelled => AppColors.error,
    AppointmentStatus.postponed => AppColors.accent,
    AppointmentStatus.completed => AppColors.textSecondary,
  };

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String get _dateLabel {
    final d = appointment.date;
    return '${_twoDigits(d.day)}/${_twoDigits(d.month)}/${d.year} · ${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: _statusColor.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      appointment.serviceName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      appointment.status.label,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _dateLabel,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: actions,
                ),
              ],
            ],
          ),
        )
        .animate(delay: (animationIndex * 70).ms)
        .fadeIn(duration: 320.ms)
        .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic);
  }
}
