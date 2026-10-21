import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/app_user.dart';
import '../../models/appointment.dart';
import '../../models/barbershop.dart';
import '../../models/product.dart';
import '../../models/shop_closure.dart';
import '../../models/service.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/purchase_repository.dart';
import '../../repositories/service_repository.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../../utils/shop_hours.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/choice_tile.dart';
import '../widgets/day_time_picker.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/nequi_payment_sheet.dart';
import '../widgets/responsive_body.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_box.dart';
import '../../utils/error_text.dart';

/// Reserva de una cita: servicio, barbero, día y hora (solo horas dentro del
/// horario de la barbería) y forma de reserva. Pagar por Nequi bloquea el
/// horario de inmediato; la barbería confirma después que recibió el dinero.
class BookAppointmentView extends StatefulWidget {
  final String barbershopId;
  final String barbershopName;

  const BookAppointmentView({
    super.key,
    required this.barbershopId,
    required this.barbershopName,
  });

  @override
  State<BookAppointmentView> createState() => _BookAppointmentViewState();
}

class _BookAppointmentViewState extends State<BookAppointmentView> {
  /// Días que se pueden reservar hacia adelante.

  // Los streams se abren una sola vez: crearlos dentro de build() reabriría
  // la consulta (y mostraría el esqueleto de carga) con cada selección.
  late final Stream<Barbershop?> _shop = context
      .read<BarbershopRepository>()
      .watchOne(widget.barbershopId);
  late final Stream<List<Service>> _services = context
      .read<ServiceRepository>()
      .watchByBarbershop(widget.barbershopId);
  late final Stream<List<AppUser>> _barbers = context
      .read<UserRepository>()
      .watchBarbersByBarbershop(widget.barbershopId);

  late final Stream<List<Product>> _products = context
      .read<ProductRepository>()
      .watchByBarbershop(widget.barbershopId);

  /// "Fuera de la tienda · vuelve ~10:30" mientras el barbero esté fuera.
  String? _awayLabel(AppUser barber) {
    final until = barber.awayUntilEstimate;
    if (until == null || !until.isAfter(DateTime.now())) return null;
    return 'Fuera de la tienda · vuelve ~${timeLabel(until)}';
  }

  /// Máximo de unidades de un mismo producto por reserva.
  static const _maxPerProduct = 5;

  /// Máximo de productos distintos por compra (lo exigen las reglas).
  static const _maxDistinctProducts = 5;

  Service? _service;
  AppUser? _barber;
  DateTime? _day;
  DateTime? _dateTime;
  bool _payNow = false;
  bool _saving = false;

  /// Último dato de la barbería, para calcular las horas sin esperar al
  /// `StreamBuilder`.
  Barbershop? _shopData;

  /// Productos activos de la barbería (último dato recibido).
  List<Product> _catalog = const [];

  /// Respuestas ya conocidas de "¿está tomada esta hora?" por barbero y hora:
  /// cambiar de servicio o volver a un día ya visto no repite lecturas.
  final Map<String, bool> _slotCache = {};

  /// Horas del barbero elegido que una reserva pagada ya bloqueó.
  Set<DateTime> _taken = {};
  bool _loadingTaken = false;
  int _takenRequest = 0;

  /// Productos que el cliente quiere junto a su cita: id -> unidades.
  final Map<String, int> _cart = {};

  void _pickService(Service service) {
    setState(() {
      _service = service;
      // La duración cambia qué horas caben: se vuelve a elegir la hora.
      _dateTime = null;
    });
    _loadTaken();
  }

  void _pickDay(DateTime day) {
    setState(() {
      _day = day;
      _dateTime = null;
    });
    _loadTaken();
  }

  void _pickBarber(AppUser barber) {
    setState(() {
      _barber = barber;
      _dateTime = null;
    });
    _loadTaken();
  }

