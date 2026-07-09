import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../firebase_options.dart';

/// Push (FCM) — solo móvil. Web queda fuera: ahí vive la campana in-app.
///
/// Tolerante a falta de configuración: si `firebase_options.dart` sigue siendo
/// el placeholder (o Firebase falla por cualquier motivo), el servicio queda
/// desactivado en silencio y la app funciona igual.
class PushService {
  PushService._();

  static bool _firebaseListo = false;
  static bool _tokenRegistrado = false;
  static String? _ultimoToken;

  static bool get soportado => !kIsWeb;

  /// Inicializa Firebase una sola vez. Falso si no hay configuración.
  static Future<bool> _ensureFirebase() async {
    if (_firebaseListo) return true;
    if (!soportado) return false;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseListo = true;
      return true;
    } catch (e) {
      debugPrint('Push desactivado (Firebase sin configurar): $e');
      return false;
    }
  }

  /// Pide permiso, obtiene el token FCM y lo registra en el backend.
  /// Llamar cuando hay sesión de un Cliente real (no admin, no web).
  static Future<void> registrarDispositivo() async {
    if (_tokenRegistrado) return;
    if (!await _ensureFirebase()) return;
    try {
      final fcm = FirebaseMessaging.instance;
      final permiso = await fcm.requestPermission();
      if (permiso.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await fcm.getToken();
      if (token == null) return;
      await registrarPushToken(token, _plataforma());
      _ultimoToken = token;
      _tokenRegistrado = true;

      fcm.onTokenRefresh.listen((nuevo) async {
        try {
          await registrarPushToken(nuevo, _plataforma());
          _ultimoToken = nuevo;
        } catch (_) {/* reintenta en el próximo arranque */}
      });
    } catch (e) {
      debugPrint('Push: no se pudo registrar el dispositivo: $e');
    }
  }

  /// Da de baja el token al cerrar sesión (el dispositivo deja de recibir).
  static Future<void> desactivarDispositivo() async {
    final token = _ultimoToken;
    _tokenRegistrado = false;
    if (token == null) return;
    try {
      await eliminarPushToken(token);
    } catch (_) {/* best-effort */}
  }

  /// Mensajes con la app abierta (FCM no muestra notificación del sistema
  /// en foreground): el caller refresca la campana in-app.
  static void onForegroundMessage(void Function(RemoteMessage) handler) {
    if (!_firebaseListo) return;
    FirebaseMessaging.onMessage.listen(handler);
  }

  /// Tap en una notificación (app en background o cerrada).
  static Future<void> onNotificationTap(
    void Function(RemoteMessage) handler,
  ) async {
    if (!_firebaseListo) return;
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) handler(initial);
  }

  static String _plataforma() {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : 'android';
  }
}
