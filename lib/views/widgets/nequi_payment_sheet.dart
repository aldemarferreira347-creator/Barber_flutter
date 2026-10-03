import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/barbershop.dart';
import '../../models/payment_record.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_dialog.dart';

/// Hoja para pagar por Nequi de forma manual: muestra a qué número y
/// cuánto transferir, y pide la referencia del comprobante. El pago no se
/// cobra desde la app: queda en verificación hasta que quien recibe el
/// dinero confirme que le llegó.
///
/// Devuelve la referencia escrita, o `null` si se cerró sin enviar.
Future<String?> showNequiPaymentSheet(
  BuildContext context, {
  required String title,
  required double amount,
  required String payeeName,
  required String payeePhone,
  String? verifier,
}) {
  return AppBottomSheet.show<String>(
    context,
    title: title,
    child: _NequiPaymentForm(
      amount: amount,
      payeeName: payeeName,
      payeePhone: payeePhone,
      verifier: verifier ?? payeeName,
    ),
  );
}

class _NequiPaymentForm extends StatefulWidget {
  final double amount;
  final String payeeName;
  final String payeePhone;
  final String verifier;

  const _NequiPaymentForm({
    required this.amount,
    required this.payeeName,
    required this.payeePhone,
    required this.verifier,
  });

  @override
  State<_NequiPaymentForm> createState() => _NequiPaymentFormState();
}

class _NequiPaymentFormState extends State<_NequiPaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _reference = TextEditingController();

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(normalizePaymentReference(_reference.text));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Transfiere desde tu app Nequi y luego registra el comprobante.',
            style: text.secondary,
          ),
          const SizedBox(height: AppSpace.lg),
          AppCard(
            color: AppColors.surfaceRaised,
            child: Column(
              children: [
                _CopyRow(
                  label: 'Valor exacto',
                  value: formatCop(widget.amount),
                  copyValue: widget.amount.round().toString(),
                  tooltip: 'Copiar valor',
                ),
                const Divider(height: AppSpace.xl),
                _CopyRow(
                  label: 'Nequi de ${widget.payeeName}',
                  value: formatNequiPhone(widget.payeePhone),
                  copyValue: normalizeNequiPhone(widget.payeePhone),
                  tooltip: 'Copiar número Nequi',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          TextFormField(
            controller: _reference,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            maxLength: 30,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Referencia del comprobante',
              helperText: 'La ves en el comprobante de Nequi (ej. M1234567)',
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
            validator: validatePaymentReference,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Tu pago queda en verificación hasta que ${widget.verifier} '
            'confirme que recibió el dinero.',
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpace.lg),
          AppButton(
            onPressed: _submit,
            icon: Icons.send_outlined,
            child: const Text('Ya pagué, enviar comprobante'),
          ),
        ],
      ),
    );
  }
}

class _CopyRow extends StatefulWidget {
  final String label;
  final String value;
  final String copyValue;
  final String tooltip;

  const _CopyRow({
    required this.label,
    required this.value,
    required this.copyValue,
    required this.tooltip,
  });

  @override
  State<_CopyRow> createState() => _CopyRowState();
}

class _CopyRowState extends State<_CopyRow> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.copyValue));
    if (!mounted) return;
    // La hoja modal tapa los SnackBar: el aviso es el propio ícono.
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label, style: text.bodySmall),
              const SizedBox(height: 2),
              Text(widget.value, style: text.titleMedium),
            ],
          ),
        ),
        IconButton(
          tooltip: _copied ? 'Copiado' : widget.tooltip,
          icon: Icon(
            _copied ? Icons.check : Icons.copy_outlined,
            color: _copied ? AppColors.readable(AppColors.success) : null,
          ),
          onPressed: _copy,
        ),
      ],
    );
  }
}
