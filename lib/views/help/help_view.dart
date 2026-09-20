import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../support_info.dart';
import '../../theme/app_colors.dart';
import 'privacy_policy_view.dart';

class HelpView extends StatelessWidget {
  const HelpView({super.key});

  static const _faq = [
    (
      q: '¿Cómo agendo una cita?',
      a:
          'Entra a la barbería que te interese desde "Barberías", elige "Agendar cita" y '
          'sigue los pasos para escoger servicio, barbero y horario.',
    ),
    (
      q: '¿Cómo cancelo o pospongo una cita pagada?',
      a:
          'Desde "Citas", abre la cita y toca cancelar. Si ya la pagaste, la app te ofrece '
          'posponerla primero; si insistes en cancelar, te pedirá una justificación para '
          'gestionar el reembolso.',
    ),
    (
      q: '¿Cómo registro mi barbería y me vuelvo Dueño?',
      a:
          'Desde tu perfil de Cliente, toca "Registrar mi barbería". Tu solicitud queda '
          'pendiente de revisión; cuando el administrador la apruebe podrás pagar la '
          'mensualidad y gestionarla por completo.',
    ),
    (
      q: '¿Qué pasa si la mensualidad de mi barbería vence?',
      a:
          'Tienes un período de gracia de unos días; si no pagas en ese plazo, la barbería '
          'se bloquea y deja de verse en el catálogo hasta que regularices el pago.',
    ),
    (
      q: '¿Cómo cambio el tono de mis notificaciones o el modo oscuro?',
      a:
          'Ambas opciones están en tu perfil (pestaña "Perfil" o "Más"), justo debajo de tus '
          'datos de cuenta.',
    ),
  ];

  Future<void> _launch(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No se pudo abrir')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Preguntas frecuentes',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: AppColors.border),
              child: Column(
                children: [
                  for (final (index, item) in _faq.indexed) ...[
                    if (index > 0) Divider(height: 1, color: AppColors.border),
                    ExpansionTile(
                      title: Text(
                        item.q,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedAlignment: Alignment.topLeft,
                      children: [
                        Text(
                          item.a,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Contáctanos',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _launch(
                context,
                Uri(scheme: 'mailto', path: SupportInfo.supportEmail),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mail_outline, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(child: Text(SupportInfo.supportEmail)),
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _launch(
                context,
                Uri(scheme: 'tel', path: SupportInfo.supportPhone),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone_outlined, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(child: Text(SupportInfo.supportPhone)),
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyView()),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, color: AppColors.accent),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Política de privacidad')),
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
