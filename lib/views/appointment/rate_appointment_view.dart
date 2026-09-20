import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../models/comment.dart';
import '../../repositories/comment_repository.dart';
import '../../repositories/rating_repository.dart';
import '../../theme/app_colors.dart';

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
  final _picker = ImagePicker();

  int _barberStars = 0;
  int _shopStars = 0;
  Uint8List? _photoBytes;
  String? _photoName;
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoName = file.name;
    });
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.of(context).pop();
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () {
                Navigator.of(context).pop();
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_barberStars == 0 || _shopStars == 0) return;
    setState(() => _saving = true);
    try {
      await context.read<RatingRepository>().submitRating(
        appointmentId: widget.appointment.id,
        barberStars: _barberStars,
        shopStars: _shopStars,
      );

      if (!mounted) return;

      CommentStatus? commentStatus;
      final commentText = _commentController.text.trim();
      if (commentText.isNotEmpty) {
        final commentRepo = context.read<CommentRepository>();
        String? photoUrl;
        if (_photoBytes != null) {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${_photoName ?? 'foto.jpg'}';
          photoUrl = await commentRepo.uploadPhoto(
            appointmentId: widget.appointment.id,
            fileName: fileName,
            bytes: _photoBytes!,
          );
        }
        commentStatus = await commentRepo.submitComment(
          appointmentId: widget.appointment.id,
          text: commentText,
          photoUrl: photoUrl,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        final message = commentStatus == CommentStatus.rejected
            ? 'Gracias por calificar. Tu comentario no se publicó por contener lenguaje inapropiado.'
            : '¡Gracias por calificar!';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar la calificación: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    return Scaffold(
      appBar: AppBar(title: const Text('Calificar servicio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConductGuidelines(),
          const SizedBox(height: 20),
          Text(
            '¿Cómo estuvo ${appointment.barberName}?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _StarPicker(
            value: _barberStars,
            onChanged: (v) => setState(() => _barberStars = v),
          ),
          const SizedBox(height: 20),
          const Text(
            '¿Cómo estuvo la barbería en general?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _StarPicker(
            value: _shopStars,
            onChanged: (v) => setState(() => _shopStars = v),
          ),
          const SizedBox(height: 24),
          const Text(
            'Comentario (opcional)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Cuéntanos cómo te fue...',
            ),
          ),
          const SizedBox(height: 12),
          if (_photoBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _photoBytes!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showPhotoOptions,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(
              _photoBytes == null
                  ? 'Adjuntar foto del resultado'
                  : 'Cambiar foto',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_barberStars > 0 && _shopStars > 0 && !_saving)
                ? _submit
                : null,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Enviar calificación'),
          ),
        ],
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StarPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () => onChanged(i),
            icon: Icon(
              i <= value ? Icons.star : Icons.star_border,
              color: AppColors.primary,
              size: 32,
            ),
          ),
      ],
    );
  }
}

class _ConductGuidelines extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Antes de calificar',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'La barbería debe garantizar puntualidad, higiene y buen trato. '
            'Te pedimos que tu comentario sea constructivo: describe tu experiencia '
            'con respeto, sin insultos ni lenguaje ofensivo.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