  /// Consulta qué horas del día elegido ya tiene tomadas el barbero, para
  /// mostrarlas ocupadas en vez de dejar que falle al confirmar.
  Future<void> _loadTaken() async {
    final shop = _shopData;
    final barber = _barber;
    final day = _day;
    final service = _service;
    final request = ++_takenRequest;
    if (shop == null || barber == null || day == null || service == null) {
      if (_taken.isNotEmpty) setState(() => _taken = {});
      return;
    }
    setState(() => _loadingTaken = true);
    final slots = availableSlotsForShop(
      shop,
      day: day,
      durationMinutes: service.durationMinutes,
    );
    String keyOf(DateTime slot) => '${barber.uid}|${slot.toIso8601String()}';
    final unknown = [
      for (final slot in slots)
        if (!_slotCache.containsKey(keyOf(slot))) slot,
    ];
    if (unknown.isNotEmpty) {
      final known = await context.read<AppointmentRepository>().takenSlots(
        barberId: barber.uid,
        slots: unknown,
      );
      for (final slot in unknown) {
        _slotCache[keyOf(slot)] = known.contains(slot);
      }
    }
    if (!mounted || request != _takenRequest) return;
    final taken = {
      for (final slot in slots)
        if (_slotCache[keyOf(slot)] == true) slot,
    };
    setState(() {
      _taken = taken;
      _loadingTaken = false;
      if (_dateTime != null && taken.contains(_dateTime)) _dateTime = null;
    });
  }

  void _setQuantity(Product product, int quantity) => setState(() {
    if (quantity <= 0) {
      _cart.remove(product.id);
    } else {
      _cart[product.id] = quantity;
    }
  });

  /// Productos del carrito con su cantidad, solo los que siguen existiendo.
  List<({Product product, int quantity})> _cartLines(List<Product> catalog) => [
    for (final product in catalog)
      if ((_cart[product.id] ?? 0) > 0)
        (product: product, quantity: _cart[product.id]!),
  ];

