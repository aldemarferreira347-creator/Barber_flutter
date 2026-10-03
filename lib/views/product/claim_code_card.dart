import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../widgets/app_card.dart';

/// Código de reclamo de una compra, grande y copiable, con el tiempo que
/// queda para reclamarla. Es lo que el cliente muestra en el mostrador.
class ClaimCodeCard extends StatefulWidget {
  final String code;
  final DateTime? expiresAt;

  const ClaimCodeCard({super.key, required this.code, this.expiresAt});

  @override
  State<ClaimCodeCard> createState() => _ClaimCodeCardState();
}

class _ClaimCodeCardState extends State<ClaimCodeCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final expiresAt = widget.expiresAt;
    return AppCard(
      color: AppColors.surfaceRaised,
      child: Column(
        children: [
          Text('Tu código de reclamo', style: text.bodySmall),
          const SizedBox(height: AppSpace.xs),
          Semantics(
            label: 'Código de reclamo ${widget.code.split('').join(' ')}',
            excludeSemantics: true,
            child: Text(
              widget.code,
              style: text.headlineMedium?.copyWith(letterSpacing: 4),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          if (expiresAt != null)
            Text(
              'Vence en ${remainingLabel(expiresAt)}',
              style: text.secondary,
            ),
          const SizedBox(height: AppSpace.sm),
          TextButton.icon(
            onPressed: _copy,
            icon: Icon(_copied ? Icons.check : Icons.copy_outlined, size: 18),
            label: Text(_copied ? 'Copiado' : 'Copiar código'),
          ),
        ],
      ),
    );
  }
}
