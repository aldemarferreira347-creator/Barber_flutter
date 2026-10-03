import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../models/barbershop.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/owner_report.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/responsive_body.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/stat_card.dart';

enum _Period {
  today('Hoy'),
  week('7 días'),
  month('30 días');

  final String label;

  const _Period(this.label);

  DateTime from(DateTime now) => switch (this) {
    _Period.today => DateTime(now.year, now.month, now.day),
    _Period.week => now.subtract(const Duration(days: 7)),
    _Period.month => now.subtract(const Duration(days: 30)),
  };
}

/// Informe del dueño: citas atendidas, clientes, ingresos y actividad por
/// barbero de sus barberías aprobadas, por periodo.
class OwnerReportView extends StatefulWidget {
  const OwnerReportView({super.key});

  @override
  State<OwnerReportView> createState() => _OwnerReportViewState();
}

class _OwnerReportViewState extends State<OwnerReportView> {
  _Period _period = _Period.week;
  late final Stream<List<Barbershop>> _shops = context
      .read<BarbershopRepository>()
      .watchByOwner(context.read<AuthController>().profile?.uid ?? '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informe')),
      body: StreamBuilder<List<Barbershop>>(
        stream: _shops,
        builder: (context, shopsSnapshot) {
          if (shopsSnapshot.hasError) {
            return const Center(
              child: ErrorState(title: 'No pudimos cargar tus barberías'),
            );
          }
          if (!shopsSnapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: ShimmerList(),
            );
          }
          final approved = [
            for (final shop in shopsSnapshot.data!)
              if (shop.approvalStatus == BarbershopApprovalStatus.approved)
                shop.id,
          ];
          if (approved.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.insights_outlined,
                title: 'Aún no hay datos',
                subtitle:
                    'El informe aparece cuando tienes una barbería aprobada.',
              ),
            );
          }
          return _ReportBody(
            shopIds: approved,
            period: _period,
            onPeriod: (period) => setState(() => _period = period),
          );
        },
      ),
    );
  }
}

class _ReportBody extends StatefulWidget {
  final List<String> shopIds;
  final _Period period;
  final ValueChanged<_Period> onPeriod;

  const _ReportBody({
    required this.shopIds,
    required this.period,
    required this.onPeriod,
  });

  @override
  State<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends State<_ReportBody> {
  late final Stream<List<Appointment>> _appointments = context
      .read<AppointmentRepository>()
      .watchByBarbershops(widget.shopIds);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
      children: [
        ResponsiveBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_Period>(
                segments: [
                  for (final p in _Period.values)
                    ButtonSegment(value: p, label: Text(p.label)),
                ],
                selected: {widget.period},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    widget.onPeriod(selection.first),
              ),
              const SizedBox(height: AppSpace.lg),
              StreamBuilder<List<Appointment>>(
                stream: _appointments,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const ErrorState(
                      title: 'No pudimos cargar las citas',
                    );
                  }
                  if (!snapshot.hasData) return const ShimmerList();
                  final now = DateTime.now();
                  final report = buildOwnerReport(
                    snapshot.data!,
                    from: widget.period.from(now),
                    now: now,
                  );
                  if (report.isEmpty) {
                    return const EmptyState(
                      icon: Icons.insights_outlined,
                      title: 'Sin actividad en este periodo',
                      subtitle: 'Prueba con un periodo más largo.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StatGrid(
                        children: [
                          StatCard(
                            icon: Icons.check_circle_outline,
                            iconColor: AppColors.success,
                            value: '${report.completed}',
                            label: 'Citas atendidas',
                          ),
                          StatCard(
                            icon: Icons.people_outline,
                            value: '${report.clientsServed}',
                            label: 'Clientes atendidos',
                          ),
                          StatCard(
                            icon: Icons.payments_outlined,
                            iconColor: AppColors.gold,
                            value: formatCop(report.revenue),
                            label: 'Ingresos por Nequi',
                          ),
                          StatCard(
                            icon: Icons.event_busy_outlined,
                            iconColor: AppColors.error,
                            value: '${report.lost}',
                            label: 'Canceladas',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.xl),
                      const SectionHeader(title: 'Por barbero'),
                      if (report.byBarber.isEmpty)
                        const SizedBox.shrink()
                      else
                        for (final row in report.byBarber) ...[
                          AppCard(
                            padding: const EdgeInsets.all(AppSpace.md),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        row.barberName,
                                        style: text.titleSmall,
                                      ),
                                      Text(
                                        '${row.completed} atendida(s)'
                                        '${row.lost > 0 ? ' · ${row.lost} perdida(s)' : ''}',
                                        style: text.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatCop(row.revenue),
                                  style: text.titleSmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpace.sm),
                        ],
                      const SizedBox(height: AppSpace.md),
                      Text(
                        'Los ingresos son los de las citas pagadas por Nequi '
                        'y completadas. "Canceladas" incluye las rechazadas. '
                        'Se calcula con las últimas 100 citas de cada '
                        'barbería.',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
