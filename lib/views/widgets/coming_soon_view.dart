import 'package:flutter/material.dart';

import 'empty_state.dart';

/// Pantalla placeholder para tabs cuya funcionalidad todavía no existe
/// (citas, servicios, disponibilidad) — fases futuras del roadmap.
class ComingSoonView extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const ComingSoonView({super.key, required this.title, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: EmptyState(icon: icon, title: title, subtitle: message),
      ),
    );
  }
}
