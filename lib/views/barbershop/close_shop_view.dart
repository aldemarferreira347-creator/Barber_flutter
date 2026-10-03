import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/shop_closure_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/responsive_body.dart';
import '../../utils/error_text.dart';

/// Cierre de tienda por evento externo (spec 3.4): el dueño elige el rango
/// de fechas/horas afectado y el motivo. Cada reserva pagada dentro de ese
/// rango queda aplazada y el cliente la ve como "Aplazada" en sus citas
/// para reprogramarla (no hay envío de avisos sin servidor).
class CloseShopView extends StatefulWidget {
  final String barbershopId;

  const CloseShopView({super.key, required this.barbershopId});

  @override
  State<CloseShopView> createState() => _CloseShopViewState();
}

class _CloseShopViewState extends State<CloseShopView> {
  final _reasonController = TextEditingController();
  DateTime? _from;
  DateTime? _until;
  int? _appointmentsAffected;
  String? _error;

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
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
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
    final picked = await _pickDateTime(_from ?? DateTime.now());
    if (picked != null) {
      setState(() {
        _from = picked;
        _error = null;
      });
    }
  }

  Future<void> _pickUntil() async {
    final picked = await _pickDateTime(
      _until ?? (_from ?? DateTime.now()).add(const Duration(hours: 4)),
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
    final from = _from;
    final until = _until;
    if (from == null || until == null) {
      return 'Elige desde cuándo y hasta cuándo estará cerrada la barbería.';
    }
    if (!until.isAfter(from)) {
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

    final ok = await AppDialog.confirm(
      context,
      title: 'Cerrar la barbería',
      message:
          'Las reservas pagadas entre ${numericDateTimeLabel(_from!)} y '
          '${numericDateTimeLabel(_until!)} quedarán aplazadas y su '
          'calificación tendrá un descuento de 1 estrella. No se puede '
          'deshacer.',
      confirmLabel: 'Cerrar y aplazar',
      destructive: true,
    );
    if (!ok || !mounted) return;

    try {
      final affected = await context
          .read<ShopClosureRepository>()
          .closeForExternalEvent(
            barbershopId: widget.barbershopId,
            closedFrom: _from!,
            closedUntil: _until!,
            reason: _reasonController.text.trim(),
          );
      if (mounted) setState(() => _appointmentsAffected = affected);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo cerrar la barbería: ${errorText(e)}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final affected = _appointmentsAffected;
    return Scaffold(
      appBar: AppBar(title: const Text('Cerrar por evento externo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          children: [
            ResponsiveBody(
              maxWidth: AppLayout.formWidth,
              child: affected != null
                  ? _buildResult(context, affected)
                  : _buildForm(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context, int affected) {
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
          affected == 0
              ? 'No había reservas pagadas afectadas en ese rango.'
              : 'Se aplazaron $affected reserva(s) pagada(s). Cada cliente la '
                    'verá como "Aplazada" en sus citas para reprogramarla.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
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
                  'Las reservas pagadas dentro de este rango quedarán '
                  'aplazadas y sus clientes podrán reprogramar. Su '
                  'calificación final tendrá un descuento obligatorio de 1 '
                  'estrella, porque el cierre afecta su experiencia aunque no '
                  'dependa de la barbería.',
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
          child: Text(
            _from == null
                ? 'Desde: elegir fecha y hora'
                : 'Desde: ${numericDateTimeLabel(_from!)}',
          ),
        ),
        const SizedBox(height: AppSpace.md),
        AppButton(
          variant: AppButtonVariant.secondary,
          onPressed: _pickUntil,
          icon: Icons.event,
          child: Text(
            _until == null
                ? 'Hasta: elegir fecha y hora'
                : 'Hasta: ${numericDateTimeLabel(_until!)}',
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
            hintText: 'Corte de energía, emergencia…',
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
          onPressed: _confirm,
          icon: Icons.event_busy_outlined,
          child: const Text('Confirmar cierre'),
        ),
      ],
    );
  }
}
