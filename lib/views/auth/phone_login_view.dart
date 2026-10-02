import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/responsive_body.dart';

class PhoneLoginView extends StatefulWidget {
  const PhoneLoginView({super.key});

  @override
  State<PhoneLoginView> createState() => _PhoneLoginViewState();
}

class _PhoneLoginViewState extends State<PhoneLoginView> {
  final _phoneController = TextEditingController(text: '+57');
  final _codeController = TextEditingController();
  PhoneCodeHandle? _codeHandle;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendCode(AuthController auth) async {
    final phone = _phoneController.text.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      _showMessage('Usa formato internacional, ej. +573001234567');
      return;
    }
    final handle = await auth.startPhoneVerification(phone);
    if (!mounted) return;
    if (handle == null) {
      if (auth.errorMessage != null) _showMessage(auth.errorMessage!);
      return;
    }
    setState(() => _codeHandle = handle);
  }

  Future<void> _confirmCode(AuthController auth) async {
    final handle = _codeHandle;
    if (handle == null) return;
    final ok = await auth.confirmPhoneCode(handle, _codeController.text.trim());
    if (!mounted) return;
    if (!ok) {
      if (auth.errorMessage != null) _showMessage(auth.errorMessage!);
      return;
    }
    // Esta vista quedó pushed encima del AuthGate: hay que salir para que
    // se vea la home ya actualizada que el AuthGate arma por debajo.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final codeStep = _codeHandle != null;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ingresar con teléfono')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ResponsiveBody(
              maxWidth: AppLayout.formWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    codeStep ? Icons.sms_outlined : Icons.phone_iphone,
                    size: 48,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Semantics(
                    header: true,
                    child: Text(
                      codeStep
                          ? 'Ingresa el código que te enviamos'
                          : 'Te vamos a enviar un código por SMS',
                      textAlign: TextAlign.center,
                      style: text.titleLarge,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    codeStep
                        ? 'Enviado a ${_phoneController.text}'
                        : 'Escribe tu número con indicativo de país',
                    textAlign: TextAlign.center,
                    style: text.secondary,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  if (!codeStep) ...[
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    AppButton(
                      loading: auth.isBusy,
                      onPressed: () => _sendCode(auth),
                      icon: Icons.send_outlined,
                      child: const Text('Enviar código'),
                    ),
                  ] else ...[
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(
                        labelText: 'Código de 6 dígitos',
                        prefixIcon: Icon(Icons.sms_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    AppButton(
                      loading: auth.isBusy,
                      onPressed: () => _confirmCode(auth),
                      icon: Icons.check_circle_outline,
                      child: const Text('Confirmar código'),
                    ),
                    AppButton(
                      variant: AppButtonVariant.text,
                      onPressed: () => setState(() => _codeHandle = null),
                      child: const Text('Cambiar número'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
