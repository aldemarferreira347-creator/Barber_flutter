import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/responsive_body.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/shop_avatar.dart';
import 'add_barbershop_view.dart';
import 'approval_status_badge.dart';
import 'owner_alerts_section.dart';
import 'owner_barbershop_manage_view.dart';
import '../../utils/error_text.dart';

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
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Eliminar borrador',
      message: '¿Eliminar el borrador "${draft.name}"? No se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await repo.deleteDraft(draft.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: ${errorText(e)}')),
        );
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
                      padding: const EdgeInsets.only(
                        top: AppSpace.lg,
                        bottom: 96,
                      ),
                      children: [
                        ResponsiveBody(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OwnerAlertsSection(shops: shops),
                              if (shops.isNotEmpty)
                                SectionHeader(
                                  title: 'Barberías (${shops.length})',
                                ),
                              for (final shop in shops) ...[
                                _ShopTile(
                                  shop: shop,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => OwnerBarbershopManageView(
                                        barbershopId: shop.id,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpace.md),
                              ],
                              if (drafts.isNotEmpty) ...[
                                const SizedBox(height: AppSpace.sm),
                                SectionHeader(
                                  title:
                                      'Borradores (${drafts.length}/$kMaxBarbershopDrafts)',
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpace.md,
                                  ),
                                  child: Text(
                                    'Sin pagar: solo tú los ves. Al pagar la '
                                    'mensualidad pasan a revisión.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ),
                                for (final draft in drafts) ...[
                                  _ShopTile(
                                    shop: draft,
                                    onTap: () =>
                                        _openForm(context, draft: draft),
                                    trailing: IconButton(
                                      tooltip: 'Eliminar borrador',
                                      icon: const Icon(Icons.delete_outline),
                                      color: AppColors.readable(
                                        AppColors.error,
                                      ),
                                      onPressed: () =>
                                          _deleteDraft(context, repo, draft),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpace.md),
                                ],
                              ],
                            ],
                          ),
                        ),
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
    return AppCard(
      onTap: onTap,
      semanticLabel: shop.name,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          ShopAvatar(photoUrl: shop.photoUrl, name: shop.name, size: 52),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if ((shop.address ?? '').isNotEmpty)
                  Text(
                    shop.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                const SizedBox(height: AppSpace.sm),
                ApprovalStatusBadge(status: shop.approvalStatus),
              ],
            ),
          ),
          trailing ?? Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
