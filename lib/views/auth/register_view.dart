import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../help/privacy_policy_view.dart';
import '../widgets/brand_mark.dart';
import '../widgets/gradient_button.dart';
import 'register_success_view.dart';

/// Autorregistro público: siempre crea una cuenta de Cliente. Ser Dueño
/// requiere pagar la suscripción (fase futura); Barbero lo crea su Dueño;
/// Admin no se autorregistra. Por eso este formulario no ofrece selector de
/// rol.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthController auth) async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await auth.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
    );
    if (!ok && mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
    } else if (ok && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RegisterSuccessView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                          child: Column(
                            children: [
                              const BrandMark(size: 44),
                              const SizedBox(height: 8),
                              Text(
                                'BarberFlow',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .scale(
                          begin: const Offset(0.6, 0.6),
                          curve: Curves.elasticOut,
                          duration: 800.ms,
                        )
                        .fadeIn(duration: 300.ms),
                    const SizedBox(height: 20),
                    const Text(
                          'Crear cuenta',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                        .animate(delay: 150.ms)
                        .fadeIn(duration: 320.ms)
                        .slideY(
                          begin: 0.15,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 4),
                    Text(
                      'Completa la información para registrarte como cliente',
                      style: TextStyle(color: AppColors.textSecondary),
                    ).animate(delay: 200.ms).fadeIn(duration: 320.ms),
                    const SizedBox(height: 20),
                    TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Requerido'
                              : null,
                        )
                        .animate(delay: 250.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(
                          begin: 0.15,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 14),
                    TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (value) =>
                              (value == null || !value.contains('@'))
                              ? 'Correo inválido'
                              : null,
                        )
                        .animate(delay: 300.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(
                          begin: 0.15,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 14),
                    TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              (value == null || value.length < 6)
                              ? 'Mínimo 6 caracteres'
                              : null,
                        )
                        .animate(delay: 350.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(
                          begin: 0.15,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 14),
                    TextFormField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirmar contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value != _passwordController.text
                              ? 'Las contraseñas no coinciden'
                              : null,
                        )
                        .animate(delay: 400.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(
                          begin: 0.15,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '¿Eres dueño de una barbería? Esa cuenta se habilita pagando la suscripción, desde tu perfil una vez inicies sesión.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Términos y condiciones'),
                                content: const Text(
                                  'Al registrarte aceptas el uso de tus datos para gestionar tus citas y tu cuenta en BarberFlow.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Entendido'),
                                  ),
                                ],
                              ),
                            ),
                            child: Text(
                              'Términos y condiciones',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            '  ·  ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyView(),
                              ),
                            ),
                            child: Text(
                              'Política de privacidad',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    GradientButton(
                      onPressed: auth.isBusy ? null : () => _submit(auth),
                      child: auth.isBusy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Registrarse'),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: AppColors.textSecondary),
                            children: [
                              const TextSpan(text: '¿Ya tienes una cuenta? '),
                              TextSpan(
                                text: 'Inicia sesión',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
