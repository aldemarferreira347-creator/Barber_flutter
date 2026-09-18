import 'package:cloud_functions/cloud_functions.dart';

import '../repositories/shop_closure_repository.dart';

class CloudShopClosureService implements ShopClosureRepository {
  final FirebaseFunctions _functions;

  CloudShopClosureService({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<int> closeForExternalEvent({
    required String barbershopId,
    required DateTime closedFrom,
    required DateTime closedUntil,
    required String reason,
  }) async {
    final result = await _functions.httpsCallable('closeShopForExternalEvent').call<Map<String, dynamic>>({
      'barbershopId': barbershopId,
      'closedFrom': closedFrom.toIso8601String(),
      'closedUntil': closedUntil.toIso8601String(),
      'reason': reason,
    });
    return (result.data['appointmentsAffected'] as num).toInt();
  }
}
