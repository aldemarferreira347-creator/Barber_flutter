import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import '../widgets/auth_gate.dart';
import '../widgets/brand_mark.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('lib/views/img/fondo.png', fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.55),
                  const Color(0xFF1E293B).withValues(alpha: 0.75),
                  const Color(0xFF0B1220).withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandMark(size: 68, color: Colors.white)
                            .animate()
                            .scale(
                              begin: const Offset(0.4, 0.4),
                              curve: Curves.elasticOut,
                              duration: 900.ms,
                            )
                            .fadeIn(duration: 400.ms),
                        const SizedBox(height: 18),
                        const Text(
                              'BarberFlow',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                            .animate(delay: 350.ms)
                            .fadeIn(duration: 500.ms)
                            .slideY(
                              begin: 0.3,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            ),
                        const SizedBox(height: 6),
                        Text(
                          'Tu barbería, siempre conectada',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ).animate(delay: 550.ms).fadeIn(duration: 500.ms),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Text(
                    'Gestiona  ·  Organiza  ·  Crece',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ).animate(delay: 800.ms).fadeIn(duration: 600.ms),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
