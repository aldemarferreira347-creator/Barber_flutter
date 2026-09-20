import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../theme/app_colors.dart';

class AddProductView extends StatefulWidget {
  final String barbershopId;

  const AddProductView({super.key, required this.barbershopId});

  @override
  State<AddProductView> createState() => _AddProductViewState();
}

class _AddProductViewState extends State<AddProductView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _photoBytes;
  String? _photoName;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = context.read<ProductRepository>();
      String? photoUrl;
      if (_photoBytes != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_photoName ?? 'foto.jpg'}';
        photoUrl = await repo.uploadPhoto(
          barbershopId: widget.barbershopId,
          fileName: fileName,
          bytes: _photoBytes!,
        );
      }
      await repo.create(
        Product(
          id: '',
          barbershopId: widget.barbershopId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          price: double.tryParse(_priceController.text.trim()) ?? 0,
          photoUrl: photoUrl,
        ),
      );
      if (mounted) Navigator.of(context).pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo producto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => _showPhotoOptions(context),
                  child: Container(
                    width: 140,
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
                          : null,
                    ),
                    child: _photoBytes == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Añadir foto',
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
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Requerido'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) =>
                    (double.tryParse(value ?? '') == null) ? 'Inválido' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar producto'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoOptions(BuildContext context) {
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
}
