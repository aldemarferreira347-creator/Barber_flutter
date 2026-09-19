import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/status_badge.dart';

class ManageUsersView extends StatefulWidget {
  const ManageUsersView({super.key});

  @override
  State<ManageUsersView> createState() => _ManageUsersViewState();
}

class _ManageUsersViewState extends State<ManageUsersView> {
  String _query = '';
  UserRole? _roleFilter;

  String _roleLabel(UserRole role) => switch (role) {
    UserRole.admin => 'Admin',
    UserRole.owner => 'Dueño',
    UserRole.barber => 'Barbero',
    UserRole.client => 'Cliente',
  };

  Future<void> _notify(BuildContext context, AppUser user) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Enviar')),
        ],
      ),
    );
    if (send != true || !context.mounted) return;
    if (titleController.text.trim().isEmpty) return;
    try {
      await context.read<NotificationRepository>().send(
        toUserId: user.uid,
        title: titleController.text.trim(),
        body: bodyController.text.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notificación enviada a ${user.name}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo enviar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userService = context.read<UserRepository>();
    final currentUid = context.read<AuthController>().profile?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(hintText: 'Buscar usuarios...', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var users = snapshot.data ?? [];
                  if (_roleFilter != null) {
                    users = users.where((u) => u.role == _roleFilter).toList();
                  }
                  if (_query.isNotEmpty) {
                    users = users
                        .where((u) => u.name.toLowerCase().contains(_query) || u.email.toLowerCase().contains(_query))
                        .toList();
                  }
                  if (users.isEmpty) {
                    return const Center(
                      child: Text('No se encontraron usuarios', style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final initials = user.name.isNotEmpty
                          ? user.name.trim().split(RegExp(r'\s+')).map((p) => p[0]).take(2).join().toUpperCase()
                          : '?';
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Text(
                                initials,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    user.email,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  if (user.uid == currentUid)
                                    Text(
                                      _roleLabel(user.role),
                                      style: const TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else
                                    PopupMenuButton<UserRole>(
                                      initialValue: user.role,
                                      onSelected: (role) => userService.setRole(user.uid, role),
                                      itemBuilder: (context) => UserRole.values
                                          .map((role) => PopupMenuItem(value: role, child: Text(_roleLabel(role))))
                                          .toList(),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _roleLabel(user.role),
                                            style: const TextStyle(
                                              color: AppColors.accent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.accent),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined, color: AppColors.accent),
                              tooltip: 'Enviar notificación',
                              onPressed: () => _notify(context, user),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                StatusBadge.active(user.active),
                                Switch(
                                  value: user.active,
                                  onChanged: (value) => userService.setActive(user.uid, value),
                                ),
                              ],
                            ),
                          ],
                        ),
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

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
    );
  }
}
