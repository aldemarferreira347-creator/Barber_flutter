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
          final shop = shopSnapshot.data;
          if (shop == null) return const Center(child: CircularProgressIndicator());

          final isStaff = profile != null && _isStaffOfShop(profile, shop);

          return StreamBuilder<List<Comment>>(
            stream: context.read<CommentRepository>().watchPublishedByBarbershop(barbershopId),
            builder: (context, commentsSnapshot) {
              final comments = commentsSnapshot.data ?? const <Comment>[];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _AverageRatingHeader(shop: shop),
                  const SizedBox(height: 20),
                  if (comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Todavía no hay comentarios.', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    for (final comment in comments) ...[
                      _CommentCard(comment: comment, canReply: isStaff && !comment.hasReply),
                      const SizedBox(height: 10),
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

class _AverageRatingHeader extends StatelessWidget {
  final Barbershop shop;

  const _AverageRatingHeader({required this.shop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: AppColors.primary, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shop.ratingCount == 0 ? 'Sin calificaciones aún' : shop.averageRating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              if (shop.ratingCount > 0)
                Text(
                  '${shop.ratingCount} calificación(es)',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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

  const _CommentCard({required this.comment, required this.canReply});

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  final _replyController = TextEditingController();
  bool _replying = false;
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await context.read<CommentRepository>().replyToComment(commentId: widget.comment.appointmentId, replyText: text);
      if (mounted) setState(() => _replying = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo enviar la respuesta: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment.clientName, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(comment.text),
          if (comment.photoUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(comment.photoUrl!, height: 140, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          if (comment.hasReply) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Respuesta de la barbería', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(comment.replyText!),
                ],
              ),
            ),
          ] else if (widget.canReply) ...[
            const SizedBox(height: 10),
            if (_replying)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _replyController,
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: 'Responder a este comentario...'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _sending ? null : _sendReply,
                      child: _sending
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Enviar'),
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => setState(() => _replying = true), child: const Text('Responder')),
              ),
          ],
        ],
      ),
    );
  }
}
