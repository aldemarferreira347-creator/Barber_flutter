import 'package:flutter/material.dart';

import '../../support_info.dart';
import '../../theme/app_colors.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Política de privacidad')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Section(
            title: 'Qué datos recogemos',
            body:
                'Nombre, correo electrónico y teléfono al registrarte; la ubicación de tu '
                'barbería si eres Dueño; fotos que subas a tu perfil, barbería, servicios '
                'o productos; y el historial de tus citas, calificaciones y compras dentro '
                'de la app.',
          ),
          _Section(
            title: 'Para qué los usamos',
            body:
                'Para operar las funciones de BarberFlow: gestionar citas, notificarte '
                'recordatorios y avisos, procesar pagos de servicios y mensualidades, y '
                'mostrar tu barbería en el catálogo cuando corresponda. No vendemos tus '
                'datos a terceros ni los usamos con fines publicitarios ajenos a la app.',
          ),
          const _Section(
            title: 'Con quién se comparten',
            body:
                'Usamos Firebase (Google Cloud) como infraestructura de autenticación, base '
                'de datos y almacenamiento de archivos; y una pasarela de pago para procesar '
                'transacciones. Estos proveedores procesan los datos únicamente para prestar '
                'el servicio a BarberFlow, bajo sus propias políticas de seguridad.',
          ),
          const _Section(
            title: 'Tus derechos',
            body:
                'Puedes pedir acceso, corrección o eliminación de tus datos personales '
                'escribiendo a soporte (ver abajo). Eliminar tu cuenta borra tu perfil y '
                'deja de mostrar tu información en el catálogo; el historial de citas '
                'asociado a una barbería puede conservarse por motivos contables.',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.mail_outline, color: AppColors.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('Dudas sobre tus datos: ${SupportInfo.supportEmail}')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}
