import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

// ignore: always_use_package_imports -- import condicional: la resolucion por plataforma exige ruta relativa.
import 'browser_ua_stub.dart'
    if (dart.library.js_interop) 'browser_ua_web.dart';
import 'package:sozu_cliente_app/core/version.dart';
import 'package:sozu_cliente_app/shared/ports/tracking_port.dart';

/// Mediciones de uso ("Uso por portal" en Alta Dirección): registra la sesión
/// del cliente en portal_sesiones (portal `clientes`). Las donas del tablero
/// clasifican el user_agent: en web se manda el real del navegador; en móvil
/// uno sintético con marca/modelo reales del dispositivo.
///
/// El puerto llega por parámetro y no por un provider leído aquí: es un
/// singleton estático y no tiene `ref`. Mismo reparto que [PushService].
class PortalTracking {
  PortalTracking._();

  static const _portal = 'clientes';
  static const _heartbeatCada = Duration(minutes: 5);

  static String? _sessionId;
  static Timer? _heartbeat;
  static bool _iniciando = false;

  /// Abre (o reutiliza) la sesión de medición. Llamar cuando hay sesión de un
  /// Cliente real (no impersonación de admin).
  static Future<void> iniciar(TrackingPort port) async {
    if (_sessionId != null || _iniciando) return;
    _iniciando = true;
    try {
      _sessionId = await port.register(
        portal: _portal,
        userAgent: await _userAgent(),
      );
      if (_sessionId == null) return;
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(_heartbeatCada, (_) => _touch(port));
    } finally {
      _iniciando = false;
    }
  }

  static Future<void> _touch(TrackingPort port) async {
    final id = _sessionId;
    if (id != null) await port.touch(id);
  }

  /// Cierra la sesión de medición. Llamar ANTES de signOut (necesita JWT).
  static Future<void> cerrar(TrackingPort port) async {
    final id = _sessionId;
    _heartbeat?.cancel();
    _heartbeat = null;
    _sessionId = null;
    if (id != null) await port.close(id);
  }

  /// UA para clasificar en las donas: real en web; sintético (pero con los
  /// tokens que el clasificador espera: Android/Mobile/modelo, iPhone) en app.
  static Future<String> _userAgent() async {
    final delNavegador = userAgentDelNavegador();
    if (delNavegador != null && delNavegador.isNotEmpty) return delNavegador;

    try {
      final plugin = DeviceInfoPlugin();
      if (!kIsWeb && Platform.isAndroid) {
        final a = await plugin.androidInfo;
        return 'Mozilla/5.0 (Linux; Android ${a.version.release}; '
            '${a.model}) Mobile SozuClienteApp/$appVersionBase';
      }
      if (!kIsWeb && Platform.isIOS) {
        final i = await plugin.iosInfo;
        return 'Mozilla/5.0 (iPhone; CPU iPhone OS '
            '${i.systemVersion.replaceAll('.', '_')} like Mac OS X) '
            'Mobile SozuClienteApp/$appVersionBase (${i.utsname.machine})';
      }
    } catch (_) {
      /* fallback genérico */
    }
    return 'SozuClienteApp/$appVersionBase Mobile';
  }
}
