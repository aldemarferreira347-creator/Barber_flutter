import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/responsive_body.dart';
import '../widgets/shimmer_box.dart';
import '../../utils/error_text.dart';

class ManageBarbersView extends StatelessWidget {
  final String barbershopId;

  const ManageBarbersView({super.key, required this.barbershopId});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _hireBarber(BuildContext context) async {
    final repo = context.read<UserRepository>();
    final user = await AppBottomSheet.show<AppUser>(
      context,
      title: 'Contratar barbero',
      child: _FindClientForm(repo: repo),
    );
    if (user == null || !context.mounted) return;

    final who = user.name.isEmpty ? user.email : user.name;
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Contratar a $who',
      message:
          '${user.email} pasará a ser barbero de tu barbería y podrá recibir '
          'y atender citas.',
      confirmLabel: 'Contratar',
    );
    if (!confirmed || !context.mounted) return;

    try {
      await repo.hireAsBarber(uid: user.uid, barbershopId: barbershopId);
      if (context.mounted) _snack(context, '$who ahora es barbero.');
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'No se pudo contratar: ${errorText(e)}');
      }
    }
  }

  Future<void> _release(BuildContext context, AppUser barber) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Dar de baja',
      message:
          '¿Quitar a ${barber.name} como barbero de tu barbería? Volverá a '
          'ser cliente.',
      confirmLabel: 'Dar de baja',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<UserRepository>().releaseFromBarbershop(barber.uid);
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'No se pudo dar de baja: ${errorText(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<UserRepository>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Barberos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _hireBarber(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Contratar'),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: repo.watchBarbersByBarbershop(barbershopId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: ErrorState(title: 'No pudimos cargar los barberos'),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: ShimmerList(),
            );
          }
          final barbers = snapshot.data!;
          if (barbers.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.content_cut,
                title: 'Sin barberos todavía',
                subtitle: 'Contrata a un cliente ya registrado para que trabaje en tu barbería.',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(top: AppSpace.lg, bottom: 96),
            children: [
              ResponsiveBody(
                child: Column(
                  children: [
                    for (final barber in barbers) ...[
                      AppCard(
                        padding: const EdgeInsets.all(AppSpace.md),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.surfaceRaised,
                              child: Text(
                                barber.initials,
                                style: text.labelLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    barber.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleSmall,
                                  ),
                                  Text(
                                    barber.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _release(context, barber),
                              child: Text(
                                'Dar de baja',
                                style: TextStyle(
                                  color: AppColors.readable(AppColors.error),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Formulario de la hoja: busca por correo a un cliente ya registrado y lo
/// devuelve si se puede contratar; si no, explica por qué en el mismo lugar.
class _FindClientForm extends StatefulWidget {
  final UserRepository repo;

  const _FindClientForm({required this.repo});

  @override
  State<_FindClientForm> createState() => _FindClientFormState();
}

class _FindClientFormState extends State<_FindClientForm> {
  final _email = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _problem = 'Escribe un correo válido.');
      return;
    }
    try {
      final user = await widget.repo.findByEmail(email);
      if (!mounted) return;
      if (user == null) {
        setState(
          () => _problem =
              'No existe ninguna cuenta con ese correo. Pídele que se '
              'registre primero como cliente.',
        );
      } else if (user.role != UserRole.client) {
        setState(
          () => _problem =
              '${user.name.isEmpty ? user.email : user.name} ya tiene otro '
              'rol y no se puede contratar.',
        );
      } else {
        Navigator.of(context).pop(user);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _problem = 'No se pudo buscar: ${errorText(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Escribe el correo de un cliente ya registrado en BarberFlow para '
          'contratarlo como barbero de tu barbería.',
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.search,
          onChanged: (_) {
            if (_problem != null) setState(() => _problem = null);
          },
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
            labelText: 'Correo del barbero',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        if (_problem != null) ...[
          const SizedBox(height: AppSpace.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              _problem!,
              style: text.bodyMedium?.copyWith(
                color: AppColors.readable(AppColors.error),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        AppButton(
          onPressed: _search,
          icon: Icons.search,
          child: const Text('Buscar'),
        ),
      ],
    );
  }
}
