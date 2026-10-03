import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/status_badge.dart';

/// Nombre del rol tal como se muestra en la app.
String roleLabel(UserRole role) => switch (role) {
  UserRole.admin => 'Admin',
  UserRole.owner => 'Dueño',
  UserRole.barber => 'Barbero',
  UserRole.client => 'Cliente',
};

Color roleColor(UserRole role) => switch (role) {
  UserRole.admin => AppColors.roleAdmin,
  UserRole.owner => AppColors.roleOwner,
  UserRole.barber => AppColors.roleBarber,
  UserRole.client => AppColors.accent,
};

/// Avatar con las iniciales, teñido con el color del rol.
class UserAvatar extends StatelessWidget {
  final AppUser user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final color = roleColor(user.role);
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.tint(color),
        child: Text(
          user.initials,
          style: TextStyle(
            color: AppColors.readable(color),
            fontSize: radius * 0.65,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Rol y estado de la cuenta, uno junto al otro.
class UserBadges extends StatelessWidget {
  final AppUser user;

  const UserBadges({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.xs,
      children: [
        StatusBadge(label: roleLabel(user.role), color: roleColor(user.role)),
        StatusBadge(
          label: user.active ? 'Activo' : 'Inactivo',
          color: user.active ? AppColors.success : AppColors.error,
        ),
      ],
    );
  }
}
