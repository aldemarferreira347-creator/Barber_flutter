import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../models/shop_closure.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/shop_closure_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../../utils/error_text.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/responsive_body.dart';

/// Frase con lo que provoca un cierre, para el aviso de confirmación.
String closureImpactText(ClosureImpact impact) {
  if (impact.total == 0) {
    return 'Ahora mismo no hay citas ni compras abiertas que se vean '
        'afectadas.';
  }
  final parts = [
    if (impact.paidAppointments > 0)
      '${impact.paidAppointments} cita(s) pagada(s) quedarán aplazadas',
    if (impact.unpaidAppointments > 0)
      '${impact.unpaidAppointments} cita(s) sin pago se cancelarán',
    if (impact.purchases > 0)
      '${impact.purchases} compra(s) de productos seguirán pendientes',
  ];
  return '${parts.join('; ')}. Cada cliente afectado recibirá un aviso en la '
      'app.';
}

/// Cierre de tienda por evento externo (spec 3.4): el dueño elige desde
/// cuándo, hasta cuándo (opcional) y el motivo. Sin fecha de regreso la
/// barbería queda cerrada hasta que él mismo la reabra, y antes de hacerlo la
/// app pide confirmación explícita. Cada cliente con una cita o una compra
/// abierta recibe un aviso.
class CloseShopView extends StatefulWidget {
  final String barbershopId;

  const CloseShopView({super.key, required this.barbershopId});

  @override
  State<CloseShopView> createState() => _CloseShopViewState();
}

class _CloseShopViewState extends State<CloseShopView> {
  final _reasonController = TextEditingController();
  late DateTime _from = _roundedNow();
  DateTime? _until;
  ClosureResult? _result;
  String? _error;
  bool _working = false;

  static DateTime _roundedNow() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickFrom() async {
    final picked = await _pickDateTime(_from);
    if (picked != null) {
      setState(() {
        _from = picked;
        _error = null;
      });
    }
  }

  Future<void> _pickUntil() async {
    final picked = await _pickDateTime(
      _until ?? _from.add(const Duration(hours: 4)),
    );
    if (picked != null) {
      setState(() {
        _until = picked;
        _error = null;
      });
    }
  }

  /// Mensaje de validación, o null si el formulario está completo.
  String? _validate() {
    final until = _until;
    if (until != null && !until.isAfter(_from)) {
      return 'El final del cierre debe ser posterior al inicio.';
    }
    if (_reasonController.text.trim().isEmpty) {
      return 'Escribe el motivo del cierre.';
    }
    return null;
  }

