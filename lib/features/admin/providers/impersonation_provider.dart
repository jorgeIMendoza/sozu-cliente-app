import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';

/// Cliente impersonado por un super administrador (solo web).
/// Estado in-memory: al recargar la página el guard regresa al selector.
/// Se limpia al cerrar sesión o cambiar de usuario para evitar que un target
/// residual afecte a otra sesión en la misma pestaña.
class ImpersonationController extends ChangeNotifier {
  StreamSubscription<AuthSession?>? _sub;
  String? _userId;

  int? clientId;
  String? clientName;
  String? email;

  bool get active => clientId != null;

  ImpersonationController(AuthPort port) {
    _userId = port.currentSession?.userId;
    _sub = port.sessionChanges.listen((session) {
      final nextId = session?.userId;
      if (nextId != _userId) {
        _userId = nextId;
        if (active) clear();
      }
    });
  }

  void select(int id, String name, String? email) {
    clientId = id;
    clientName = name;
    this.email = email;
    notifyListeners();
  }

  void clear() {
    clientId = null;
    clientName = null;
    email = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final impersonationProvider = ChangeNotifierProvider<ImpersonationController>((
  ref,
) {
  return ImpersonationController(ref.watch(authPortProvider));
});
