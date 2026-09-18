import 'package:cloud_functions/cloud_functions.dart';

import '../repositories/barber_availability_repository.dart';

class CloudBarberAvailabilityService implements BarberAvailabilityRepository {
  final FirebaseFunctions _functions;

  CloudBarberAvailabilityService({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<void> markAway(int estimatedMinutes) {
    return _functions.httpsCallable('markBarberAway').call<void>({'estimatedMinutes': estimatedMinutes});
  }

  @override
  Future<void> markReturned() {
    return _functions.httpsCallable('markBarberReturned').call<void>();
  }
}
