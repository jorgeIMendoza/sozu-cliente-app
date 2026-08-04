import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/features/auth/services/portal_access.dart';

/// Contrato de quién entra al Portal del Cliente.
///
/// El mismo criterio corre en `_shared/cliente.ts` (`authClient`). Si divergen,
/// el usuario pasa el login y recibe 403 en cada pantalla, así que este archivo
/// es el espejo del gate del backend.
void main() {
  UserProfile perfil({int? roleId, String? roleName, bool isBuyer = false}) =>
      UserProfile(roleId: roleId, roleName: roleName, isBuyer: isBuyer);

  group('camino 1: rol Cliente', () {
    test('el rol Cliente entra aunque no sea comprador', () {
      expect(PortalAccess.allows(perfil(roleId: 23)), isTrue);
    });

    test('un cliente sin fila en compradores sigue entrando', () {
      // Existe exactamente uno en produccion; es la razon de conservar el rol
      // como camino alterno en vez de gatear solo por compradores.
      expect(PortalAccess.allows(perfil(roleId: 23, isBuyer: false)), isTrue);
    });
  });

  group('camino 2: comprador', () {
    test('un interno comprador entra (rol Agente Inmobiliario = 3)', () {
      expect(PortalAccess.allows(perfil(roleId: 3, isBuyer: true)), isTrue);
    });

    test('un interno que NO es comprador queda fuera', () {
      expect(PortalAccess.allows(perfil(roleId: 3, isBuyer: false)), isFalse);
    });
  });

  group('bordes', () {
    test('sin perfil no hay acceso', () {
      expect(PortalAccess.allows(null), isFalse);
    });

    test('sin rol_id cae al nombre del rol, normalizado', () {
      expect(PortalAccess.allows(perfil(roleName: 'Cliente')), isTrue);
      expect(PortalAccess.allows(perfil(roleName: '  cliente ')), isTrue);
      expect(PortalAccess.allows(perfil(roleName: 'Agente')), isFalse);
      expect(PortalAccess.allows(perfil(roleName: null)), isFalse);
    });

    test('con rol_id presente el nombre ya NO decide', () {
      // Un backend que mande rol_id manda; el nombre es solo la transicion.
      expect(
        PortalAccess.allows(perfil(roleId: 3, roleName: 'Cliente')),
        isFalse,
      );
    });

    test('isBuyer default false: sin es_comprador el gate es el de antes', () {
      // Tolerar el paso intermedio del despliegue: mientras el RPC no traiga la
      // columna, el acceso queda exactamente como estaba (solo rol Cliente).
      expect(PortalAccess.allows(const UserProfile(roleId: 3)), isFalse);
      expect(PortalAccess.allows(const UserProfile(roleId: 23)), isTrue);
    });

    test('clientRoleId default 23 sin env cargado', () {
      expect(PortalAccess.clientRoleId, 23);
    });
  });
}
