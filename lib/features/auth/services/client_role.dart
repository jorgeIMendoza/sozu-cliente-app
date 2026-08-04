import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';

/// Gate del rol de usuario final del app (Cliente). Decide quién entra al
/// portal; el acceso administrador va por permiso, no por aquí.
abstract final class ClientRole {
  /// `roles.id` del rol Cliente en producción, el único ambiente contra el que
  /// se compila esta app.
  static const int _defaultId = 23;

  /// Id del rol Cliente, con `CLIENTE_ROL_ID` del env como override.
  ///
  /// Getter, no `static final`: una constante perezosa leída antes de
  /// `dotenv.load()` cachearía el default para toda la vida del proceso.
  static int get id =>
      (dotenv.isInitialized
          ? int.tryParse(dotenv.env['CLIENTE_ROL_ID'] ?? '')
          : null) ??
      _defaultId;

  /// ¿El perfil es un usuario final del app? Por [UserProfile.roleId]; cae al
  /// nombre normalizado solo mientras el backend no devuelva `rol_id`.
  static bool matches(UserProfile? p) {
    if (p == null) return false;
    final roleId = p.roleId;
    if (roleId != null) return roleId == id;
    return (p.roleName ?? '').trim().toLowerCase() == 'cliente';
  }
}
