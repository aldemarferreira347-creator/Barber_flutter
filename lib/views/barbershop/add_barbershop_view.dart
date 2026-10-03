import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../models/platform_settings.dart';
import '../../models/user_role.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/platform_settings_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/nequi_payment_sheet.dart';
import '../widgets/responsive_body.dart';

/// Alta de barbería. Registrar cuesta la mensualidad de la plataforma
/// ([PlatformSettings.monthlyFee]): el dueño paga por Nequi y la envía a
/// revisión (el administrador verifica el pago y la aprueba), o la deja como
/// borrador (máximo [kMaxBarbershopDrafts]) y paga después. Con [draft]
/// edita un borrador existente.
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
  final _nequiController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationService = LocationService();
  final _picker = ImagePicker();
  late final Stream<PlatformSettings> _settings = context
      .read<PlatformSettingsRepository>()
      .watch();
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
      _nequiController.text = draft.nequiPhone ?? '';
      _descriptionController.text = draft.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nequiController.dispose();
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

  Future<void> _showPhotoOptions() async {
    final source = await AppBottomSheet.show<ImageSource>(
      context,
      title: 'Foto de portada',
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
    if (source != null) await _pickPhoto(source);
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
    final nequi = normalizeNequiPhone(_nequiController.text);
    return Barbershop(
      id: widget.draft?.id ?? '',
      name: _nameController.text.trim(),
      ownerId: ownerId,
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      description: _descriptionController.text.trim(),
      photoUrl: widget.draft?.photoUrl,
      nequiPhone: nequi.isEmpty ? null : nequi,
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

  Future<void> _payAndRegister(PlatformSettings settings) async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final ownerId = auth.profile?.uid;
    if (ownerId == null) return;

    final reference = await showNequiPaymentSheet(
      context,
      title: 'Pagar primera mensualidad',
      amount: settings.monthlyFee,
      payeeName: 'BarberFlow',
      payeePhone: settings.nequiPhone!,
      verifier: 'el administrador de BarberFlow',
    );
    if (reference == null || !mounted) return;

    setState(() => _paying = true);
    final repo = context.read<BarbershopRepository>();
    final userRepo = context.read<UserRepository>();
    try {
      if (widget.draft != null) {
        // Se guardan primero las ediciones del formulario: publishDraft
        // convierte lo que hay guardado en el borrador.
        final id = await _persistDraft(repo, ownerId);
        await repo.publishDraft(id, reference: reference);
      } else {
        final shopId = await repo.createPaid(
          _buildShop(ownerId),
          reference: reference,
        );
        if (_photoBytes != null) {
          await repo.uploadPhoto(
            shopId,
            fileName: _photoFileName,
            bytes: _photoBytes!,
          );
        }
      }
      // Solicitud de rol de Dueño (spec 12.1): sin plan Blaze no hay función
      // en la nube; la regla de users/{uid} tiene una rama dedicada y
      // acotada solo a client->owner (ver firestore.rules).
      if (auth.profile?.role == UserRole.client) {
        await userRepo.setRole(ownerId, UserRole.owner);
        await auth.refreshProfile();
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Comprobante enviado. El administrador verificará tu pago y '
              'revisará tu barbería.',
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

  Widget _photoPicker() {
    final text = Theme.of(context).textTheme;
    final remote = widget.draft?.photoUrl;
    final hasPhoto = _photoBytes != null || remote != null;
    return Semantics(
      button: true,
      label: hasPhoto ? 'Cambiar foto de portada' : 'Añadir foto de portada',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: _showPhotoOptions,
        child: Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            image: _photoBytes != null
                ? DecorationImage(
                    image: MemoryImage(_photoBytes!),
                    fit: BoxFit.cover,
                  )
                : remote != null
                ? DecorationImage(
                    image: CachedNetworkImageProvider(remote),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: hasPhoto
              ? null
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text('Añadir foto de portada', style: text.bodySmall),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.draft == null ? 'Nueva barbería' : 'Editar borrador',
        ),
      ),
      body: StreamBuilder<PlatformSettings>(
        stream: _settings,
        initialData: PlatformSettings.defaults,
        builder: (context, snapshot) {
          final settings = snapshot.data ?? PlatformSettings.defaults;
          final busy = _saving || _paying;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
              children: [
                ResponsiveBody(
                  maxWidth: AppLayout.formWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _photoPicker(),
                      const SizedBox(height: AppSpace.lg),
                      AppCard(
                        color: AppColors.surfaceRaised,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: Text(
                                'Para registrarla pagas la primera mensualidad '
                                '(${formatCop(settings.monthlyFee)}) por Nequi; '
                                'el administrador verifica el pago y revisa la '
                                'barbería antes de mostrarla en el catálogo. '
                                'Si prefieres, guárdala como borrador (máximo '
                                '$kMaxBarbershopDrafts) y págala después.',
                                style: text.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: AppSpace.lg),
                      TextFormField(
                        controller: _addressController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: AppSpace.lg),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo de contacto',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      TextFormField(
                        controller: _nequiController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Nequi para cobros (opcional)',
                          helperText:
                              'Tus clientes pagarán citas y productos a este '
                              'número. Sin él solo cobras en el local.',
                          helperMaxLines: 2,
                          prefixIcon: Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                        ),
                        validator: validateNequiPhone,
                      ),
                      const SizedBox(height: AppSpace.lg),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      AppButton(
                        variant: AppButtonVariant.secondary,
                        onPressed: _locating ? null : _useCurrentLocation,
                        loading: _locating,
                        icon: _position == null
                            ? Icons.my_location_outlined
                            : Icons.check_circle_outline,
                        child: Text(
                          _position == null
                              ? 'Usar mi ubicación actual'
                              : 'Ubicación guardada',
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      if (!settings.canCharge)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.md),
                          child: Text(
                            'El administrador aún no configuró el Nequi de la '
                            'plataforma, así que por ahora solo puedes '
                            'guardar la barbería como borrador.',
                            style: text.secondary,
                          ),
                        ),
                      AppButton(
                        onPressed: (busy || !settings.canCharge)
                            ? null
                            : () => _payAndRegister(settings),
                        icon: Icons.payments_outlined,
                        loading: _paying,
                        child: Text(
                          'Pagar y registrar (${formatCop(settings.monthlyFee)})',
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      AppButton(
                        variant: AppButtonVariant.secondary,
                        onPressed: busy ? null : _saveDraft,
                        loading: _saving,
                        icon: Icons.edit_note_outlined,
                        child: const Text('Guardar como borrador'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
