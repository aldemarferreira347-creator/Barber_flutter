import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/responsive_body.dart';

class RegisterSuccessView extends StatelessWidget {
  const RegisterSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ResponsiveBody(
            maxWidth: AppLayout.formWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpace.xl),
                    decoration: BoxDecoration(
                      color: AppColors.tint(AppColors.success),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: AppColors.readable(AppColors.success),
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                Semantics(
                  header: true,
                  child: Text(
                    '¡Registro exitoso!',
                    textAlign: TextAlign.center,
                    style: text.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Tu cuenta ha sido creada correctamente.\nAhora puedes iniciar sesión.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppSpace.xxl),
                AppButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Ir a iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
