import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../widgets/auth_gate.dart';
import '../widgets/brand_mark.dart';

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
    _timer = Timer(const Duration(milliseconds: 1600), () {
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo fotográfico de la barbería
          Image.asset(
            'lib/views/img/fondo.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          // Capa oscura degradada para alto contraste y elegancia
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Builder(
            builder: (context) {
              final reduceMotion = MediaQuery.of(context).disableAnimations;
              final brand = BrandMark(
                size: 86,
                color: Colors.white,
                spin: !reduceMotion,
              );
              final title = const Text(
                'BarberFlow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              );
              final subtitle = Text(
                'Tu barbería, siempre conectada',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.80),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              );
              final tagline = Text(
                'Gestiona   •   Organiza   •   Crece',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                ),
              );

              return SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: reduceMotion
                              ? [
                                  brand,
                                  const SizedBox(height: 18),
                                  title,
                                  const SizedBox(height: 8),
                                  subtitle,
                                ]
                              : [
                                  brand
                                      .animate()
                                      .scale(
                                        begin: const Offset(0.5, 0.5),
                                        curve: Curves.easeOutBack,
                                        duration: 800.ms,
                                      )
                                      .fadeIn(duration: 400.ms),
                                  const SizedBox(height: 18),
                                  title
                                      .animate(delay: 250.ms)
                                      .fadeIn(duration: 400.ms)
                                      .slideY(
                                        begin: 0.25,
                                        end: 0,
                                        curve: Curves.easeOutCubic,
                                      ),
                                  const SizedBox(height: 8),
                                  subtitle
                                      .animate(delay: 450.ms)
                                      .fadeIn(duration: 400.ms),
                                ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: reduceMotion
                          ? tagline
                          : tagline
                                .animate(delay: 600.ms)
                                .fadeIn(duration: 500.ms),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
