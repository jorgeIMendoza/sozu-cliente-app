import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:sozu_cliente_app/core/backend_env.dart';

import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';

/// Quién puede entrar al Portal del Cliente.
///
/// Dos caminos, no uno: el rol Cliente **o** ser comprador. El rol dice para qué
/// se contrató a la persona, no si compró; un agente, un abogado o alguien de
/// obra pueden ser clientes de SOZU.
///
/// El acceso administrador (impersonación) es otra cosa y va por permiso del rol
/// ([UserProfile.canManageClientApp]), no por aquí.
abstract final class PortalAccess {
  /// `roles.id` del rol Cliente en producción, el único ambiente contra el que
  /// se compila esta app.
  static const int _defaultClientRoleId = 23;

  /// Id del rol Cliente, con `CLIENTE_ROL_ID` del env como override.
  ///
  /// Getter, no `static final`: una constante perezosa leída antes de
  /// `dotenv.load()` cachearía el default para toda la vida del proceso.
  static int get clientRoleId =>
      (dotenv.isInitialized ? int.tryParse(backendClienteRolId) : null) ??
      _defaultClientRoleId;

  /// ¿Este perfil puede entrar al portal?
  ///
  /// El mismo criterio lo aplica `authClient()` en las Edge Functions. Si los dos
  /// dejan de coincidir el usuario entra y recibe 403 en cada pantalla, así que
  /// se cambian juntos.
  static bool allows(UserProfile? p) {
    if (p == null) return false;
    return _hasClientRole(p) || p.isBuyer;
  }

  /// Por [UserProfile.roleId]; cae al nombre normalizado solo mientras el
  /// backend no devuelva `rol_id`.
  static bool _hasClientRole(UserProfile p) {
    final roleId = p.roleId;
    if (roleId != null) return roleId == clientRoleId;
    return (p.roleName ?? '').trim().toLowerCase() == 'cliente';
  }
}
