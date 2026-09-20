import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'animated_background.dart';

class RoleTab {
  final String label;
  final IconData icon;
  final Widget page;

  const RoleTab({required this.label, required this.icon, required this.page});
}

/// Scaffold compartido por los 4 roles: cuerpo con IndexedStack + bottom nav
/// propio de cada rol (tabs distintos por rol, mismo comportamiento). La
/// barra inferior es una versión animada (píldora deslizante + iconos que
/// laten al seleccionarse) en vez del `BottomNavigationBar` plano original.
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
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBackground()),
          // Cada tab (y los streams de Firestore que abre) solo se construye
          // la primera vez que se visita, no las 4 de una vez al entrar —
          // evita listeners activos de más mientras el usuario nunca los abre.
          IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < widget.tabs.length; i++)
                if (_visited.contains(i))
                  widget.tabs[i].page
                else
                  const SizedBox.shrink(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _AnimatedBottomNav(
        tabs: widget.tabs,
        index: _index,
        onTap: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
      ),
    );
  }
}

class _AnimatedBottomNav extends StatelessWidget {
  final List<RoleTab> tabs;
  final int index;
  final ValueChanged<int> onTap;

  const _AnimatedBottomNav({
    required this.tabs,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / tabs.length;
              return SizedBox(
                height: 56,
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment(
                        tabs.length <= 1
                            ? 0
                            : (index / (tabs.length - 1)) * 2 - 1,
                        0,
                      ),
                      child: Container(
                        width: itemWidth - 12,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accent.withValues(alpha: 0.16),
                              AppColors.primary.withValues(alpha: 0.12),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: _NavItem(
                              tab: tabs[i],
                              selected: i == index,
                              onTap: () => onTap(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final RoleTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: selected ? 1 : 0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            builder: (context, t, child) =>
                Transform.scale(scale: 1 + (t * 0.15), child: child),
            child: Icon(tab.icon, color: color, size: 22),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
