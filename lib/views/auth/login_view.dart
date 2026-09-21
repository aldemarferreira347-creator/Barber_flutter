import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../widgets/brand_mark.dart';
import '../widgets/custom_icons.dart';
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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo oscuro de la barbería visible en la parte inferior
          Image.asset(
            'lib/views/img/fondo.png',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),
          // Contenedor blanco con bordes inferiores redondeados.
          // Se usa SingleChildScrollView directamente como child del Container
          // para que la tarjeta blanca ocupe solo el espacio de su contenido.
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Cabecera con logo BarberFlow
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const BrandMark(
                                  size: 58,
                                  color: Color(0xFF0F172A),
                                  spin: false,
                                )
                                    .animate()
                                    .scale(
                                      begin: const Offset(0.7, 0.7),
                                      curve: Curves.elasticOut,
                                      duration: 800.ms,
                                    )
                                    .fadeIn(duration: 300.ms),
                                const SizedBox(height: 8),
                                const Text(
                                  'BarberFlow',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tu barbería, siempre conectada',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),

                          // Título "Iniciar sesión"
                          Center(
                            child: Column(
                              children: [
                                const Text(
                                  'Iniciar sesión',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Accede a tu cuenta para continuar',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .slideY(
                                begin: 0.15,
                                end: 0,
                                curve: Curves.easeOutCubic,
                              ),
                          const SizedBox(height: 20),

                          // Campo: Correo electrónico
                          TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Correo electrónico',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.mail_outline,
                                    color: Color(0xFF64748B),
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 16,
                                      ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF3B82F6),
                                      width: 1.5,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFEF4444),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (value) =>
                                    (value == null || !value.contains('@'))
                                        ? 'Correo inválido'
                                        : null,
                              )
                              .animate(delay: 100.ms)
                              .fadeIn(duration: 300.ms)
                              .slideY(
                                begin: 0.15,
                                end: 0,
                                curve: Curves.easeOutCubic,
                              ),
                          const SizedBox(height: 16),

                          // Campo: Contraseña
                          TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Contraseña',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: Color(0xFF64748B),
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF64748B),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePassword =
                                          !_obscurePassword,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF3B82F6),
                                      width: 1.5,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFEF4444),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (value) =>
                                    (value == null || value.length < 6)
                                        ? 'Mínimo 6 caracteres'
                                        : null,
                              )
                              .animate(delay: 150.ms)
                              .fadeIn(duration: 300.ms)
                              .slideY(
                                begin: 0.15,
                                end: 0,
                                curve: Curves.easeOutCubic,
                              ),

                          // ¿Olvidaste tu contraseña?
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: auth.isBusy
                                  ? null
                                  : () => _forgotPassword(auth),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Botón "Iniciar sesión"
                          SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: auth.isBusy
                                      ? null
                                      : () => _submit(auth),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(
                                      0xFF0F172A,
                                    ).withValues(alpha: 0.6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: auth.isBusy
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Iniciar sesión',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              )
                              .animate(delay: 200.ms)
                              .fadeIn(duration: 300.ms)
                              .slideY(
                                begin: 0.15,
                                end: 0,
                                curve: Curves.easeOutCubic,
                              ),
                          const SizedBox(height: 16),

                          // "¿No tienes una cuenta? Regístrate"
                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterView(),
                                ),
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: const [
                                  Text(
                                    '¿No tienes una cuenta? ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    'Regístrate',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Divisor con "o"
                          const Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Color(0xFFE2E8F0),
                                  height: 1,
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  'o',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Color(0xFFE2E8F0),
                                  height: 1,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Botón "Continuar con Google"
                          SizedBox(
                            height: 54,
                            child: OutlinedButton(
                              onPressed: auth.isBusy
                                  ? null
                                  : () => _submitGoogle(auth),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GoogleLogo(size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Continuar con Google',
                                    style: TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Opción alternativa por teléfono
                          Center(
                            child: TextButton.icon(
                              onPressed: auth.isBusy
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const PhoneLoginView(),
                                      ),
                                    ),
                              icon: const Icon(
                                Icons.phone_outlined,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                              label: const Text(
                                'Continuar con teléfono',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
