import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../widgets/brand_mark.dart';

class RegisterSuccessView extends StatelessWidget {
  const RegisterSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.check, color: AppColors.success, size: 48),
              ),
              const SizedBox(height: 20),
              const Text('¡Registro exitoso!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Tu cuenta ha sido creada correctamente.\nAhora puedes iniciar sesión.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Ir a iniciar sesión'),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const BrandMark(size: 26),
              ),
              const SizedBox(height: 8),
              const Text('BarberFlow', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
