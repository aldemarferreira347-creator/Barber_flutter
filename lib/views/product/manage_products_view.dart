import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/shimmer_box.dart';
import 'add_product_view.dart';
import 'buy_product_view.dart';

/// Catálogo de productos de una barbería. [canManage] controla si se puede
/// agregar/activar-desactivar (Dueño) o solo se muestran (Cliente).
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
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddProductView(barbershopId: barbershopId),
                ),
              ),
              child: const Icon(Icons.add),
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
              padding: EdgeInsets.all(16),
              child: ShimmerList(),
            );
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'Sin productos todavía',
                subtitle:
                    'Añade ceras, tintes u otros productos con precio y foto.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              final onTap = canManage || !product.active
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BuyProductView(product: product),
                      ),
                    );
              return PressableScale(
                    onTap: onTap,
                    child: Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      elevation: 1,
                      shadowColor: AppColors.textPrimary.withValues(
                        alpha: 0.08,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onTap,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: product.photoUrl != null
                                    ? Image.network(
                                        product.photoUrl!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        semanticLabel:
                                            'Foto de ${product.name}',
                                      )
                                    : Container(
                                        width: 56,
                                        height: 56,
                                        color: AppColors.background,
                                        child: Icon(
                                          Icons.shopping_bag_outlined,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if ((product.description ?? '').isNotEmpty)
                                      Text(
                                        product.description!,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '\$${product.price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent,
                                ),
                              ),
                              if (canManage)
                                Switch(
                                  value: product.active,
                                  onChanged: (value) => repo.setActive(
                                    barbershopId,
                                    product.id,
                                    value,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .animate(delay: (index * 60).ms)
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
            },
          );
        },
      ),
    );
  }
}
