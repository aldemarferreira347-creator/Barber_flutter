import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../support_info.dart';
import '../../theme/app_colors.dart';
import '../widgets/action_list_tile.dart';
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
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideX(begin: -0.05, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
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
              )
              .animate(delay: 100.ms)
              .fadeIn(duration: 300.ms)
              .slideX(begin: -0.05, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 8),
          ActionListTile(
            icon: Icons.mail_outline,
            label: SupportInfo.supportEmail,
            animationIndex: 0,
            onTap: () => _launch(
              context,
              Uri(scheme: 'mailto', path: SupportInfo.supportEmail),
            ),
          ),
          const SizedBox(height: 10),
          ActionListTile(
            icon: Icons.phone_outlined,
            label: SupportInfo.supportPhone,
            animationIndex: 1,
            onTap: () => _launch(
              context,
              Uri(scheme: 'tel', path: SupportInfo.supportPhone),
            ),
          ),
          const SizedBox(height: 10),
          ActionListTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Política de privacidad',
            animationIndex: 2,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyView()),
            ),
          ),
        ],
      ),
    );
  }
}
