import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'app_dialog.dart';
import 'app_network_image.dart';

/// Foto elegida: bytes ya leídos y nombre original del archivo.
typedef PickedPhoto = ({Uint8List bytes, String name});

/// Recuadro para elegir una foto (cámara o galería) con vista previa de la
/// foto nueva o, si no hay, de la que ya tenía ([url]). Solo muestra la
/// elección: quien lo usa sube el archivo al guardar.
class PhotoPickerField extends StatelessWidget {
  final PickedPhoto? picked;
  final String? url;
  final String label;
  final double height;
  final ValueChanged<PickedPhoto> onPicked;

  const PhotoPickerField({
    super.key,
    required this.picked,
    required this.url,
    required this.onPicked,
    this.label = 'Añadir foto',
    this.height = 140,
  });

  Future<void> _choose(BuildContext context) async {
    final source = await AppBottomSheet.show<ImageSource>(
      context,
      title: 'Foto',
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de galería'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (file == null) return;
    onPicked((bytes: await file.readAsBytes(), name: file.name));
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    final remote = url;
    final hasPhoto = picked != null || (remote != null && remote.isNotEmpty);

    Widget content;
    if (picked != null) {
      content = ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          picked!.bytes,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          semanticLabel: 'Foto elegida',
        ),
      );
    } else if (remote != null && remote.isNotEmpty) {
      content = AppNetworkImage(
        url: remote,
        semanticLabel: 'Foto actual',
        width: double.infinity,
        height: height,
        borderRadius: radius,
      );
    } else {
      content = Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary),
            const SizedBox(height: AppSpace.xs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    return Semantics(
      button: true,
      label: hasPhoto ? 'Cambiar foto' : label,
      child: InkWell(
        borderRadius: radius,
        onTap: () => _choose(context),
        child: content,
      ),
    );
  }
}
