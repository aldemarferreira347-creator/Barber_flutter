import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../repositories/shop_closure_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/gradient_button.dart';

/// Cierre de tienda por evento externo (spec 3.4): el dueño elige el rango
/// de fechas/horas afectado y el motivo. Cada reserva pagada dentro de ese
/// rango queda aplazada automáticamente y se notifica al cliente.
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
  bool _saving = false;
  int? _appointmentsAffected;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
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
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickUntil() async {
    final picked = await _pickDateTime(
      _until ?? (_from ?? DateTime.now()).add(const Duration(hours: 4)),
    );
    if (picked != null) setState(() => _until = picked);
  }

  Future<void> _confirm() async {
    final from = _from;
    final until = _until;
    if (from == null || until == null || _reasonController.text.trim().isEmpty)
      return;

    setState(() => _saving = true);
    try {
      final affected = await context
          .read<ShopClosureRepository>()
          .closeForExternalEvent(
            barbershopId: widget.barbershopId,
            closedFrom: from,
            closedUntil: until,
            reason: _reasonController.text.trim(),
          );
      setState(() => _appointmentsAffected = affected);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cerrar la barbería: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _label(DateTime? value) =>
      value == null ? 'Elegir fecha y hora' : value.toString().substring(0, 16);

  @override
  Widget build(BuildContext context) {
    final affected = _appointmentsAffected;
    return Scaffold(
      appBar: AppBar(title: const Text('Cerrar por evento externo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: affected != null ? _buildResult(affected) : _buildForm(),
      ),
    );
  }

  Widget _buildResult(int affected) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 56,
              )
              .animate()
              .fadeIn(duration: 320.ms)
              .scaleXY(begin: 0.6, end: 1, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text(
            affected == 0
                ? 'No había reservas pagadas afectadas en ese rango.'
                : 'Se aplazaron $affected reserva(s) pagada(s) y se notificó a cada cliente.',
            textAlign: TextAlign.center,
          ).animate(delay: 120.ms).fadeIn(duration: 300.ms),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            child: GradientButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Listo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      children: [
        Text(
          'Las reservas pagadas dentro de este rango quedarán aplazadas y sus clientes serán invitados a reprogramar. '
          'Su calificación final tendrá un descuento obligatorio de 1 estrella, ya que el cierre afecta su experiencia '
          'aunque no dependa de la barbería.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _pickFrom,
          icon: const Icon(Icons.event),
          label: Text('Desde: ${_label(_from)}'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pickUntil,
          icon: const Icon(Icons.event),
          label: Text('Hasta: ${_label(_until)}'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Motivo del cierre (p. ej. corte de energía, emergencia)',
          ),
        ),
        const SizedBox(height: 24),
        GradientButton(
          onPressed: (_from != null && _until != null && !_saving)
              ? _confirm
              : null,
          icon: _saving ? null : Icons.event_busy_outlined,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirmar cierre'),
        ),
      ],
    );
  }
}
