import 'package:flutter/material.dart';

import '../../models/appointment.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'app_card.dart';
import 'status_badge.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final String subtitle;
  final List<Widget> actions;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.subtitle,
    this.actions = const [],
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
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(appointment.serviceName, style: text.titleSmall),
              ),
              const SizedBox(width: AppSpace.sm),
              StatusBadge(label: appointment.status.label, color: _statusColor),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(subtitle, style: text.bodyMedium),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpace.xs),
              Text(_dateLabel, style: text.bodySmall),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
