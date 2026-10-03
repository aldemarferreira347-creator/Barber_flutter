import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/responsive_body.dart';
import '../widgets/scroll_to_top_fab.dart';
import '../widgets/shimmer_box.dart';
import 'user_forms.dart';
import 'user_style.dart';
import '../../utils/error_text.dart';

/// Acciones que el admin puede hacer sobre otro usuario.
enum _UserAction { edit, toggleActive, notify, delete }

/// Gestión de usuarios (admin): buscar, filtrar por rol y, desde la hoja de
/// acciones de cada uno, editar, activar/desactivar, avisar o eliminar.
class ManageUsersView extends StatefulWidget {
  const ManageUsersView({super.key});

  @override
  State<ManageUsersView> createState() => _ManageUsersViewState();
}

class _ManageUsersViewState extends State<ManageUsersView> {
  final _scrollController = ScrollController();
  late final Stream<List<AppUser>> _users = context
      .read<UserRepository>()
      .watchAll();
  String _query = '';
  UserRole? _roleFilter;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showActions(AppUser user) async {
    final action = await AppBottomSheet.show<_UserAction>(
      context,
      title: user.name.isEmpty ? '(sin nombre)' : user.name,
      child: _UserActions(user: user),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _UserAction.edit:
        await _edit(user);
      case _UserAction.toggleActive:
        await _toggleActive(user);
      case _UserAction.notify:
        await _notify(user);
      case _UserAction.delete:
        await _delete(user);
    }
  }

  Future<void> _edit(AppUser user) async {
    final saved = await AppBottomSheet.show<bool>(
      context,
      title: 'Editar usuario',
      child: EditUserForm(user: user),
    );
    if (saved == true && mounted) _snack('Usuario actualizado');
  }

  Future<void> _toggleActive(AppUser user) async {
    final repo = context.read<UserRepository>();
    final deactivating = user.active;
    if (deactivating) {
      final ok = await AppDialog.confirm(
        context,
        title: 'Desactivar cuenta',
        message:
            '${user.name} no podrá usar la app hasta que vuelvas a '
            'activarla.',
        confirmLabel: 'Desactivar',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    try {
      await repo.setActive(user.uid, !deactivating);
      if (mounted) {
        _snack(deactivating ? 'Cuenta desactivada' : 'Cuenta activada');
      }
    } catch (e) {
      if (mounted) _snack('No se pudo cambiar el estado: ${errorText(e)}');
    }
  }

  Future<void> _notify(AppUser user) async {
    final sent = await AppBottomSheet.show<bool>(
      context,
      title: 'Notificar a ${user.name}',
      child: NotifyUserForm(user: user),
    );
    if (sent == true && mounted) _snack('Notificación enviada a ${user.name}');
  }

  Future<void> _delete(AppUser user) async {
    final repo = context.read<UserRepository>();
    final ok = await AppDialog.confirm(
      context,
      title: 'Eliminar perfil',
      message:
          'Se borra el perfil de ${user.name} y sus datos en la app. No se '
          'puede deshacer. Para impedir el acceso sin borrar nada, usa '
          '"Desactivar cuenta".',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await repo.deleteUser(user.uid);
      if (mounted) _snack('Perfil de ${user.name} eliminado');
    } catch (e) {
      if (mounted) _snack('No se pudo eliminar: ${errorText(e)}');
    }
  }

  Future<void> _add() async {
    final created = await AppBottomSheet.show<bool>(
      context,
      title: 'Añadir usuario',
      child: const AddUserForm(),
    );
    if (created == true && mounted) _snack('Usuario creado');
  }

  List<AppUser> _filter(List<AppUser> users) => [
    for (final u in users)
      if ((_roleFilter == null || u.role == _roleFilter) &&
          (_query.isEmpty ||
              u.name.toLowerCase().contains(_query) ||
              u.email.toLowerCase().contains(_query)))
        u,
  ];

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<AuthController>().profile?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_user_fab',
            onPressed: _add,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Añadir usuario'),
          ),
          const SizedBox(height: AppSpace.md),
          ScrollToTopFab(controller: _scrollController),
        ],
      ),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpace.lg),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o correo',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _roleFilter == null,
                    onSelected: (_) => setState(() => _roleFilter = null),
                  ),
                  for (final role in UserRole.values) ...[
                    const SizedBox(width: AppSpace.sm),
                    ChoiceChip(
                      label: Text(roleLabel(role)),
                      selected: _roleFilter == role,
                      onSelected: (_) => setState(() => _roleFilter = role),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Expanded(
              child: StreamBuilder<List<AppUser>>(
                stream: _users,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: ErrorState(
                        title: 'No pudimos cargar los usuarios',
                      ),
                    );
                  }
                  if (!snapshot.hasData) return const ShimmerList();
                  final users = _filter(snapshot.data!);
                  if (users.isEmpty) {
                    return const Center(
                      child: EmptyState(
                        icon: Icons.search_off,
                        title: 'No se encontraron usuarios',
                        subtitle: 'Prueba con otro nombre, correo o rol.',
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 140),
                    itemCount: users.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpace.md),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isSelf = user.uid == currentUid;
                      return _UserTile(
                        user: user,
                        isSelf: isSelf,
                        onTap: isSelf ? null : () => _showActions(user),
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

class _UserTile extends StatelessWidget {
  final AppUser user;
  final bool isSelf;
  final VoidCallback? onTap;

  const _UserTile({required this.user, required this.isSelf, this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      semanticLabel: 'Acciones para ${user.name}',
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          UserAvatar(user: user),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name.isNotEmpty ? user.name : '(sin nombre)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: AppSpace.sm),
                      Text(
                        '(tú)',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                UserBadges(user: user),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.more_vert, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

/// Contenido de la hoja de acciones: devuelve la acción elegida.
class _UserActions extends StatelessWidget {
  final AppUser user;

  const _UserActions({required this.user});

  @override
  Widget build(BuildContext context) {
    void pick(_UserAction action) => Navigator.of(context).pop(action);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          user.email,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.sm),
        UserBadges(user: user),
        const SizedBox(height: AppSpace.lg),
        ActionListTile(
          icon: Icons.edit_outlined,
          label: 'Editar usuario',
          subtitle: 'Nombre, correo o rol',
          onTap: () => pick(_UserAction.edit),
        ),
        const SizedBox(height: AppSpace.sm),
        ActionListTile(
          icon: user.active ? Icons.block : Icons.check_circle_outline,
          iconColor: user.active ? AppColors.warning : AppColors.success,
          label: user.active ? 'Desactivar cuenta' : 'Activar cuenta',
          subtitle: user.active
              ? 'No podrá usar la app'
              : 'Restaurar el acceso',
          onTap: () => pick(_UserAction.toggleActive),
        ),
        const SizedBox(height: AppSpace.sm),
        ActionListTile(
          icon: Icons.notifications_outlined,
          iconColor: AppColors.roleAdmin,
          label: 'Enviar notificación',
          subtitle: 'Aviso en su bandeja de la app',
          onTap: () => pick(_UserAction.notify),
        ),
        const SizedBox(height: AppSpace.sm),
        ActionListTile(
          icon: Icons.delete_outline,
          iconColor: AppColors.error,
          label: 'Eliminar perfil',
          subtitle: 'Borra sus datos en la app',
          onTap: () => pick(_UserAction.delete),
        ),
      ],
    );
  }
}
