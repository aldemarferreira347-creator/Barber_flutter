import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_text.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/brand_mark.dart';
import '../widgets/custom_icons.dart';
import '../widgets/responsive_body.dart';
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit(AuthController auth) async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await auth.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!ok && mounted && auth.errorMessage != null) {
      _showMessage(auth.errorMessage!);
    }
  }

  Future<void> _submitGoogle(AuthController auth) async {
    final outcome = await auth.signInWithGoogle();
    if (!mounted) return;

    switch (outcome) {
      case null:
        if (auth.errorMessage != null) _showMessage(auth.errorMessage!);
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
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _PasswordConfirmDialog(email: email),
    );
    if (password == null || password.isEmpty || !mounted) return;

    final ok = await auth.confirmGoogleLinkWithPassword(
      email: email,
      password: password,
      pendingGoogleCredential: pendingGoogleCredential,
    );
    if (!ok && mounted && auth.errorMessage != null) {
      _showMessage(auth.errorMessage!);
    }
  }

  Future<void> _forgotPassword(AuthController auth) async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ResetPasswordDialog(initialEmail: _emailController.text.trim()),
    );
    if (email == null || email.isEmpty || !mounted) return;
    final ok = await auth.sendPasswordResetEmail(email);
    if (!mounted) return;
    _showMessage(
      ok
          ? 'Te enviamos un enlace a $email para restablecer tu contraseña.'
          : (auth.errorMessage ?? 'No se pudo enviar el correo'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
            child: ResponsiveBody(
              maxWidth: AppLayout.formWidth,
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandMark(size: 64, spin: false)),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        'BarberFlow',
                        textAlign: TextAlign.center,
                        style: text.headlineMedium,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'Tu barbería, siempre conectada',
                        textAlign: TextAlign.center,
                        style: text.secondary,
                      ),
                      const SizedBox(height: AppSpace.xxl),
                      Semantics(
                        header: true,
                        child: Text('Iniciar sesión', style: text.titleLarge),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'Accede a tu cuenta para continuar',
                        style: text.secondary,
                      ),
                      const SizedBox(height: AppSpace.xl),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (value) =>
                            (value == null || !value.contains('@'))
                            ? 'Correo inválido'
                            : null,
                      ),
                      const SizedBox(height: AppSpace.md),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(auth),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Ingresa tu contraseña'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _forgotPassword(auth),
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      AppButton(
                        loading: auth.isBusy,
                        onPressed: () => _submit(auth),
                        child: const Text('Iniciar sesión'),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '¿No tienes una cuenta? ',
                            style: text.secondary,
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterView(),
                              ),
                            ),
                            child: const Text('Regístrate'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.md,
                            ),
                            child: Text('o', style: text.bodySmall),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: AppSpace.lg),
                      AppButton(
                        variant: AppButtonVariant.secondary,
                        leading: const GoogleLogo(size: 20),
                        onPressed: auth.isBusy
                            ? null
                            : () => _submitGoogle(auth),
                        child: const Text('Continuar con Google'),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      AppButton(
                        variant: AppButtonVariant.text,
                        icon: Icons.phone_outlined,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PhoneLoginView(),
                          ),
                        ),
                        child: const Text('Continuar con teléfono'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pide la contraseña original para vincular Google a una cuenta ya creada
/// con correo y contraseña (spec 5.1). Es un widget propio para que el
/// controlador del campo se libere al cerrarse el diálogo.
class _PasswordConfirmDialog extends StatefulWidget {
  final String email;

  const _PasswordConfirmDialog({required this.email});

  @override
  State<_PasswordConfirmDialog> createState() => _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends State<_PasswordConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirma tu contraseña'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ya existe una cuenta registrada con ${widget.email} usando correo y contraseña. Confírmala para vincular tu cuenta de Google a ella.',
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _controller,
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
          onPressed: () => Navigator.of(context).pop(_controller.text),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: const Text('Vincular'),
        ),
      ],
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const _ResetPasswordDialog({required this.initialEmail});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final _controller = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recuperar contraseña'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Correo electrónico',
          prefixIcon: Icon(Icons.mail_outline),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: const Text('Enviar enlace'),
        ),
      ],
    );
  }
}
