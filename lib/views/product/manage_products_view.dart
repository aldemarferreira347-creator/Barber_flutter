import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../theme/app_tokens.dart';
import '../widgets/catalog_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/responsive_body.dart';
import '../widgets/shimmer_box.dart';
import 'buy_product_view.dart';
import 'product_form_sheet.dart';

/// Catálogo de productos de una barbería. Con [canManage] (dueño) se agregan,
/// editan, eliminan y ocultan; sin él (cliente) solo se ven los activos y se
/// pueden comprar.
class ManageProductsView extends StatelessWidget {
  final String barbershopId;
  final bool canManage;

  const ManageProductsView({
    super.key,
    required this.barbershopId,
    this.canManage = false,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ProductRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () =>
                  showProductForm(context, barbershopId: barbershopId),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo producto'),
            )
          : null,
      body: StreamBuilder<List<Product>>(
        stream: repo.watchByBarbershop(barbershopId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: ErrorState(title: 'No pudimos cargar los productos'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: ShimmerList(),
            );
          }
          final products = [
            for (final p in snapshot.data ?? const <Product>[])
              if (canManage || p.active) p,
          ];
          if (products.isEmpty) {
            return Center(
              child: EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'Sin productos todavía',
                subtitle: canManage
                    ? 'Añade ceras, tintes u otros productos con precio y foto.'
                    : 'Esta barbería aún no publicó productos.',
                actionLabel: canManage ? 'Nuevo producto' : null,
                onAction: canManage
                    ? () => showProductForm(context, barbershopId: barbershopId)
                    : null,
              ),
            );
          }
          return ResponsiveBody(
            maxWidth: AppLayout.formWidth,
            child: ListView.separated(
              padding: EdgeInsets.only(
                top: AppSpace.lg,
                bottom: canManage ? 96 : AppSpace.xl,
              ),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
              itemBuilder: (context, index) {
                final product = products[index];
                return CatalogTile(
                  name: product.name,
                  detail: product.description,
                  priceLabel: formatCop(product.price),
                  photoUrl: product.photoUrl,
                  fallbackIcon: Icons.shopping_bag_outlined,
                  active: product.active,
                  onActiveChanged: canManage
                      ? (value) =>
                            repo.setActive(barbershopId, product.id, value)
                      : null,
                  onTap: canManage
                      ? () => showProductForm(
                          context,
                          barbershopId: barbershopId,
                          product: product,
                        )
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BuyProductView(product: product),
                          ),
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
