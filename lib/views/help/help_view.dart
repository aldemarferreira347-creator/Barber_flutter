import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../support_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/app_card.dart';
import '../widgets/brand_mark.dart';
import '../widgets/responsive_body.dart';
import '../widgets/section_header.dart';
import 'privacy_policy_view.dart';

class HelpView extends StatelessWidget {
  const HelpView({super.key});

  static const _faq = [
    (
      q: '¿Cómo agendo una cita?',
      a:
          'Entra a la barbería que te interese desde "Barberías", elige '
          '"Agendar cita" y escoge servicio, barbero, día y hora. Solo ves '
          'las horas libres dentro del horario de la barbería.',
    ),
    (
      q: '¿Cómo pago con Nequi?',
      a:
          'Al agendar elige "Pagar con Nequi": la app te muestra el número '
          'de la barbería y el valor exacto. Haz el envío desde tu Nequi y '
          'escribe aquí la referencia del comprobante. La barbería confirma '
          'que recibió el dinero y tu cita queda pagada; mientras tanto el '
          'horario ya es tuyo. Si el pago se rechaza, lo verás en tu cita.',
    ),
    (
      q: '¿Cómo cancelo o pospongo una cita pagada?',
      a:
          'Desde "Citas", abre la cita y toca cancelar. Si ya la pagaste, la '
          'app te ofrece posponerla primero; si insistes en cancelar, te '
          'pedirá una justificación para gestionar el reembolso.',
    ),
    (
      q: '¿Cómo compro un producto?',
      a:
          'Entra a la barbería, elige el producto y paga por Nequi con el '
          'mismo procedimiento. Cuando la barbería confirme el pago verás un '
          'código en "Mis compras": muéstralo en la barbería para recibir '
          'tu producto.',
    ),
    (
      q: '¿Recibiré recordatorios de mis citas?',
      a:
          'Sí, en la app del teléfono: un aviso 1 hora y otro 15 minutos '
          'antes de cada cita aceptada. Acepta el permiso de notificaciones '
          'cuando la app lo pida.',
    ),
    (
      q: '¿Cómo registro mi barbería y me vuelvo Dueño?',
      a:
          'Desde tu perfil de Cliente, toca "Registrar mi barbería". Pagas '
          'la primera mensualidad por Nequi al administrador y tu solicitud '
          'queda en revisión; cuando la apruebe podrás gestionarla por '
          'completo.',
    ),
    (
      q: '¿Qué pasa si la mensualidad de mi barbería vence?',
      a:
          'Tienes unos días de gracia; si no pagas en ese plazo, la barbería '
          'deja de verse en el catálogo y no recibe citas ni compras hasta '
          'que regularices el pago.',
    ),
    (
      q: '¿Cómo cambio el tono de mis notificaciones o el modo oscuro?',
      a:
          'Ambas opciones están en tu perfil (pestaña "Perfil" o "Más"), '
          'justo debajo de tus datos de cuenta.',
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
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          children: [
            ResponsiveBody(
              maxWidth: AppLayout.formWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(title: 'Preguntas frecuentes'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: Column(
                        children: [
                          for (final (index, item) in _faq.indexed) ...[
                            if (index > 0)
                              Divider(height: 1, color: AppColors.border),
                            ExpansionTile(
                              title: Text(item.q, style: text.titleSmall),
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.lg,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                AppSpace.lg,
                                0,
                                AppSpace.lg,
                                AppSpace.lg,
                              ),
                              expandedAlignment: Alignment.topLeft,
                              children: [
                                Text(
                                  item.a,
                                  style: text.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  const SectionHeader(title: 'Contáctanos'),
                  ActionListTile(
                    icon: Icons.mail_outline,
                    label: SupportInfo.supportEmail,
                    onTap: () => _launch(
                      context,
                      Uri(scheme: 'mailto', path: SupportInfo.supportEmail),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  ActionListTile(
                    icon: Icons.phone_outlined,
                    label: SupportInfo.supportPhone,
                    onTap: () => _launch(
                      context,
                      Uri(scheme: 'tel', path: SupportInfo.supportPhone),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  ActionListTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Política de privacidad',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyView(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxl),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandMark(size: 32, spin: false),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          'BarberFlow • Tu barbería, siempre conectada',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
