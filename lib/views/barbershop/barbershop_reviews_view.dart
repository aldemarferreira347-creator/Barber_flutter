import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/app_user.dart';
import '../../models/barbershop.dart';
import '../../models/comment.dart';
import '../../models/user_role.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/comment_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_network_image.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/responsive_body.dart';
import '../widgets/shimmer_box.dart';
import '../../utils/error_text.dart';

bool _isStaffOfShop(AppUser profile, Barbershop shop) {
  if (profile.role == UserRole.admin) return true;
  if (profile.role == UserRole.owner) return shop.ownerId == profile.uid;
  if (profile.role == UserRole.barber) return profile.barbershopId == shop.id;
  return false;
}

/// Reseñas de la barbería (spec 7.1/7.2): promedio de calificación y los
/// comentarios publicados, con la respuesta del personal cuando existe.
class BarbershopReviewsView extends StatelessWidget {
  final String barbershopId;

  const BarbershopReviewsView({super.key, required this.barbershopId});

  @override
  Widget build(BuildContext context) {
    final barbershopRepo = context.read<BarbershopRepository>();
    final profile = context.watch<AuthController>().profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Reseñas')),
      body: StreamBuilder<Barbershop?>(
        stream: barbershopRepo.watchOne(barbershopId),
        builder: (context, shopSnapshot) {
          if (shopSnapshot.hasError) {
            return const Center(
              child: ErrorState(
                title: 'No pudimos cargar las reseñas',
                subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
              ),
            );
          }
          final shop = shopSnapshot.data;
          if (shop == null) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: ShimmerList(count: 4),
            );
          }

          final isStaff = profile != null && _isStaffOfShop(profile, shop);

          return StreamBuilder<List<Comment>>(
            stream: context
                .read<CommentRepository>()
                .watchPublishedByBarbershop(barbershopId),
            builder: (context, commentsSnapshot) {
              if (commentsSnapshot.hasError) {
                return const Center(
                  child: ErrorState(
                    title: 'No pudimos cargar los comentarios',
                    subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
                  ),
                );
              }
              final comments = commentsSnapshot.data ?? const <Comment>[];

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
                children: [
                  ResponsiveBody(
                    maxWidth: AppLayout.formWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AverageRatingHeader(shop: shop),
                        const SizedBox(height: AppSpace.xl),
                        if (comments.isEmpty)
                          const EmptyState(
                            icon: Icons.chat_bubble_outline,
                            title: 'Todavía no hay comentarios',
                            subtitle: 'Los clientes pueden comentar después de una cita completada.',
                          )
                        else
                          for (final comment in comments) ...[
                            _CommentCard(
                              key: ValueKey(comment.appointmentId),
                              comment: comment,
                              canReply: isStaff && !comment.hasReply,
                            ),
                            const SizedBox(height: AppSpace.md),
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

class _AverageRatingHeader extends StatelessWidget {
  final Barbershop shop;

  const _AverageRatingHeader({required this.shop});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.star, color: AppColors.gold, size: 32),
          const SizedBox(width: AppSpace.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shop.ratingCount == 0
                    ? 'Sin calificaciones aún'
                    : shop.averageRating.toStringAsFixed(1),
                style: text.titleLarge,
              ),
              if (shop.ratingCount > 0)
                Text(
                  shop.ratingCount == 1
                      ? '1 calificación'
                      : '${shop.ratingCount} calificaciones',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatefulWidget {
  final Comment comment;
  final bool canReply;

  const _CommentCard({
    super.key,
    required this.comment,
    required this.canReply,
  });

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  final _replyController = TextEditingController();
  bool _replying = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    try {
      await context.read<CommentRepository>().replyToComment(
        commentId: widget.comment.appointmentId,
        replyText: text,
      );
      if (mounted) setState(() => _replying = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo enviar la respuesta: ${errorText(e)}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment.clientName, style: text.titleSmall),
          const SizedBox(height: AppSpace.xs),
          Text(comment.text, style: text.bodyMedium),
          if (comment.photoUrl != null) ...[
            const SizedBox(height: AppSpace.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: AppNetworkImage(
                url: comment.photoUrl!,
                semanticLabel: 'Foto adjunta a la reseña',
                height: 140,
                width: double.infinity,
              ),
            ),
          ],
          if (comment.hasReply) ...[
            const SizedBox(height: AppSpace.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Respuesta de la barbería', style: text.labelLarge),
                  const SizedBox(height: AppSpace.xs),
                  Text(comment.replyText!, style: text.bodyMedium),
                ],
              ),
            ),
          ] else if (widget.canReply) ...[
            const SizedBox(height: AppSpace.sm),
            if (_replying)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _replyController,
                    maxLines: 2,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Tu respuesta',
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _replying = false),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      AppButton(
                        expand: false,
                        onPressed: _sendReply,
                        child: const Text('Enviar'),
                      ),
                    ],
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _replying = true),
                  child: const Text('Responder'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
