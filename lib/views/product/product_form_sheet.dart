import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/photo_picker_field.dart';
import '../../utils/error_text.dart';

/// Crea o edita un producto en una hoja modal: nombre, descripción, precio y
/// foto. Con [product] edita ese producto y además ofrece eliminarlo.
/// Devuelve `true` si se guardó o eliminó algo.
Future<bool?> showProductForm(
  BuildContext context, {
  required String barbershopId,
  Product? product,
}) {
  return AppBottomSheet.show<bool>(
    context,
    title: product == null ? 'Nuevo producto' : 'Editar producto',
    child: _ProductForm(barbershopId: barbershopId, product: product),
  );
}

class _ProductForm extends StatefulWidget {
  final String barbershopId;
  final Product? product;

  const _ProductForm({required this.barbershopId, required this.product});

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _description = TextEditingController(
    text: widget.product?.description ?? '',
  );
  late final _price = TextEditingController(
    text: widget.product == null
        ? ''
        : widget.product!.price.round().toString(),
  );
  PickedPhoto? _photo;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = context.read<ProductRepository>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      var photoUrl = widget.product?.photoUrl;
      if (_photo != null) {
        photoUrl = await repo.uploadPhoto(
          barbershopId: widget.barbershopId,
          fileName: '${DateTime.now().millisecondsSinceEpoch}_${_photo!.name}',
          bytes: _photo!.bytes,
        );
      }
      final description = _description.text.trim();
      final updated = Product(
        id: widget.product?.id ?? '',
        barbershopId: widget.barbershopId,
        name: _name.text.trim(),
        description: description.isEmpty ? null : description,
        price: double.parse(_price.text.trim()),
        photoUrl: photoUrl,
        active: widget.product?.active ?? true,
      );
      if (widget.product == null) {
        await repo.create(updated);
      } else {
        await repo.update(updated);
      }
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo guardar: ${errorText(e)}')),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final product = widget.product!;
    final repo = context.read<ProductRepository>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await AppDialog.confirm(
      context,
      title: 'Eliminar producto',
      message:
          '¿Eliminar "${product.name}"? Las compras ya hechas no se '
          'afectan. Si solo se agotó, ocúltalo en lugar de eliminarlo.',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Volver',
      destructive: true,
    );
    if (!ok) return;
    try {
      await repo.delete(widget.barbershopId, product.id);
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: ${errorText(e)}')),
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
            url: widget.product?.photoUrl,
            label: 'Añadir foto del producto',
            onPicked: (photo) => setState(() => _photo = photo),
          ),
          const SizedBox(height: AppSpace.lg),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre del producto',
              prefixIcon: Icon(Icons.shopping_bag_outlined),
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
          TextFormField(
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
          const SizedBox(height: AppSpace.xl),
          AppButton(
            onPressed: _saving ? null : _save,
            loading: _saving,
            icon: Icons.save_outlined,
            child: Text(
              widget.product == null ? 'Guardar producto' : 'Guardar cambios',
            ),
          ),
          if (widget.product != null) ...[
            const SizedBox(height: AppSpace.sm),
            AppButton(
              variant: AppButtonVariant.text,
              onPressed: _saving ? null : _delete,
              child: Text(
                'Eliminar producto',
                style: TextStyle(color: AppColors.readable(AppColors.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
