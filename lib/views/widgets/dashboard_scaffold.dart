import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import 'pressable_scale.dart';

/// Estructura compartida por los 4 dashboards de rol (Admin/Dueño/Barbero/
/// Cliente), siguiendo el mockup de referencia: banda oscura con saludo +
/// campana de notificaciones, y una "hoja" clara con esquinas redondeadas
/// que se monta encima, conteniendo el resto del contenido en un
/// `ListView`.
class DashboardScaffold extends StatelessWidget {
  final String greeting;
  final String subtitle;
  final Widget? avatar;
  final VoidCallback? onNotifications;
  final List<Widget> children;
  final Widget? floatingActionButton;

  const DashboardScaffold({
    super.key,
    required this.greeting,
    required this.subtitle,
    this.avatar,
    this.onNotifications,
    required this.children,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, const Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Row(
                      children: [
                        if (avatar != null) ...[
                          avatar!,
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onNotifications != null)
                          PressableScale(
                            onTap: onNotifications,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_none,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 320.ms)
                  .slideY(begin: -0.15, end: 0, curve: Curves.easeOutCubic),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
