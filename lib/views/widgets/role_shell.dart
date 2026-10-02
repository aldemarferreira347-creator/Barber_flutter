import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

class RoleTab {
  final String label;
  final IconData icon;
  final Widget page;

  const RoleTab({required this.label, required this.icon, required this.page});
}

/// Scaffold compartido por los 4 roles: cuerpo con `IndexedStack` y
/// navegación propia de cada rol (tabs distintos por rol, mismo
/// comportamiento).
///
/// La navegación se adapta al ancho: barra inferior en teléfono
/// ([ScreenSize.compact]), riel lateral compacto en tablet y riel extendido
/// con etiquetas en escritorio. Es la navegación nativa de Material, así que
/// conserva semántica de lectores de pantalla, teclado y foco.
class RoleShell extends StatefulWidget {
  final List<RoleTab> tabs;

  const RoleShell({super.key, required this.tabs});

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;
  late final Set<int> _visited = {0};

  void _select(int i) => setState(() {
    _index = i;
    _visited.add(i);
  });

  @override
  Widget build(BuildContext context) {
    // Cada tab (y los streams de Firestore que abre) solo se construye la
    // primera vez que se visita, no todas de una vez al entrar — evita
    // listeners activos de más mientras el usuario nunca los abre.
    final body = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < widget.tabs.length; i++)
          if (_visited.contains(i))
            widget.tabs[i].page
          else
            const SizedBox.shrink(),
      ],
    );

    final size = context.screenSize;
    if (size == ScreenSize.compact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            for (final tab in widget.tabs)
              NavigationDestination(icon: Icon(tab.icon), label: tab.label),
          ],
        ),
      );
    }

    final extended = size == ScreenSize.expanded;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: _select,
            extended: extended,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              for (final tab in widget.tabs)
                NavigationRailDestination(
                  icon: Icon(tab.icon),
                  label: Text(tab.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
