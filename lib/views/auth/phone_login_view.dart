import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../widgets/gradient_button.dart';

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

  Future<void> _sendCode(AuthController auth) async {
    final phone = _phoneController.text.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usa formato internacional, ej. +573001234567'),
        ),
      );
      return;
    }
    final handle = await auth.startPhoneVerification(phone);
    if (handle == null) {
      if (mounted && auth.errorMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
      }
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
      if (auth.errorMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
      }
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

    return Scaffold(
      appBar: AppBar(title: const Text('Ingresar con teléfono')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                        codeStep ? Icons.sms_outlined : Icons.phone_iphone,
                        size: 48,
                        color: AppColors.accent,
                      )
                      .animate()
                      .fadeIn(duration: 320.ms)
                      .scaleXY(begin: 0.7, end: 1, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),
                  Text(
                    codeStep
                        ? 'Ingresa el código que te enviamos'
                        : 'Te vamos a enviar un código por SMS',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ).animate(delay: 80.ms).fadeIn(duration: 300.ms),
                  const SizedBox(height: 4),
                  Text(
                    codeStep
                        ? 'Enviado a ${_phoneController.text}'
                        : 'Escribe tu número con indicativo de país',
                    style: TextStyle(color: AppColors.textSecondary),
                  ).animate(delay: 120.ms).fadeIn(duration: 300.ms),
                  const SizedBox(height: 20),
                  if (!codeStep) ...[
                    TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        )
                        .animate(delay: 160.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 20),
                    GradientButton(
                      onPressed: auth.isBusy ? null : () => _sendCode(auth),
                      icon: auth.isBusy ? null : Icons.send_outlined,
                      child: auth.isBusy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Enviar código'),
                    ),
                  ] else ...[
                    TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Código de 6 dígitos',
                            prefixIcon: Icon(Icons.sms_outlined),
                          ),
                        )
                        .animate(delay: 160.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 20),
                    GradientButton(
                      onPressed: auth.isBusy ? null : () => _confirmCode(auth),
                      icon: auth.isBusy ? null : Icons.check_circle_outline,
                      child: auth.isBusy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Confirmar código'),
                    ),
                    TextButton(
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
