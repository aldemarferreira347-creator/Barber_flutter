import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../utils/shop_hours.dart';
import '../widgets/adaptive_card_list.dart';
import '../widgets/app_card.dart';
import '../widgets/app_network_image.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_box.dart';
import 'barbershop_detail_view.dart';

enum _CatalogFilter { all, openNow, topRated }

/// Catálogo del cliente (spec 12.1/12.6): solo barberías aprobadas y activas.
/// Se puede buscar por nombre o dirección, filtrar por las que están abiertas
/// ahora y ordenar por valoración.
class BarbershopCatalogView extends StatefulWidget {
  const BarbershopCatalogView({super.key});

  @override
  State<BarbershopCatalogView> createState() => _BarbershopCatalogViewState();
}

class _BarbershopCatalogViewState extends State<BarbershopCatalogView> {
  String _query = '';
  _CatalogFilter _filter = _CatalogFilter.all;

  static String _label(_CatalogFilter f) => switch (f) {
    _CatalogFilter.all => 'Todas',
    _CatalogFilter.openNow => 'Abiertas ahora',
    _CatalogFilter.topRated => 'Mejor valoradas',
  };

  List<Barbershop> _apply(List<Barbershop> shops) {
    var result = shops.where((s) {
      if (_query.isEmpty) return true;
      return s.name.toLowerCase().contains(_query) ||
          (s.address ?? '').toLowerCase().contains(_query);
    }).toList();
    if (_filter == _CatalogFilter.openNow) {
      result = result.where((s) => shopOpenStatus(s.schedule).isOpen).toList();
    }
    result.sort((a, b) {
      if (_filter == _CatalogFilter.topRated) {
        final byRating = b.averageRating.compareTo(a.averageRating);
        if (byRating != 0) return byRating;
      }
      return a.name.compareTo(b.name);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<BarbershopRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Barberías')),
      body: AdaptiveListBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpace.sm),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o dirección',
                prefixIcon: Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final filter in _CatalogFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpace.sm),
                      child: ChoiceChip(
                        label: Text(_label(filter)),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Expanded(
              child: StreamBuilder<List<Barbershop>>(
                stream: repo.watchApproved(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const ErrorState(
                      title: 'No pudimos cargar las barberías',
                      subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ShimmerList(itemHeight: 200);
                  }
                  final all = snapshot.data ?? const <Barbershop>[];
                  final shops = _apply(all);
                  if (shops.isEmpty) {
                    return EmptyState(
                      icon: Icons.storefront_outlined,
                      title: all.isEmpty
                          ? 'Aún no hay barberías'
                          : 'No encontramos barberías',
                      subtitle: all.isEmpty
                          ? 'Cuando se registre una barbería aparecerá aquí.'
                          : 'Prueba con otra búsqueda o quita los filtros.',
                    );
                  }
                  return AdaptiveCardList(
                    itemCount: shops.length,
                    itemBuilder: (context, index) =>
                        _ShopCard(shop: shops[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final Barbershop shop;

  const _ShopCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = shopOpenStatus(shop.schedule);
    final statusColor = status.isOpen ? AppColors.success : AppColors.warning;
    final url = shop.photoUrl;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BarbershopDetailView(barbershopId: shop.id),
        ),
      ),
      semanticLabel: '${shop.name}, ${status.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 132,
            child: url != null && url.isNotEmpty
                ? AppNetworkImage(
                    url: url,
                    semanticLabel: 'Foto de ${shop.name}',
                    width: double.infinity,
                    height: 132,
                    decodeWidth: 480,
                  )
                : Container(
                    color: AppColors.surfaceRaised,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.storefront_outlined,
                      size: 40,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                    ),
                    if (shop.averageRating > 0) ...[
                      const Icon(Icons.star, size: 16, color: AppColors.gold),
                      const SizedBox(width: 2),
                      Text(
                        shop.averageRating.toStringAsFixed(1),
                        style: text.labelMedium,
                      ),
                    ],
                  ],
                ),
                if (shop.address != null && shop.address!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    shop.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.secondary,
                  ),
                ],
                const SizedBox(height: AppSpace.sm),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        status.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelMedium?.copyWith(
                          color: AppColors.readable(statusColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
