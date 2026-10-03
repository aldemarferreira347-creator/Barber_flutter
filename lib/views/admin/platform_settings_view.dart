import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../models/platform_settings.dart';
import '../../repositories/platform_settings_repository.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/error_state.dart';
import '../widgets/responsive_body.dart';
import '../widgets/shimmer_box.dart';
import '../../utils/error_text.dart';

/// Datos de cobro de la plataforma: a qué Nequi transfieren los dueños su
/// mensualidad, cuánto cuesta y cuántos días de gracia tienen tras
/// vencerse antes del bloqueo. Solo el admin (también lo exigen las reglas).
class PlatformSettingsView extends StatelessWidget {
  const PlatformSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos de cobro')),
      body: StreamBuilder<PlatformSettings>(
        stream: context.read<PlatformSettingsRepository>().watch(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: ErrorState(title: 'No pudimos cargar la configuración'),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: ShimmerList(itemHeight: 64),
            );
          }
          return _SettingsForm(settings: snapshot.data!);
        },
      ),
    );
  }
}

class _SettingsForm extends StatefulWidget {
  final PlatformSettings settings;

  const _SettingsForm({required this.settings});

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _phone = TextEditingController(
    text: widget.settings.nequiPhone ?? '',
  );
  late final _holder = TextEditingController(
    text: widget.settings.nequiHolder ?? '',
  );
  late final _fee = TextEditingController(
    text: widget.settings.monthlyFee.round().toString(),
  );
  late final _grace = TextEditingController(
    text: widget.settings.graceDays.toString(),
  );

  @override
  void dispose() {
    _phone.dispose();
    _holder.dispose();
    _fee.dispose();
    _grace.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = context.read<PlatformSettingsRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.save(
        nequiPhone: _phone.text,
        nequiHolder: _holder.text,
        monthlyFee: double.parse(_fee.text.trim()),
        graceDays: int.parse(_grace.text.trim()),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Datos de cobro guardados')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo guardar: ${errorText(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
        children: [
          ResponsiveBody(
            maxWidth: AppLayout.formWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Los dueños transfieren aquí su mensualidad y registran la '
                  'referencia del comprobante; tú verificas cada pago en tu '
                  'Nequi antes de confirmarlo.',
                  style: text.secondary,
                ),
                const SizedBox(height: AppSpace.xl),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nequi de la plataforma',
                    helperText: 'Celular de 10 dígitos, empieza en 3',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  validator: (v) => validateNequiPhone(v, required: true),
                ),
                const SizedBox(height: AppSpace.lg),
                TextFormField(
                  controller: _holder,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Titular de la cuenta (opcional)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                TextFormField(
                  controller: _fee,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Mensualidad por barbería (COP)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (v) {
                    final value = double.tryParse((v ?? '').trim());
                    if (value == null || value <= 0) {
                      return 'Escribe un valor mayor que 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpace.lg),
                TextFormField(
                  controller: _grace,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Días de gracia tras el vencimiento',
                    helperText:
                        'Pasados esos días la barbería deja de recibir citas',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  validator: (v) {
                    final value = int.tryParse((v ?? '').trim());
                    if (value == null || value < 0 || value > 30) {
                      return 'Entre 0 y 30 días';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpace.xl),
                AppButton(
                  onPressed: _save,
                  icon: Icons.save_outlined,
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
