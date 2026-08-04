import 'package:web/web.dart' as web;

/// Web: user agent real del navegador (las donas de "Uso por portal" lo
/// clasifican por tipo/SO/navegador/marca).
String? userAgentDelNavegador() => web.window.navigator.userAgent;
