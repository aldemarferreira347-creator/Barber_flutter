import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import 'user_style.dart';
import '../../utils/error_text.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Selector de rol (un solo valor).
class _RoleSelector extends StatelessWidget {
  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  const _RoleSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rol', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final role in UserRole.values)
              ChoiceChip(
                label: Text(roleLabel(role)),
                selected: value == role,
                onSelected: (_) => onChanged(role),
              ),
          ],
        ),
      ],
    );
  }
}

/// Mensaje de error dentro de la hoja (no se cierra para poder corregir).
class _FormError extends StatelessWidget {
  final String message;

  const _FormError(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.readable(AppColors.error)),
        ),
      ),
    );
  }
}

/// Alta de un usuario por el admin: crea la cuenta de acceso y su perfil sin
/// cerrar la sesión del admin. Cierra la hoja con `true` al terminar.
class AddUserForm extends StatefulWidget {
  const AddUserForm({super.key});

  @override
  State<AddUserForm> createState() => _AddUserFormState();
}

class _AddUserFormState extends State<AddUserForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  UserRole _role = UserRole.client;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == UserRole.admin) {
      final ok = await AppDialog.confirm(
        context,
        title: 'Crear administrador',
        message:
            'Un administrador puede ver y cambiar todo en BarberFlow, '
            'incluidos los pagos. ¿Seguro?',
        confirmLabel: 'Crear administrador',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    final auth = context.read<AuthController>();
    final created = await auth.adminRegisterUser(
      email: _email.text.trim(),
      password: _password.text,
      name: _name.text.trim(),
      role: _role,
    );
    if (!mounted) return;
    if (created) {
      Navigator.of(context).pop(true);
    } else {
      setState(
        () => _error = auth.errorMessage ?? 'No se pudo crear el usuario',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'El usuario podrá iniciar sesión con estas credenciales.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Escribe el nombre' : null,
          ),
          const SizedBox(height: AppSpace.md),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (v) => (v == null || !_emailPattern.hasMatch(v.trim()))
                ? 'Correo inválido'
                : null,
          ),
          const SizedBox(height: AppSpace.md),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
          ),
          const SizedBox(height: AppSpace.md),
          TextFormField(
            controller: _confirm,
            obscureText: _obscure,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) =>
                v != _password.text ? 'Las contraseñas no coinciden' : null,
          ),
          const SizedBox(height: AppSpace.lg),
          _RoleSelector(
            value: _role,
            onChanged: (role) => setState(() => _role = role),
          ),
          if (_error != null) _FormError(_error!),
          const SizedBox(height: AppSpace.xl),
          AppButton(
            onPressed: _submit,
            icon: Icons.person_add_outlined,
            child: const Text('Registrar usuario'),
          ),
        ],
      ),
    );
  }
}

/// Edición de nombre, correo y rol en una sola escritura. Cierra la hoja con
/// `true` si guardó algo.
class EditUserForm extends StatefulWidget {
  final AppUser user;

  const EditUserForm({super.key, required this.user});

  @override
  State<EditUserForm> createState() => _EditUserFormState();
}

class _EditUserFormState extends State<EditUserForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _email = TextEditingController(text: widget.user.email);
  late UserRole _role = widget.user.role;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = widget.user;
    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    final roleChanged = _role != user.role;
    if (name == user.name && email == user.email && !roleChanged) {
      Navigator.of(context).pop(false);
      return;
    }
    if (roleChanged) {
      final ok = await AppDialog.confirm(
        context,
        title: 'Cambiar rol',
        message:
            '${user.name} pasará de ${roleLabel(user.role)} a '
            '${roleLabel(_role)} y verá y podrá hacer cosas distintas en la '
            'app.',
        confirmLabel: 'Cambiar rol',
        destructive: _role == UserRole.admin,
      );
      if (!ok || !mounted) return;
    }
    final repo = context.read<UserRepository>();
    try {
      await repo.updateProfile(
        user.uid,
        name: name == user.name ? null : name,
        email: email == user.email ? null : email,
        role: roleChanged ? _role : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar: ${errorText(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Escribe el nombre' : null,
          ),
          const SizedBox(height: AppSpace.md),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo del perfil',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (v) => (v == null || !_emailPattern.hasMatch(v.trim()))
                ? 'Correo inválido'
                : null,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Cambia el correo que se ve en la app. El correo con el que '
            'inicia sesión no cambia.',
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          _RoleSelector(
            value: _role,
            onChanged: (role) => setState(() => _role = role),
          ),
          if (_error != null) _FormError(_error!),
          const SizedBox(height: AppSpace.xl),
          AppButton(
            onPressed: _save,
            icon: Icons.check_circle_outline,
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }
}

/// Aviso del admin a un usuario: queda en su bandeja de notificaciones de la
/// app (no hay envío push sin servidor).
class NotifyUserForm extends StatefulWidget {
  final AppUser user;

  const NotifyUserForm({super.key, required this.user});

  @override
  State<NotifyUserForm> createState() => _NotifyUserFormState();
}

class _NotifyUserFormState extends State<NotifyUserForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await context.read<NotificationRepository>().send(
        toUserId: widget.user.uid,
        title: _title.text.trim(),
        body: _body.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo enviar: ${errorText(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lo verá en su bandeja de notificaciones dentro de la app.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          TextFormField(
            controller: _title,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Título'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Escribe un título' : null,
          ),
          const SizedBox(height: AppSpace.sm),
          TextFormField(
            controller: _body,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Mensaje'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Escribe el mensaje' : null,
          ),
          if (_error != null) _FormError(_error!),
          const SizedBox(height: AppSpace.lg),
          AppButton(
            onPressed: _send,
            icon: Icons.send_outlined,
            child: const Text('Enviar notificación'),
          ),
        ],
      ),
    );
  }
}
