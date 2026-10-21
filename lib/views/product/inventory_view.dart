import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/stock_movement.dart';
import '../../repositories/inventory_repository.dart';
import '../../repositories/product_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../../utils/error_text.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/async_state_view.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive_body.dart';
import '../widgets/status_badge.dart';

/// Inventario de una barbería: cuántas unidades hay de cada producto, y la
/// bitácora de quién metió o sacó cuánto. Lo usan el dueño y los barberos de
/// la barbería; no permite cambiar precios (eso es del dueño en "Productos").
class InventoryView extends StatelessWidget {
  final String barbershopId;

  const InventoryView({super.key, required this.barbershopId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventario'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Existencias'),
              Tab(text: 'Movimientos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _StockTab(barbershopId: barbershopId),
            _MovementsTab(barbershopId: barbershopId),
          ],
        ),
      ),
    );
  }
}

class _StockTab extends StatelessWidget {
  final String barbershopId;

  const _StockTab({required this.barbershopId});

  @override
  Widget build(BuildContext context) {
    return AsyncStateView<List<Product>>(
      stream: context.read<ProductRepository>().watchByBarbershop(barbershopId),
      errorTitle: 'No pudimos cargar el inventario',
      empty: const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Aún no hay productos',
        subtitle:
            'Cuando el dueño agregue productos al catálogo, aquí llevarás '
            'cuántas unidades entran y salen.',
      ),
      builder: (context, products) => ResponsiveBody(
        maxWidth: AppLayout.formWidth,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          itemCount: products.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
          itemBuilder: (context, index) =>
              _StockCard(product: products[index], barbershopId: barbershopId),
        ),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final Product product;
  final String barbershopId;

  const _StockCard({required this.product, required this.barbershopId});

  Future<void> _register(BuildContext context, StockMovementType type) async {
    final done = await AppBottomSheet.show<bool>(
      context,
      title: '${type.label} de ${product.name}',
      child: StockMovementForm(
        barbershopId: barbershopId,
        product: product,
        type: type,
      ),
    );
    if (done == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type.label} registrada en el inventario.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stock = product.stock;
    final (label, color) = switch (stock) {
      null => ('Sin inventario', AppColors.textSecondary),
      0 => ('Agotado', AppColors.error),
      _ when product.isLowStock => ('Quedan pocas', AppColors.warning),
      _ => ('Disponible', AppColors.success),
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(product.name, style: text.titleSmall)),
              StatusBadge(label: label, color: color),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            stock == null
                ? 'Registra una entrada para empezar a llevar el inventario.'
                : '$stock ${stock == 1 ? 'unidad' : 'unidades'}',
            style: stock == null ? text.bodySmall : text.headlineSmall,
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.secondary,
                  icon: Icons.add,
                  onPressed: () =>
                      _register(context, StockMovementType.inbound),
                  child: const Text('Entrada'),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.secondary,
                  icon: Icons.remove,
                  onPressed: stock == null || stock == 0
                      ? null
                      : () => _register(context, StockMovementType.outbound),
                  child: const Text('Salida'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Formulario de una entrada o salida: cantidad, motivo y nota opcional.
class StockMovementForm extends StatefulWidget {
  final String barbershopId;
  final Product product;
  final StockMovementType type;

  const StockMovementForm({
    super.key,
    required this.barbershopId,
    required this.product,
    required this.type,
  });

  @override
  State<StockMovementForm> createState() => _StockMovementFormState();
}

class _StockMovementFormState extends State<StockMovementForm> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  late StockReason _reason = StockReason.selectable(widget.type).first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = context.read<InventoryRepository>();
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await repo.registerMovement(
        barbershopId: widget.barbershopId,
        productId: widget.product.id,
        type: widget.type,
        quantity: int.parse(_quantity.text.trim()),
        reason: _reason,
        note: _note.text,
      );
      navigator.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stock = widget.product.stock;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stock == null
                ? 'Todavía no se lleva inventario de este producto.'
                : 'Ahora hay $stock ${stock == 1 ? 'unidad' : 'unidades'}.',
            style: text.secondary,
          ),
          const SizedBox(height: AppSpace.lg),
          TextFormField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              prefixIcon: Icon(Icons.numbers),
            ),
            validator: (value) {
              final quantity = int.tryParse(value ?? '');
              if (quantity == null || quantity <= 0) return 'Mayor que 0';
              if (quantity > 10000) return 'Máximo 10000';
              if (widget.type == StockMovementType.outbound &&
                  stock != null &&
                  quantity > stock) {
                return 'Solo hay $stock';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpace.lg),
          Text('Motivo', style: text.labelMedium),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final reason in StockReason.selectable(widget.type))
                ChoiceChip(
                  label: Text(reason.label),
                  selected: _reason == reason,
                  onSelected: (_) => setState(() => _reason = reason),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          TextFormField(
            controller: _note,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Nota (opcional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              _error!,
              style: text.bodySmall?.copyWith(
                color: AppColors.readable(AppColors.error),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          AppButton(
            onPressed: _saving ? null : _save,
            loading: _saving,
            icon: Icons.check,
            child: Text('Registrar ${widget.type.label.toLowerCase()}'),
          ),
        ],
      ),
    );
  }
}

class _MovementsTab extends StatelessWidget {
  final String barbershopId;

  const _MovementsTab({required this.barbershopId});

  @override
  Widget build(BuildContext context) {
    return AsyncStateView<List<StockMovement>>(
      stream: context.read<InventoryRepository>().watchMovements(barbershopId),
      errorTitle: 'No pudimos cargar los movimientos',
      empty: const EmptyState(
        icon: Icons.swap_vert,
        title: 'Aún no hay movimientos',
        subtitle:
            'Cada entrada y salida de productos quedará anotada aquí con '
            'quién la hizo.',
      ),
      builder: (context, movements) => ResponsiveBody(
        maxWidth: AppLayout.formWidth,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          itemCount: movements.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
          itemBuilder: (context, index) =>
              _MovementTile(movement: movements[index]),
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final StockMovement movement;

  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final inbound = movement.type == StockMovementType.inbound;
    final color = inbound ? AppColors.success : AppColors.error;
    final created = movement.createdAt;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.tint(color),
              shape: BoxShape.circle,
            ),
            child: Icon(
              inbound ? Icons.south_west : Icons.north_east,
              color: AppColors.readable(color),
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movement.productName, style: text.titleSmall),
                Text(
                  '${movement.reason.label}'
                  '${movement.byUserName.isEmpty ? '' : ' · ${movement.byUserName}'}'
                  '${created == null ? '' : ' · ${dateTimeLabel(created)}'}',
                  style: text.bodySmall,
                ),
                if ((movement.note ?? '').isNotEmpty)
                  Text(movement.note!, style: text.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${inbound ? '+' : '-'}${movement.quantity}',
                style: text.titleSmall,
              ),
              Text('quedan ${movement.stockAfter}', style: text.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