  Future<void> _confirm(Barbershop shop) async {
    final profile = context.read<AuthController>().profile;
    final service = _service;
    final barber = _barber;
    final dateTime = _dateTime;
    if (profile == null ||
        service == null ||
        barber == null ||
        dateTime == null) {
      return;
    }

    final payNow = _payNow && shop.acceptsNequi;
    String? reference;
    if (payNow) {
      reference = await showNequiPaymentSheet(
        context,
        title: 'Pagar con Nequi',
        amount: service.price,
        payeeName: shop.name,
        payeePhone: shop.nequiPhone!,
      );
      if (reference == null || !mounted) return;
    }

    setState(() => _saving = true);
    String appointmentId;
    try {
      final repo = context.read<AppointmentRepository>();
      if (payNow) {
        // Reserva pagada (spec 6.1/6.2): el horario se bloquea en una
        // transacción y el pago queda en verificación. Si alguien más ya lo
        // tomó, falla con un error claro en vez de crear la cita.
        appointmentId = await repo.createPaid(
          barbershopId: widget.barbershopId,
          barberId: barber.uid,
          barberName: barber.name,
          serviceId: service.id,
          clientName: profile.name,
          date: dateTime,
          reference: reference!,
        );
      } else {
        appointmentId = await repo.create(
          Appointment(
            id: '',
            barbershopId: widget.barbershopId,
            barberId: barber.uid,
            barberName: barber.name,
            clientId: profile.uid,
            clientName: profile.name,
            serviceId: service.id,
            serviceName: service.name,
            servicePrice: service.price,
            durationMinutes: service.durationMinutes,
            date: dateTime,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo agendar: ${errorText(e)}')),
        );
        setState(() => _saving = false);
        // Quizá alguien tomó esa hora: se vuelven a consultar las ocupadas.
        _slotCache.clear();
        unawaited(_loadTaken());
      }
      return;
    }
    if (!mounted) return;

    // La cita ya quedó creada. Los productos se pagan aparte (cada compra
    // tiene su propio pago Nequi y su código de reclamo); si algo falla aquí
    // la cita NO se pierde y el cliente puede comprarlos después.
    final productsResult = await _buyProducts(shop, appointmentId);
    if (!mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${payNow ? 'Horario reservado. ${shop.name} confirmará tu pago en breve.' : 'Cita solicitada. El barbero debe confirmarla.'}'
          '${productsResult == null ? '' : ' $productsResult'}',
        ),
      ),
    );
  }

  /// Compra los productos elegidos vinculándolos a [appointmentId]. Devuelve
  /// una frase para el aviso final, o null si no había productos.
  Future<String?> _buyProducts(Barbershop shop, String appointmentId) async {
    final lines = _cartLines(_catalog);
    if (lines.isEmpty) return null;
    final total = lines.fold<double>(
      0,
      (sum, line) => sum + line.product.price * line.quantity,
    );
    final reference = await showNequiPaymentSheet(
      context,
      title: 'Pagar productos con Nequi',
      amount: total,
      payeeName: shop.name,
      payeePhone: shop.nequiPhone!,
    );
    if (reference == null || !mounted) {
      return 'Tus productos quedaron sin comprar: puedes pedirlos después '
          'desde la barbería.';
    }
    try {
      await context.read<PurchaseRepository>().createPurchase(
        barbershopId: widget.barbershopId,
        items: [
          for (final line in lines)
            PurchaseItemInput(
              productId: line.product.id,
              quantity: line.quantity,
            ),
        ],
        reference: reference,
        appointmentId: appointmentId,
      );
      return 'Tus productos se reclaman con un código en "Mis compras".';
    } catch (e) {
      return 'No se pudieron comprar los productos (${errorText(e)}). Tu '
          'cita sí quedó agendada.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Agendar en ${widget.barbershopName}')),
      body: StreamBuilder<Barbershop?>(
        stream: _shop,
        builder: (context, shopSnapshot) {
          if (shopSnapshot.hasError) {
            return Center(
              child: ErrorState(
                title: 'No pudimos cargar la barbería',
                error: shopSnapshot.error,
              ),
            );
          }
          final shop = shopSnapshot.data;
          _shopData = shop;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
            children: [
              ResponsiveBody(
                maxWidth: AppLayout.formWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (shop?.relevantClosure() != null)
                      _ClosureNotice(closure: shop!.relevantClosure()!),
                    const SectionHeader(title: '1. Elige un servicio'),
                    StreamBuilder<List<Service>>(
                      stream: _services,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return ErrorState(
                            title: 'No pudimos cargar los servicios',
                            error: snapshot.error,
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ShimmerList(count: 2, itemHeight: 58);
                        }
                        final services = (snapshot.data ?? [])
                            .where((s) => s.active)
                            .toList();
                        if (services.isEmpty) {
                          return const EmptyState(
                            icon: Icons.content_cut,
                            title: 'Sin servicios disponibles',
                            subtitle:
                                'Esta barbería todavía no publicó servicios.',
                          );
                        }
                        return Column(
                          children: [
                            for (final service in services)
                              ChoiceTile(
                                selected: _service?.id == service.id,
                                title: service.name,
                                subtitle: '${service.durationMinutes} min',
                                trailing: Text(
                                  formatCop(service.price),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                onTap: () => _pickService(service),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpace.xl),
                    const SectionHeader(title: '2. Elige un barbero'),
                    StreamBuilder<List<AppUser>>(
                      stream: _barbers,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return ErrorState(
                            title: 'No pudimos cargar los barberos',
                            error: snapshot.error,
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ShimmerList(count: 2, itemHeight: 58);
                        }
                        final barbers = (snapshot.data ?? [])
                            .where((b) => b.available)
                            .toList();
                        if (barbers.isEmpty) {
                          return const EmptyState(
                            icon: Icons.person_outline,
                            title: 'Sin barberos disponibles',
                            subtitle: 'Esta barbería todavía no tiene barberos activos.',
                          );
                        }
                        return Column(
                          children: [
                            for (final barber in barbers)
                              ChoiceTile(
                                selected: _barber?.uid == barber.uid,
                                title: barber.name,
                                subtitle: _awayLabel(barber),
                                onTap: () => _pickBarber(barber),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpace.xl),
                    const SectionHeader(title: '3. Elige día y hora'),
                    if (shop == null)
                      const ShimmerList(count: 1, itemHeight: 58)
                    else
                      DayAndTimePicker(
                        shop: shop,
                        durationMinutes: _service?.durationMinutes,
                        day: _day,
                        dateTime: _dateTime,
                        disabledSlots: _taken,
                        loading: _loadingTaken,
                        onDay: _pickDay,
                        onTime: (time) => setState(() => _dateTime = time),
                      ),
                    const SizedBox(height: AppSpace.xl),
                    _ProductsStep(
                      stream: _products,
                      acceptsNequi: shop?.acceptsNequi ?? false,
                      cart: _cart,
                      maxPerProduct: _maxPerProduct,
                      maxDistinct: _maxDistinctProducts,
                      onCatalog: (catalog) => _catalog = catalog,
                      onQuantity: _setQuantity,
                    ),
                    const SectionHeader(title: '5. ¿Cómo quieres reservar?'),
                    ChoiceTile(
                      selected: !_payNow || !(shop?.acceptsNequi ?? false),
                      title: 'Pagar en la barbería',
                      subtitle: 'Solicitas la cita; no bloquea el horario hasta que el barbero la acepte.',
                      onTap: () => setState(() => _payNow = false),
                    ),
                    ChoiceTile(
                      selected: _payNow && (shop?.acceptsNequi ?? false),
                      enabled: shop?.acceptsNequi ?? false,
                      title: 'Pagar ahora con Nequi',
                      subtitle: (shop?.acceptsNequi ?? false)
                          ? 'Bloquea el horario de inmediato: nadie más podrá tomarlo.'
                          : 'Esta barbería aún no recibe pagos por Nequi.',
                      onTap: () => setState(() => _payNow = true),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    if (_service != null &&
                        _barber != null &&
                        _dateTime != null)
                      _Summary(
                        service: _service!,
                        barber: _barber!,
                        dateTime: _dateTime!,
                        payNow: _payNow && (shop?.acceptsNequi ?? false),
                        products: _cartLines(_catalog),
                      ),
                    const SizedBox(height: AppSpace.lg),
                    AppButton(
                      onPressed:
                          (shop != null &&
                              _service != null &&
                              _barber != null &&
                              _dateTime != null)
                          ? () => _confirm(shop)
                          : null,
                      icon: (_payNow && (shop?.acceptsNequi ?? false))
                          ? Icons.lock_outline
                          : Icons.event_available,
                      loading: _saving,
                      child: Text(
                        (_payNow && (shop?.acceptsNequi ?? false))
                            ? 'Reservar y pagar'
                            : 'Solicitar cita',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final Service service;
  final AppUser barber;
  final DateTime dateTime;
  final bool payNow;
  final List<({Product product, int quantity})> products;

  const _Summary({
    required this.service,
    required this.barber,
    required this.dateTime,
    required this.payNow,
    this.products = const [],
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final productsTotal = products.fold<double>(
      0,
      (sum, line) => sum + line.product.price * line.quantity,
    );
    return AppCard(
      color: AppColors.surfaceRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen', style: text.titleSmall),
          const SizedBox(height: AppSpace.sm),
          Text('${service.name} · ${service.durationMinutes} min'),
          Text('Con ${barber.name}'),
          Text(dateTimeLabel(dateTime)),
          const Divider(height: AppSpace.xl),
          _SummaryRow(
            label: payNow ? 'Cita (Nequi)' : 'Cita (en la barbería)',
            amount: service.price,
          ),
          for (final line in products)
            _SummaryRow(
              label: '${line.quantity} x ${line.product.name}',
              amount: line.product.price * line.quantity,
            ),
          if (products.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              'Los productos se pagan por Nequi aparte de la cita y se '
              'reclaman con un código en la barbería.',
              style: text.bodySmall,
            ),
          ],
          const Divider(height: AppSpace.xl),
          _SummaryRow(
            label: 'Total',
            amount: service.price + productsTotal,
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool strong;

  const _SummaryRow({
    required this.label,
    required this.amount,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: strong ? text.titleSmall : text.secondary,
            ),
          ),
          Text(
            formatCop(amount),
            style: strong ? text.titleMedium : text.titleSmall,
          ),
        ],
      ),
    );
  }
}

/// Paso opcional de la reserva: productos de la barbería para llevarse junto
/// con la cita. Si la barbería no tiene productos el paso no aparece (no es
/// un error); si no cobra por Nequi, se explica por qué no se pueden pedir.
class _ProductsStep extends StatelessWidget {
  final Stream<List<Product>> stream;
  final bool acceptsNequi;
  final Map<String, int> cart;
  final int maxPerProduct;
  final int maxDistinct;
  final ValueChanged<List<Product>> onCatalog;
  final void Function(Product product, int quantity) onQuantity;

  const _ProductsStep({
    required this.stream,
    required this.acceptsNequi,
    required this.cart,
    required this.maxPerProduct,
    required this.maxDistinct,
    required this.onCatalog,
    required this.onQuantity,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: stream,
      builder: (context, snapshot) {
        final products = [
          for (final product in snapshot.data ?? const <Product>[])
            if (product.active) product,
        ];
        onCatalog(products);
        // Sin productos (o sin poder leerlos) la reserva sigue sin este paso.
        if (products.isEmpty) return const SizedBox.shrink();
        final text = Theme.of(context).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: '4. Agrega productos (opcional)'),
            if (!acceptsNequi)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: Text(
                  'Esta barbería aún no recibe pagos por Nequi, así que los '
                  'productos se compran en el local.',
                  style: text.secondary,
                ),
              ),
            for (final product in products)
              _ProductPickRow(
                product: product,
                enabled: acceptsNequi && product.inStock,
                quantity: cart[product.id] ?? 0,
                maxQuantity: product.maxPurchasable(maxPerProduct),
                canAddNew:
                    cart.containsKey(product.id) || cart.length < maxDistinct,
                onChanged: (quantity) => onQuantity(product, quantity),
              ),
            const SizedBox(height: AppSpace.xl),
          ],
        );
      },
    );
  }
}

class _ProductPickRow extends StatelessWidget {
  final Product product;
  final bool enabled;
  final int quantity;
  final int maxQuantity;
  final bool canAddNew;
  final ValueChanged<int> onChanged;

  const _ProductPickRow({
    required this.product,
    required this.enabled,
    required this.quantity,
    required this.maxQuantity,
    required this.canAddNew,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stockNote = !product.inStock
        ? 'Agotado'
        : product.isLowStock
        ? 'Quedan ${product.stock}'
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: text.titleSmall),
                  Text(
                    stockNote == null
                        ? formatCop(product.price)
                        : '${formatCop(product.price)} · $stockNote',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            if (quantity > 0) ...[
              IconButton(
                tooltip: 'Quitar uno',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => onChanged(quantity - 1),
              ),
              Text('$quantity', style: text.titleSmall),
            ],
            IconButton(
              tooltip: 'Agregar ${product.name}',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: enabled && canAddNew && quantity < maxQuantity
                  ? () => onChanged(quantity + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso de que la barbería tiene un cierre vigente o programado: las horas
/// que caen dentro del cierre no se ofrecen.
class _ClosureNotice extends StatelessWidget {
  final ShopClosure closure;

  const _ClosureNotice({required this.closure});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: AppCard(
        color: AppColors.tint(AppColors.warning),
        borderColor: AppColors.warning.withValues(alpha: 0.4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.event_busy_outlined,
              color: AppColors.readable(AppColors.warning),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                closure.isIndefinite
                    ? 'Esta barbería está cerrada hasta nuevo aviso'
                          '${closure.reason.isEmpty ? '' : ' (${closure.reason})'}. '
                          'Podrás reservar cuando vuelva a abrir.'
                    : 'Esta barbería estará cerrada desde '
                          '${dateTimeLabel(closure.from)} hasta '
                          '${dateTimeLabel(closure.until!)}'
                          '${closure.reason.isEmpty ? '' : ' (${closure.reason})'}. '
                          'Esas horas no están disponibles.',
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
