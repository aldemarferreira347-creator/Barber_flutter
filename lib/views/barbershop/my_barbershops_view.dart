import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/shop_avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/shimmer_box.dart';
import 'add_barbershop_view.dart';
import 'approval_status_badge.dart';
import 'owner_alerts_section.dart';
import 'owner_barbershop_manage_view.dart';

/// "Mis barberías": las barberías que administra el usuario autenticado y
/// sus borradores — NO el catálogo para reservar (eso es `Explorar`).
///
/// El dueño se toma siempre de la sesión y nunca de un parámetro, así que
/// esta pantalla no puede abrirse sobre las barberías de otra persona (el
/// admin, que sí ve todas, usa `ManageBarbershopsView(adminControls: true)`).
class MyBarbershopsView extends StatelessWidget {
  const MyBarbershopsView({super.key});

  void _openForm(BuildContext context, {Barbershop? draft}) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AddBarbershopView(draft: draft)));
  }

  Future<void> _deleteDraft(
    BuildContext context,
    BarbershopRepository repo,
    Barbershop draft,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar borrador'),
        content: Text('¿Eliminar el borrador "${draft.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repo.deleteDraft(draft.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthController>().profile?.uid;
    final repo = context.read<BarbershopRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis barberías')),
      floatingActionButton: uid == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Nueva barbería'),
            ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<Barbershop>>(
              stream: repo.watchByOwner(uid),
              builder: (context, shopsSnapshot) {
                return StreamBuilder<List<Barbershop>>(
                  stream: repo.watchDraftsByOwner(uid),
                  builder: (context, draftsSnapshot) {
                    if (shopsSnapshot.hasError || draftsSnapshot.hasError) {
                      return const Center(
                        child: ErrorState(
                          title: 'No pudimos cargar tus barberías',
                          subtitle:
                              'Verifica tu conexión e inténtalo de nuevo.',
                        ),
                      );
                    }
                    if (!shopsSnapshot.hasData || !draftsSnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: ShimmerList(),
                      );
                    }
                    final shops = shopsSnapshot.data!.toList()
                      ..sort((a, b) => a.name.compareTo(b.name));
                    final drafts = draftsSnapshot.data!.toList()
                      ..sort((a, b) => a.name.compareTo(b.name));
                    if (shops.isEmpty && drafts.isEmpty) {
                      return const Center(
                        child: EmptyState(
                          icon: Icons.storefront_outlined,
                          title: 'Aún no tienes barberías',
                          subtitle: 'Registra una pagando la primera mensualidad, o guárdala como borrador para pagar después.',
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [
                        OwnerAlertsSection(shops: shops),
                        for (var i = 0; i < shops.length; i++) ...[
                          _ShopTile(
                            shop: shops[i],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OwnerBarbershopManageView(
                                  barbershopId: shops[i].id,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (drafts.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Text(
                              'Borradores (${drafts.length}/$kMaxBarbershopDrafts) · sin pagar, solo tú los ves',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          for (final draft in drafts) ...[
                            _ShopTile(
                              shop: draft,
                              onTap: () => _openForm(context, draft: draft),
                              trailing: IconButton(
                                tooltip: 'Eliminar borrador',
                                icon: const Icon(Icons.delete_outline),
                                color: AppColors.error,
                                onPressed: () =>
                                    _deleteDraft(context, repo, draft),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  final Barbershop shop;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ShopTile({required this.shop, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        shadowColor: AppColors.textPrimary.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ShopAvatar(photoUrl: shop.photoUrl, name: shop.name, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if ((shop.address ?? '').isNotEmpty)
                        Text(
                          shop.address!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 6),
                      ApprovalStatusBadge(status: shop.approvalStatus),
                    ],
                  ),
                ),
                trailing ??
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
