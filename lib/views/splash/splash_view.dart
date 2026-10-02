import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../widgets/auth_gate.dart';
import '../widgets/brand_mark.dart';

/// Pantalla de arranque: marca sobre la foto de la barbería, siempre
/// oscura (no depende del tema) como en el mockup. Pasa sola al
/// [AuthGate], que ya muestra su propio estado de carga mientras resuelve
/// la sesión.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const onPhoto = AppColors.onColor;
    return Scaffold(
      backgroundColor: AppColors.alwaysDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo fotográfico de la barbería, oscurecido para el contraste.
          ExcludeSemantics(
            child: Image.asset('lib/views/img/fondo.png', fit: BoxFit.cover),
          ),
          const DecoratedBox(decoration: BoxDecoration(color: AppColors.scrim)),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandMark(size: 86, spin: false),
                        const SizedBox(height: 18),
                        Text(
                          'BarberFlow',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: onPhoto, fontSize: 32),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tu barbería, siempre conectada',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: onPhoto.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Text(
                    'Gestiona   •   Organiza   •   Crece',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: onPhoto.withValues(alpha: 0.7),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
