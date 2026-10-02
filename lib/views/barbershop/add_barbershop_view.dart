import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../models/user_role.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../widgets/app_button.dart';

Widget _entrance(Widget child, int index) {
  return child;
}

/// Alta de barbería. Registrar cuesta [kBarbershopMonthlyFee]: el dueño
/// puede pagar y enviarla a revisión, o dejarla como borrador (máximo
/// [kMaxBarbershopDrafts]) y pagar después. Con [draft] edita un borrador
/// existente.
class AddBarbershopView extends StatefulWidget {
  final Barbershop? draft;

  const AddBarbershopView({super.key, this.draft});

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
  final _picker = ImagePicker();
  bool _saving = false;
  bool _locating = false;
  bool _paying = false;
  Position? _position;
  Uint8List? _photoBytes;
  String? _photoName;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    if (draft != null) {
      _nameController.text = draft.name;
      _addressController.text = draft.address ?? '';
      _phoneController.text = draft.phone ?? '';
      _emailController.text = draft.email ?? '';
      _descriptionController.text = draft.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
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

  Barbershop _buildShop(String ownerId) {
    return Barbershop(
      id: widget.draft?.id ?? '',
      name: _nameController.text.trim(),
      ownerId: ownerId,
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      description: _descriptionController.text.trim(),
      photoUrl: widget.draft?.photoUrl,
      location: _position != null
          ? GeoPoint(_position!.latitude, _position!.longitude)
          : widget.draft?.location,
      schedule: widget.draft?.schedule ?? const {},
      approvalStatus: BarbershopApprovalStatus.draft,
    );
  }

  String get _photoFileName =>
      '${DateTime.now().millisecondsSinceEpoch}_${_photoName ?? 'foto.jpg'}';

  /// Guarda (o actualiza) el borrador, con su foto, y devuelve su id.
  Future<String> _persistDraft(
    BarbershopRepository repo,
    String ownerId,
  ) async {
    final shop = _buildShop(ownerId);
    final existing = widget.draft;
    final String id;
    if (existing != null) {
      id = existing.id;
      await repo.updateDraft(id, shop);
    } else {
      id = await repo.saveDraft(shop);
    }
    if (_photoBytes != null) {
      await repo.uploadDraftPhoto(
        id,
        fileName: _photoFileName,
        bytes: _photoBytes!,
      );
    }
    return id;
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;
    final ownerId = context.read<AuthController>().profile?.uid;
    if (ownerId == null) return;

    setState(() => _saving = true);
    final repo = context.read<BarbershopRepository>();
    try {
      await _persistDraft(repo, ownerId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Borrador guardado. Págalo cuando quieras enviarla a revisión.',
            ),
          ),
        );
      }
    } on BarbershopDraftLimitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
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

  Future<void> _payAndRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final ownerId = auth.profile?.uid;
    if (ownerId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pagar y registrar'),
        content: Text(
          'Se cobrarán ${formatCop(kBarbershopMonthlyFee)} de la primera '
          'mensualidad. Después el administrador revisará tu barbería antes '
          'de publicarla en el catálogo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Pagar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _paying = true);
    final repo = context.read<BarbershopRepository>();
    final userRepo = context.read<UserRepository>();
    try {
      if (widget.draft != null) {
        // Se guardan primero las ediciones del formulario: publishDraft
        // convierte lo que hay guardado en el borrador.
        final id = await _persistDraft(repo, ownerId);
        await repo.publishDraft(id);
      } else {
        final shopId = await repo.createPaid(_buildShop(ownerId));
        if (_photoBytes != null) {
          await repo.uploadPhoto(
            shopId,
            fileName: _photoFileName,
            bytes: _photoBytes!,
          );
        }
      }
      // Solicitud de rol de Dueño (spec 12.1). Antes pasaba por la función
      // en la nube requestBarbershopOwnership (Admin SDK, porque el rol
      // propio está congelado por firestore.rules para el resto de
      // transiciones) — sin plan Blaze esa función no se puede desplegar,
      // así que aquí se hace directo contra Firestore; la regla tiene una
      // rama dedicada y acotada solo a client->owner (ver firestore.rules).
      if (auth.profile?.role == UserRole.client) {
        await userRepo.setRole(ownerId, UserRole.owner);
        await auth.refreshProfile();
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pago recibido. Tu barbería quedó pendiente de revisión por el administrador.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo registrar: $e')));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.draft == null ? 'Nueva barbería' : 'Editar borrador',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _entrance(
                Center(
                  child: GestureDetector(
                    onTap: _showPhotoOptions,
                    child: Container(
                      width: double.infinity,
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
                            : widget.draft?.photoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(widget.draft!.photoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.06,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child:
                          (_photoBytes == null &&
                              widget.draft?.photoUrl == null)
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
                ),
                0,
              ),
              const SizedBox(height: 16),
              _entrance(
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Para registrarla debes pagar la primera mensualidad (\${formatCop(kBarbershopMonthlyFee)}); luego el administrador la revisa antes de mostrarla en el catálogo. Si prefieres, guárdala como borrador (máximo \$kMaxBarbershopDrafts) y págala después.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                1,
              ),
              const SizedBox(height: 20),
              _entrance(
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
                2,
              ),
              const SizedBox(height: 14),
              _entrance(
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
                3,
              ),
              const SizedBox(height: 14),
              _entrance(
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                4,
              ),
              const SizedBox(height: 14),
              _entrance(
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo de contacto',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                5,
              ),
              const SizedBox(height: 14),
              _entrance(
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                6,
              ),
              const SizedBox(height: 14),
              _entrance(
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
                        ? 'Usar mi ubicación actual'
                        : 'Ubicación guardada ✓',
                  ),
                ),
                7,
              ),
              const SizedBox(height: 24),
              AppButton(
                onPressed: (_saving || _paying) ? null : _payAndRegister,
                icon: Icons.payments_outlined,
                loading: _paying,
                child: Text(
                  'Pagar y registrar (${formatCop(kBarbershopMonthlyFee)})',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: (_saving || _paying) ? null : _saveDraft,
                icon: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_note_outlined),
                label: const Text('Guardar como borrador'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
