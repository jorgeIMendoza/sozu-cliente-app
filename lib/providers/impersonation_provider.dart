import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente impersonado por un super administrador (solo web).
/// Estado in-memory: al recargar la página el guard regresa al selector.
/// Se limpia al cerrar sesión o cambiar de usuario para evitar que un target
/// residual afecte a otra sesión en la misma pestaña.
class ImpersonationController extends ChangeNotifier {
  StreamSubscription<AuthState>? _sub;
  String? _userId;

  int? idPersona;
  String? nombre;
  String? email;

  bool get active => idPersona != null;

  ImpersonationController() {
    _userId = Supabase.instance.client.auth.currentSession?.user.id;
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final nextId = data.session?.user.id;
      if (nextId != _userId) {
        _userId = nextId;
        if (active) clear();
      }
    });
  }

  void select(int id, String nombreCliente, String? emailCliente) {
    idPersona = id;
    nombre = nombreCliente;
    email = emailCliente;
    notifyListeners();
  }

  void clear() {
    idPersona = null;
    nombre = null;
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
  return ImpersonationController();
});
