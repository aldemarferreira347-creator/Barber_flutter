import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/error_state.dart';
import '../widgets/scroll_to_top_fab.dart';
import '../widgets/shimmer_box.dart';

class ManageUsersView extends StatefulWidget {
  const ManageUsersView({super.key});

  @override
  State<ManageUsersView> createState() => _ManageUsersViewState();
}

class _ManageUsersViewState extends State<ManageUsersView> {
  final _scrollController = ScrollController();
  String _query = '';
  UserRole? _roleFilter;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _roleLabel(UserRole role) => switch (role) {
    UserRole.admin => 'Admin',
    UserRole.owner => 'Dueño',
    UserRole.barber => 'Barbero',
    UserRole.client => 'Cliente',
  };

  Color _roleColor(UserRole role) => switch (role) {
    UserRole.admin => const Color(0xFF7C3AED),
    UserRole.owner => const Color(0xFFD97706),
    UserRole.barber => const Color(0xFF0891B2),
    UserRole.client => AppColors.accent,
  };

  // ─── Modal de acciones ──────────────────────────────────────────────────────

  void _showActions(BuildContext context, AppUser user) {
    final userRepo = context.read<UserRepository>();
    final notifRepo = context.read<NotificationRepository>();
    final currentUid = context.read<AuthController>().profile?.uid;
    final isSelf = user.uid == currentUid;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _UserActionsSheet(
        user: user,
        isSelf: isSelf,
        roleLabel: _roleLabel,
        roleColor: _roleColor,
        onNotify: () => _notify(context, user, notifRepo),
        onEdit: () => _editUser(context, user, userRepo),
        onToggleActive: () =>
            userRepo.setActive(user.uid, !user.active).catchError((_) {}),
        onDelete: () => _deleteUser(context, user, userRepo),
      ),
    );
  }

  // ─── Enviar notificación ─────────────────────────────────────────────────

  Future<void> _notify(
    BuildContext context,
    AppUser user,
    NotificationRepository notifRepo,
  ) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Notificar a ${user.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mensaje'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (send != true || !context.mounted) return;
    if (titleController.text.trim().isEmpty) return;
    try {
      await notifRepo.send(
        toUserId: user.uid,
        title: titleController.text.trim(),
        body: bodyController.text.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notificación enviada a ${user.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo enviar: $e')));
      }
    }
  }

  // ─── Editar usuario ───────────────────────────────────────────────────────

  Future<void> _editUser(
    BuildContext context,
    AppUser user,
    UserRepository userRepo,
  ) async {
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    UserRole selectedRole = user.role;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Editar usuario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Correo
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: const Icon(Icons.mail_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Nota informativa
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Actualiza el correo en el perfil. El correo de inicio de sesión se gestiona desde Firebase Auth.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.warning,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Rol
                Text(
                  'Rol',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: UserRole.values.map((role) {
                    final isSel = selectedRole == role;
                    return ChoiceChip(
                      label: Text(_roleLabel(role)),
                      selected: isSel,
                      onSelected: (_) => setState(() => selectedRole = role),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: isSel ? AppColors.primary : AppColors.border,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      final newName = nameCtrl.text.trim();
      final newEmail = emailCtrl.text.trim().toLowerCase();
      if (newName.isNotEmpty && newName != user.name) {
        await userRepo.updateName(user.uid, newName);
      }
      if (newEmail.isNotEmpty && newEmail != user.email) {
        await userRepo.updateEmail(user.uid, newEmail);
      }
      if (selectedRole != user.role) {
        await userRepo.setRole(user.uid, selectedRole);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario actualizado')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }


  // ─── Eliminar usuario ─────────────────────────────────────────────────────

  Future<void> _deleteUser(
    BuildContext context,
    AppUser user,
    UserRepository userRepo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: RichText(
          text: TextSpan(
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            children: [
              const TextSpan(text: '¿Estás seguro de que deseas eliminar a '),
              TextSpan(
                text: user.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(
                text:
                    '? Esta acción no se puede deshacer.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await userRepo.deleteUser(user.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario "${user.name}" eliminado'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  // ─── Añadir usuario ───────────────────────────────────────────────────────

  Future<void> _addUser(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    UserRole selectedRole = UserRole.client;
    bool obscurePass = true;
    bool obscureConfirm = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            String roleLabel(UserRole role) => switch (role) {
              UserRole.admin => 'Admin',
              UserRole.owner => 'Dueño',
              UserRole.barber => 'Barbero',
              UserRole.client => 'Cliente',
            };

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cabecera
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.person_add_outlined,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Añadir usuario',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'El usuario podrá iniciar sesión con estas credenciales.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: const Icon(Icons.mail_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || !v.contains('@'))
                                ? 'Correo inválido'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: obscurePass,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () =>
                                setSheetState(() => obscurePass = !obscurePass),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.length < 6)
                                ? 'Mínimo 6 caracteres'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: confirmCtrl,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setSheetState(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) =>
                            v != passCtrl.text
                                ? 'Las contraseñas no coinciden'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rol',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: UserRole.values.map((role) {
                              final isSelected = selectedRole == role;
                              return ChoiceChip(
                                label: Text(roleLabel(role)),
                                selected: isSelected,
                                onSelected: (_) =>
                                    setSheetState(() => selectedRole = role),
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                backgroundColor: AppColors.surface,
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final auth = context.read<AuthController>();
                          final ok = await auth.adminRegisterUser(
                            email: emailCtrl.text,
                            password: passCtrl.text,
                            name: nameCtrl.text,
                            role: selectedRole,
                          );
                          if (!sheetCtx.mounted) return;
                          Navigator.of(sheetCtx).pop();
                          if (!context.mounted) return;
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Usuario "${nameCtrl.text.trim()}" creado',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  auth.errorMessage ??
                                      'No se pudo crear el usuario',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text(
                          'Registrar usuario',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userService = context.read<UserRepository>();
    final currentUid = context.read<AuthController>().profile?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_user_fab',
            onPressed: () => _addUser(context),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text(
              'Añadir usuario',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          ScrollToTopFab(controller: _scrollController),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar usuarios...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _RoleChip(
                    label: 'Todos',
                    selected: _roleFilter == null,
                    onTap: () => setState(() => _roleFilter = null),
                  ),
                  for (final role in UserRole.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _RoleChip(
                        label: _roleLabel(role),
                        selected: _roleFilter == role,
                        onTap: () => setState(() => _roleFilter = role),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<AppUser>>(
                stream: userService.watchAll(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: ErrorState(
                        title: 'No pudimos cargar los usuarios',
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ShimmerList();
                  }
                  var users = snapshot.data ?? [];
                  if (_roleFilter != null) {
                    users = users.where((u) => u.role == _roleFilter).toList();
                  }
                  if (_query.isNotEmpty) {
                    users = users
                        .where(
                          (u) =>
                              u.name.toLowerCase().contains(_query) ||
                              u.email.toLowerCase().contains(_query),
                        )
                        .toList();
                  }
                  if (users.isEmpty) {
                    return Center(
                      child: Text(
                        'No se encontraron usuarios',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: _scrollController,
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isSelf = user.uid == currentUid;
                      return _UserCard(
                        user: user,
                        isSelf: isSelf,
                        roleLabel: _roleLabel(user.role),
                        roleColor: _roleColor(user.role),
                        onActionsTap: isSelf
                            ? null
                            : () => _showActions(context, user),
                      )
                          .animate(delay: (index * 50).ms)
                          .fadeIn(duration: 280.ms)
                          .slideX(
                            begin: 0.06,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tarjeta de usuario ──────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final AppUser user;
  final bool isSelf;
  final String roleLabel;
  final Color roleColor;
  final VoidCallback? onActionsTap;

  const _UserCard({
    required this.user,
    required this.isSelf,
    required this.roleLabel,
    required this.roleColor,
    this.onActionsTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = user.name.isNotEmpty
        ? user.name
              .trim()
              .split(RegExp(r'\s+'))
              .map((p) => p[0])
              .take(2)
              .join()
              .toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar con indicador de estado
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: roleColor.withValues(alpha: 0.15),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: user.active
                        ? AppColors.success
                        : AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Info principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name.isNotEmpty ? user.name : '(sin nombre)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Tú',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Badge de rol
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      color: roleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Botón de acciones o indicador "eres tú"
          if (!isSelf)
            _ActionMenuButton(onTap: onActionsTap)
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ─── Botón de acciones ───────────────────────────────────────────────────────

class _ActionMenuButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _ActionMenuButton({this.onTap});

  @override
  State<_ActionMenuButton> createState() => _ActionMenuButtonState();
}

class _ActionMenuButtonState extends State<_ActionMenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.more_vert_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ─── Modal de acciones del usuario ──────────────────────────────────────────

class _UserActionsSheet extends StatelessWidget {
  final AppUser user;
  final bool isSelf;
  final String Function(UserRole) roleLabel;
  final Color Function(UserRole) roleColor;
  final VoidCallback onNotify;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _UserActionsSheet({
    required this.user,
    required this.isSelf,
    required this.roleLabel,
    required this.roleColor,
    required this.onNotify,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final rColor = roleColor(user.role);
    final initials = user.name.isNotEmpty
        ? user.name
              .trim()
              .split(RegExp(r'\s+'))
              .map((p) => p[0])
              .take(2)
              .join()
              .toUpperCase()
        : '?';

    final actions = <_SheetAction>[
      _SheetAction(
        icon: Icons.edit_outlined,
        label: 'Editar usuario',
        subtitle: 'Cambiar nombre o rol',
        color: AppColors.accent,
        onTap: () {
          Navigator.of(context).pop();
          onEdit();
        },
      ),
      _SheetAction(
        icon: user.active
            ? Icons.block_rounded
            : Icons.check_circle_outline_rounded,
        label: user.active ? 'Desactivar cuenta' : 'Activar cuenta',
        subtitle: user.active
            ? 'El usuario no podrá iniciar sesión'
            : 'Restaurar el acceso del usuario',
        color: user.active ? AppColors.warning : AppColors.success,
        onTap: () {
          Navigator.of(context).pop();
          onToggleActive();
        },
      ),
      _SheetAction(
        icon: Icons.notifications_outlined,
        label: 'Enviar notificación',
        subtitle: 'Mensaje push al dispositivo',
        color: const Color(0xFF7C3AED),
        onTap: () {
          Navigator.of(context).pop();
          onNotify();
        },
      ),
      _SheetAction(
        icon: Icons.delete_outline_rounded,
        label: 'Eliminar usuario',
        subtitle: 'Borrar perfil permanentemente',
        color: AppColors.error,
        onTap: () {
          Navigator.of(context).pop();
          onDelete();
        },
        isDestructive: true,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          )
              .animate()
              .fadeIn(duration: 200.ms),
          const SizedBox(height: 20),

          // Perfil del usuario
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: rColor.withValues(alpha: 0.15),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: rColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.6, 0.6),
                    duration: 300.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isNotEmpty ? user.name : '(sin nombre)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: rColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            roleLabel(user.role),
                            style: TextStyle(
                              color: rColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: (user.active
                                    ? AppColors.success
                                    : AppColors.error)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user.active ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                              color: user.active
                                  ? AppColors.success
                                  : AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 80.ms, duration: 250.ms)
                  .slideX(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
            ],
          ),

          const SizedBox(height: 20),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),

          // Lista de acciones con animación escalonada
          ...actions.asMap().entries.map((entry) {
            final i = entry.key;
            final action = entry.value;
            return _SheetActionTile(action: action)
                .animate(delay: (100 + i * 60).ms)
                .fadeIn(duration: 220.ms)
                .slideY(
                  begin: 0.12,
                  end: 0,
                  curve: Curves.easeOutCubic,
                );
          }),
        ],
      ),
    );
  }
}

// ─── Datos y tile de acción ───────────────────────────────────────────────────

class _SheetAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
  });
}

class _SheetActionTile extends StatefulWidget {
  final _SheetAction action;
  const _SheetActionTile({required this.action});

  @override
  State<_SheetActionTile> createState() => _SheetActionTileState();
}

class _SheetActionTileState extends State<_SheetActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        a.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _pressed
              ? a.color.withValues(alpha: 0.1)
              : a.color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _pressed
                ? a.color.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: a.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(a.icon, color: a.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: a.isDestructive ? a.color : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    a.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chip de filtro por rol ──────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: AppColors.border),
    );
  }
}
