import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../models/comment.dart';
import '../../repositories/comment_repository.dart';
import '../../repositories/rating_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/photo_picker_field.dart';
import '../widgets/responsive_body.dart';
import '../../utils/error_text.dart';

/// Calificación y comentario opcional de una cita pagada y completada
/// (spec 7.1/7.2), con los lineamientos de conducta (spec 7.4) mostrados
/// antes de calificar.
class RateAppointmentView extends StatefulWidget {
  final Appointment appointment;

  const RateAppointmentView({super.key, required this.appointment});

  @override
  State<RateAppointmentView> createState() => _RateAppointmentViewState();
}

class _RateAppointmentViewState extends State<RateAppointmentView> {
  final _commentController = TextEditingController();

  int _barberStars = 0;
  int _shopStars = 0;
  PickedPhoto? _photo;

  /// La calificación ya quedó guardada: si el comentario o la foto fallan, el
  /// reintento solo repite el comentario (calificar dos veces no se puede).
  bool _ratingSaved = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_barberStars == 0 || _shopStars == 0) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ratings = context.read<RatingRepository>();
    final comments = context.read<CommentRepository>();

    if (!_ratingSaved) {
      try {
        await ratings.submitRating(
          appointmentId: widget.appointment.id,
          barberStars: _barberStars,
          shopStars: _shopStars,
        );
        if (mounted) setState(() => _ratingSaved = true);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('No se pudo enviar la calificación: ${errorText(e)}'),
          ),
        );
        return;
      }
    }

    CommentStatus? commentStatus;
    final commentText = _commentController.text.trim();
    if (commentText.isNotEmpty) {
      try {
        String? photoUrl;
        final photo = _photo;
        if (photo != null) {
          photoUrl = await comments.uploadPhoto(
            appointmentId: widget.appointment.id,
            fileName: '${DateTime.now().millisecondsSinceEpoch}_${photo.name}',
            bytes: photo.bytes,
          );
        }
        commentStatus = await comments.submitComment(
          appointmentId: widget.appointment.id,
          text: commentText,
          photoUrl: photoUrl,
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Tu calificación ya se guardó, pero el comentario no se pudo '
              'enviar: $e. Inténtalo de nuevo.',
            ),
          ),
        );
        return;
      }
    }

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          commentStatus == CommentStatus.rejected
              ? 'Gracias por calificar. Tu comentario no se publicó por '
                    'contener lenguaje inapropiado.'
              : '¡Gracias por calificar!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Calificar servicio')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          children: [
            ResponsiveBody(
              maxWidth: AppLayout.formWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ConductGuidelines(),
                  const SizedBox(height: AppSpace.xl),
                  Text(
                    '¿Cómo estuvo ${appointment.barberName}?',
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  _StarPicker(
                    label: 'Calificación del barbero',
                    value: _barberStars,
                    onChanged: _ratingSaved
                        ? null
                        : (v) => setState(() => _barberStars = v),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Text(
                    '¿Cómo estuvo la barbería en general?',
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  _StarPicker(
                    label: 'Calificación de la barbería',
                    value: _shopStars,
                    onChanged: _ratingSaved
                        ? null
                        : (v) => setState(() => _shopStars = v),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Comentario (opcional)',
                      hintText: 'Cuéntanos cómo te fue...',
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  PhotoPickerField(
                    picked: _photo,
                    url: null,
                    label: 'Adjuntar foto del resultado',
                    onPicked: (photo) => setState(() => _photo = photo),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  AppButton(
                    onPressed: (_barberStars > 0 && _shopStars > 0)
                        ? _submit
                        : null,
                    icon: Icons.send_outlined,
                    child: Text(
                      _ratingSaved
                          ? 'Reenviar comentario'
                          : 'Enviar calificación',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int>? onChanged;

  const _StarPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      value: value == 0 ? 'sin calificar' : '$value de 5',
      child: Row(
        children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              tooltip: i == 1 ? '1 estrella' : '$i estrellas',
              onPressed: onChanged == null ? null : () => onChanged!(i),
              icon: Icon(
                i <= value ? Icons.star : Icons.star_border,
                color: AppColors.gold,
                size: 32,
              ),
            ),
        ],
      ),
    );
  }
}

class _ConductGuidelines extends StatelessWidget {
  const _ConductGuidelines();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Antes de calificar', style: text.titleSmall),
          const SizedBox(height: AppSpace.sm),
          Text(
            'La barbería debe garantizar puntualidad, higiene y buen trato. '
            'Te pedimos que tu comentario sea constructivo: describe tu '
            'experiencia con respeto, sin insultos ni lenguaje ofensivo.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
