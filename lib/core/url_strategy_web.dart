import 'package:flutter_web_plugins/url_strategy.dart';

/// Quita el `#` de las URLs en web: `/login` en vez de `/#/login`.
///
/// Requiere que el servidor devuelva `index.html` para cualquier ruta
/// desconocida, o al recargar en `/login` daría 404. Ya está cubierto:
/// firebase.json reescribe `**` → `/index.html`, y el servidor de desarrollo
/// de Flutter (`flutter run -d web-server`) hace el mismo fallback.
void usarUrlSinHash() => usePathUrlStrategy();
