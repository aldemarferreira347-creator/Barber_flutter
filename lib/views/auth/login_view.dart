import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../widgets/brand_mark.dart';
import '../widgets/gradient_button.dart';
import 'phone_login_view.dart';
import 'register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthController auth) async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await auth.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!ok && mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
    }
  }

  Future<void> _submitGoogle(AuthController auth) async {
    final outcome = await auth.signInWithGoogle();
    if (!mounted) return;

    switch (outcome) {
      case null:
        if (auth.errorMessage != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
        }
      case GoogleSignInCancelled():
        break;
      case GoogleSignInSuccess():
        break;
      case GoogleSignInRequiresPasswordLink(
        :final email,
        :final pendingGoogleCredential,
      ):
        await _linkGoogleWithPassword(
          auth,
          email: email,
          pendingGoogleCredential: pendingGoogleCredential,
        );
    }
  }

  Future<void> _linkGoogleWithPassword(
    AuthController auth, {
    required String email,
    required AuthCredential pendingGoogleCredential,
  }) async {
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirma tu contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ya existe una cuenta registrada con $email usando correo y contraseña. Confírmala para vincular tu cuenta de Google a ella.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(passwordController.text),
            child: const Text('Vincular'),
          ),
        ],
      ),
    );
    if (password == null || password.isEmpty || !mounted) return;

    final ok = await auth.confirmGoogleLinkWithPassword(
      email: email,
      password: password,
      pendingGoogleCredential: pendingGoogleCredential,
    );
    if (!ok && mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
    }
  }

  Future<void> _forgotPassword(AuthController auth) async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo electrónico',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;
    final ok = await auth.sendPasswordResetEmail(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Te enviamos un enlace a $email para restablecer tu contraseña.'
              : (auth.errorMessage ?? 'No se pudo enviar el correo'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LoginHero()
                        .animate()
                        .scale(
                          begin: const Offset(0.7, 0.7),
                          curve: Curves.elasticOut,
                          duration: 800.ms,
                        )
                        .fadeIn(duration: 300.ms),
                    const SizedBox(height: 28),
                    const Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 320.ms)
                        .slideY(
                          begin: 0.15,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 4),
                    Text(
                      'Accede a tu cuenta para continuar',
                      style: TextStyle(color: AppColors.textSecondary),
                    ).animate(delay: 60.ms).fadeIn(duration: 320.ms),
                    const SizedBox(height: 24),
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
                        .animate(delay: 120.ms)
                        .fadeIn(duration: 320.ms)
                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
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
                        .animate(delay: 180.ms)
                        .fadeIn(duration: 320.ms)
                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: auth.isBusy
                            ? null
                            : () => _forgotPassword(auth),
                        child: const Text('¿Olvidaste tu contraseña?'),
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
                              : const Text('Iniciar sesión'),
                        )
                        .animate(delay: 240.ms)
                        .fadeIn(duration: 320.ms)
                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterView(),
                          ),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: AppColors.textSecondary),
                            children: [
                              const TextSpan(text: '¿No tienes una cuenta? '),
                              TextSpan(
                                text: 'Regístrate',
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'o',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: auth.isBusy ? null : () => _submitGoogle(auth),
                      icon: const Icon(Icons.g_mobiledata, size: 26),
                      label: const Text('Continuar con Google'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: auth.isBusy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PhoneLoginView(),
                              ),
                            ),
                      icon: const Icon(Icons.phone_outlined),
                      label: const Text('Continuar con teléfono'),
                    ),
                    const SizedBox(height: 28),
                    const _LoginFooterStrip()
                        .animate(delay: 300.ms)
                        .fadeIn(duration: 500.ms),
                    const SizedBox(height: 16),
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

class _LoginFooterStrip extends StatelessWidget {
  const _LoginFooterStrip();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, const Color(0xFF1E293B)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -14,
              child: Icon(
                Icons.content_cut,
                size: 60,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              left: 16,
              bottom: -18,
              child: Icon(
                Icons.storefront_outlined,
                size: 70,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Center(
              child: Text(
                'Miles de barberías ya confían en BarberFlow',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(size: 56),
        const SizedBox(height: 10),
        Text(
          'BarberFlow',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tu barbería, siempre conectada',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}
