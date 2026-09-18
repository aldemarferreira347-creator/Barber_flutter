import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';

class AddBarbershopView extends StatefulWidget {
  const AddBarbershopView({super.key});

  @override
  State<AddBarbershopView> createState() => _AddBarbershopViewState();
}

class _AddBarbershopViewState extends State<AddBarbershopView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationService = LocationService();
  bool _saving = false;
  bool _locating = false;
  Position? _position;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final position = await _locationService.getCurrentPosition();
      setState(() => _position = position);
    } on LocationException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ownerId = context.read<AuthController>().profile?.uid;
    if (ownerId == null) return;

    setState(() => _saving = true);
    final repo = context.read<BarbershopRepository>();
    try {
      final id = await repo.create(
            Barbershop(
              id: '',
              name: _nameController.text.trim(),
              ownerId: ownerId,
              address: _addressController.text.trim(),
              phone: _phoneController.text.trim(),
              email: _emailController.text.trim(),
              description: _descriptionController.text.trim(),
            ),
          );
      if (_position != null) {
        await repo.updateLocation(id, _position!.latitude, _position!.longitude);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva barbería')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.storefront_outlined)),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Dirección', prefixIcon: Icon(Icons.location_on_outlined)),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_outlined)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo de contacto', prefixIcon: Icon(Icons.mail_outline)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción', prefixIcon: Icon(Icons.notes_outlined)),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_position == null ? Icons.my_location_outlined : Icons.check_circle, color: _position == null ? null : AppColors.success),
                label: Text(_position == null ? 'Usar mi ubicación actual' : 'Ubicación guardada ✓'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar barbería'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
