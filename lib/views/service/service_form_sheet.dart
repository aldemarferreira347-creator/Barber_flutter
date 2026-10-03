import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/photo_picker_field.dart';

/// Crea o edita un servicio en una hoja modal (en vez de una pantalla
/// aparte): nombre, descripción, precio, duración y foto. Con [service]
/// edita ese servicio y además ofrece eliminarlo. Devuelve `true` si se
/// guardó o eliminó algo.
Future<bool?> showServiceForm(
  BuildContext context, {
  required String barbershopId,
  Service? service,
}) {
  return AppBottomSheet.show<bool>(
    context,
    title: service == null ? 'Nuevo servicio' : 'Editar servicio',
    child: _ServiceForm(barbershopId: barbershopId, service: service),
  );
}

class _ServiceForm extends StatefulWidget {
  final String barbershopId;
  final Service? service;

  const _ServiceForm({required this.barbershopId, required this.service});

  @override
  State<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<_ServiceForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.service?.name ?? '');
  late final _description = TextEditingController(
    text: widget.service?.description ?? '',
  );
  late final _price = TextEditingController(
    text: widget.service == null
        ? ''
        : widget.service!.price.round().toString(),
  );
  late final _duration = TextEditingController(
    text: (widget.service?.durationMinutes ?? 30).toString(),
  );
  PickedPhoto? _photo;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = context.read<ServiceRepository>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      var photoUrl = widget.service?.photoUrl;
      if (_photo != null) {
        photoUrl = await repo.uploadPhoto(
          barbershopId: widget.barbershopId,
          fileName: '${DateTime.now().millisecondsSinceEpoch}_${_photo!.name}',
          bytes: _photo!.bytes,
        );
      }
      final description = _description.text.trim();
      final updated = Service(
        id: widget.service?.id ?? '',
        barbershopId: widget.barbershopId,
        name: _name.text.trim(),
        description: description.isEmpty ? null : description,
        price: double.parse(_price.text.trim()),
        durationMinutes: int.parse(_duration.text.trim()),
        photoUrl: photoUrl,
        active: widget.service?.active ?? true,
      );
      if (widget.service == null) {
        await repo.create(updated);
      } else {
        await repo.update(updated);
      }
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final service = widget.service!;
    final repo = context.read<ServiceRepository>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await AppDialog.confirm(
      context,
      title: 'Eliminar servicio',
      message:
          '¿Eliminar "${service.name}"? Las citas ya agendadas no se '
          'afectan. Si solo quieres dejar de ofrecerlo por un tiempo, '
          'ocúltalo en lugar de eliminarlo.',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Volver',
      destructive: true,
    );
    if (!ok) return;
    try {
      await repo.delete(widget.barbershopId, service.id);
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PhotoPickerField(
            picked: _photo,
            url: widget.service?.photoUrl,
            label: 'Añadir foto del servicio',
            onPicked: (photo) => setState(() => _photo = photo),
          ),
          const SizedBox(height: AppSpace.lg),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre del servicio',
              prefixIcon: Icon(Icons.content_cut),
            ),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: AppSpace.lg),
          TextFormField(
            controller: _description,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Precio (COP)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (value) {
                    final price = int.tryParse(value ?? '');
                    return (price == null || price <= 0) ? 'Mayor que 0' : null;
                  },
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: TextFormField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Minutos',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  validator: (value) {
                    final minutes = int.tryParse(value ?? '');
                    return (minutes == null || minutes < 5 || minutes > 480)
                        ? '5 a 480'
                        : null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          AppButton(
            onPressed: _saving ? null : _save,
            loading: _saving,
            icon: Icons.save_outlined,
            child: Text(
              widget.service == null ? 'Guardar servicio' : 'Guardar cambios',
            ),
          ),
          if (widget.service != null) ...[
            const SizedBox(height: AppSpace.sm),
            AppButton(
              variant: AppButtonVariant.text,
              onPressed: _saving ? null : _delete,
              child: Text(
                'Eliminar servicio',
                style: TextStyle(color: AppColors.readable(AppColors.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