  Future<void> _confirm() async {
    final problem = _validate();
    setState(() => _error = problem);
    if (problem != null) return;

    final repo = context.read<ShopClosureRepository>();
    setState(() => _working = true);
    ClosureImpact impact;
    try {
      impact = await repo.previewImpact(
        barbershopId: widget.barbershopId,
        closedFrom: _from,
        closedUntil: _until,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = 'No se pudo revisar qué reservas afecta: ${errorText(e)}';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _working = false);

    final indefinite = _until == null;
    final ok = await AppDialog.confirm(
      context,
      title: indefinite ? '¿Cerrar hasta nuevo aviso?' : 'Cerrar la barbería',
      message: indefinite
          ? 'No elegiste una fecha de regreso: la barbería quedará cerrada '
                'desde ${numericDateTimeLabel(_from)} y NO volverá a recibir '
                'reservas hasta que tú la reabras.\n\n'
                '${closureImpactText(impact)}\n\n'
                '¿Estás seguro de cerrar hasta nuevo aviso?'
          : 'La barbería quedará cerrada entre ${numericDateTimeLabel(_from)} '
                'y ${numericDateTimeLabel(_until!)}.\n\n'
                '${closureImpactText(impact)}\n\n'
                'Las citas pagadas llevarán un descuento de 1 estrella en su '
                'calificación. No se puede deshacer.',
      confirmLabel: indefinite ? 'Sí, cerrar hasta nuevo aviso' : 'Cerrar',
      cancelLabel: indefinite ? 'No, elegir una fecha' : 'Volver',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _working = true);
    try {
      final result = await repo.closeForExternalEvent(
        barbershopId: widget.barbershopId,
        closedFrom: _from,
        closedUntil: _until,
        reason: _reasonController.text.trim(),
      );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo cerrar la barbería: ${errorText(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _reopen() async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Reabrir la barbería',
      message:
          'La barbería volverá a aparecer abierta y los clientes podrán '
          'reservar de nuevo. Las citas que se aplazaron o cancelaron no se '
          'recuperan solas.',
      confirmLabel: 'Sí, reabrir',
      cancelLabel: 'Volver',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    try {
      await context.read<ShopClosureRepository>().reopen(widget.barbershopId);
      messenger.showSnackBar(
        const SnackBar(content: Text('La barbería volvió a abrir.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo reabrir: ${errorText(e)}')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Cerrar por evento externo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          children: [
            ResponsiveBody(
              maxWidth: AppLayout.formWidth,
              child: result != null
                  ? _buildResult(context, result)
                  : StreamBuilder<Barbershop?>(
                      stream: context.read<BarbershopRepository>().watchOne(
                        widget.barbershopId,
                      ),
                      builder: (context, snapshot) {
                        final closure = snapshot.data?.closure;
                        final active =
                            closure != null &&
                            (closure.until == null ||
                                closure.until!.isAfter(DateTime.now()));
                        return active
                            ? _buildClosed(context, closure)
                            : _buildForm(context);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// La barbería ya está cerrada: muestra desde cuándo y permite reabrirla.
  Widget _buildClosed(BuildContext context, ShopClosure closure) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: AppColors.tint(AppColors.warning),
          borderColor: AppColors.warning.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    color: AppColors.readable(AppColors.warning),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text('Barbería cerrada', style: text.titleMedium),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                'Desde ${numericDateTimeLabel(closure.from)} '
                '${closure.untilLabel(numericDateTimeLabel)}.',
                style: text.bodyMedium,
              ),
              if (closure.reason.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xs),
                Text('Motivo: ${closure.reason}', style: text.secondary),
              ],
              const SizedBox(height: AppSpace.sm),
              Text(
                'Mientras esté cerrada los clientes no pueden reservar ni '
                'comprar.',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        AppButton(
          onPressed: _working ? null : _reopen,
          loading: _working,
          icon: Icons.storefront_outlined,
          child: const Text('Reabrir barbería'),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, ClosureResult result) {
    final parts = [
      if (result.postponed > 0)
        '${result.postponed} cita(s) pagada(s) aplazada(s)',
      if (result.cancelled > 0) '${result.cancelled} cita(s) cancelada(s)',
      if (result.purchasesNotified > 0)
        '${result.purchasesNotified} compra(s) pendiente(s)',
    ];
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        const SizedBox(height: AppSpace.xxl),
        Icon(
          Icons.check_circle_outline,
          color: AppColors.readable(AppColors.success),
          size: 56,
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          'La barbería quedó cerrada.',
          textAlign: TextAlign.center,
          style: text.titleLarge,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          parts.isEmpty
              ? 'No había reservas ni compras abiertas que se vieran '
                    'afectadas.'
              : '${parts.join(', ')}. Se avisó a ${result.notificationsSent} '
                    'cliente(s) en la app.',
          textAlign: TextAlign.center,
          style: text.bodyLarge,
        ),
        if (result.notificationsFailed > 0) ...[
          const SizedBox(height: AppSpace.md),
          Text(
            'No se pudo avisar a ${result.notificationsFailed} cliente(s). '
            'El cierre sí se aplicó: considera escribirles por otro medio.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: AppColors.readable(AppColors.warning),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        AppButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Listo'),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: AppColors.tint(AppColors.warning),
          borderColor: AppColors.warning.withValues(alpha: 0.4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.readable(AppColors.warning),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  'Las citas pagadas del cierre se aplazan para que el '
                  'cliente reprograme (con un descuento obligatorio de 1 '
                  'estrella en su calificación); las que no tenían pago se '
                  'cancelan. Cada cliente con una cita o una compra abierta '
                  'recibe un aviso. Si no pones fecha de regreso, la '
                  'barbería queda cerrada hasta que la reabras.',
                  style: text.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        AppButton(
          variant: AppButtonVariant.secondary,
          onPressed: _pickFrom,
          icon: Icons.event,
          child: Text('Desde: ${numericDateTimeLabel(_from)}'),
        ),
        const SizedBox(height: AppSpace.md),
        AppButton(
          variant: AppButtonVariant.secondary,
          onPressed: _pickUntil,
          icon: Icons.event_available_outlined,
          child: Text(
            _until == null
                ? 'Hasta: sin fecha de regreso'
                : 'Hasta: ${numericDateTimeLabel(_until!)}',
          ),
        ),
        if (_until != null)
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              variant: AppButtonVariant.text,
              expand: false,
              onPressed: () => setState(() => _until = null),
              child: const Text('Quitar fecha de regreso'),
            ),
          ),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _reasonController,
          maxLines: 3,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: const InputDecoration(
            labelText: 'Motivo del cierre',
            hintText: 'Corte de energía, emergencia, remodelación...',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: text.bodyMedium?.copyWith(
                color: AppColors.readable(AppColors.error),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        AppButton(
          variant: AppButtonVariant.destructive,
          onPressed: _working ? null : _confirm,
          loading: _working,
          icon: Icons.event_busy_outlined,
          child: const Text('Confirmar cierre'),
        ),
      ],
    );
  }
}
