import 'package:flutter/material.dart';

class RoleTab {
  final String label;
  final IconData icon;
  final Widget page;

  const RoleTab({required this.label, required this.icon, required this.page});
}

/// Scaffold compartido por los 4 roles: cuerpo con IndexedStack + bottom nav
/// propio de cada rol (tabs distintos por rol, mismo comportamiento).
class RoleShell extends StatefulWidget {
  final List<RoleTab> tabs;

  const RoleShell({super.key, required this.tabs});

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;
  late final Set<int> _visited = {0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Cada tab (y los streams de Firestore que abre) solo se construye la
      // primera vez que se visita, no las 4 de una vez al entrar — evita
      // listeners activos de más mientras el usuario nunca los abre.
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < widget.tabs.length; i++)
            if (_visited.contains(i)) widget.tabs[i].page else const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        items: widget.tabs.map((tab) => BottomNavigationBarItem(icon: Icon(tab.icon), label: tab.label)).toList(),
      ),
    );
  }
}
