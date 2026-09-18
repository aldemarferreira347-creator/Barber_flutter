import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../repositories/user_repository.dart';
import '../services/firestore_user_service.dart';

/// Mantiene el perfil del usuario autenticado sincronizado en vivo con
/// Firestore (p.ej. si el admin bloquea la cuenta, `active` cambia a false
/// mientras la app sigue abierta).
class UserController extends ChangeNotifier {
  final UserRepository _userService;

  UserController({UserRepository? userService}) : _userService = userService ?? FirestoreUserService();

  StreamSubscription<AppUser?>? _subscription;
  AppUser? profile;

  void watch(String uid) {
    _subscription?.cancel();
    _subscription = _userService.watchUserProfile(uid).listen((user) {
      profile = user;
      notifyListeners();
    });
  }

  void stopWatching() {
    _subscription?.cancel();
    _subscription = null;
    profile = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
