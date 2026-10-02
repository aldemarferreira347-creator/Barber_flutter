import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../widgets/app_button.dart';

/// Edición de los datos básicos de una barbería que ya existe (Update del
/// CRUD del dueño). No toca aprobación, bloqueo ni pago: esos campos los
/// protege firestore.rules aunque se intentara.
class EditBarbershopView extends StatefulWidget {
  final Barbershop shop;

  const EditBarbershopView({super.key, required this.shop});

  @override
  State<EditBarbershopView> createState() => _EditBarbershopViewState();
}

class _EditBarbershopViewState extends State<EditBarbershopView> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.shop.name);
  late final _addressController = TextEditingController(
    text: widget.shop.address ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.shop.phone ?? '',
  );
  late final _emailController = TextEditingController(
    text: widget.shop.email ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.shop.description ?? '',
  );
  final _locationService = LocationService();
  final _picker = ImagePicker();
  bool _saving = false;
  bool _locating = false;
  Position? _position;
  Uint8List? _photoBytes;
  String? _photoName;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
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

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final position = await _locationService.getCurrentPosition();
      setState(() => _position = position);
    } on LocationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = context.read<BarbershopRepository>();
    final id = widget.shop.id;
    try {
      await repo.updateInfo(
        id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _optional(_phoneController),
        email: _optional(_emailController),
        description: _optional(_descriptionController),
      );
      if (_position != null) {
        await repo.updateLocation(
          id,
          _position!.latitude,
          _position!.longitude,
        );
      }
      if (_photoBytes != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_photoName ?? 'foto.jpg'}';
        await repo.uploadPhoto(id, fileName: fileName, bytes: _photoBytes!);
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Barbería actualizada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPhoto = widget.shop.photoUrl;
    return Scaffold(
      appBar: AppBar(title: const Text('Editar barbería')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    image: _photoBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_photoBytes!),
                            fit: BoxFit.cover,
                          )
                        : currentPhoto != null
                        ? DecorationImage(
                            image: NetworkImage(currentPhoto),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (_photoBytes == null && currentPhoto == null)
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Añadir foto de portada',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Requerido'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Requerido'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo de contacto',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _position == null
                            ? Icons.my_location_outlined
                            : Icons.check_circle,
                        color: _position == null ? null : AppColors.success,
                      ),
                label: Text(
                  _position == null
                      ? 'Actualizar con mi ubicación actual'
                      : 'Ubicación nueva lista ✓',
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                onPressed: _save,
                icon: Icons.save_outlined,
                loading: _saving,
                child: const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
