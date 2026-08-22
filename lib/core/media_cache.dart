import 'package:flutter/widgets.dart' show ImageProvider;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache en disco de imágenes y documentos (7 días). Compartida por SNetworkImage
/// y el visor de documentos.
///
/// Clave estable: las URLs firmadas de Supabase Storage caducan y llegan con un
/// `?token=...` distinto en cada fetch. Si se cacheara por la URL completa,
/// cada request sería un cache-miss. Se usa el path (sin query) como clave, que
/// sí es estable para el mismo archivo.
class SozuCacheManager {
  static const key = 'sozuMediaCache';

  static final CacheManager instance = CacheManager(
    Config(key, stalePeriod: const Duration(days: 7), maxNrOfCacheObjects: 300),
  );
}

/// Clave de cache estable derivada de una URL firmada (ignora el query string).
/// Ej. `.../object/sign/docs/contrato.pdf?token=abc` → `.../object/sign/docs/contrato.pdf`.
String cacheKeyFor(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  return '${uri.host}${uri.path}';
}

/// Extensión del archivo tomada del path (sin query), en minúsculas y sin punto.
/// Vacío si no hay extensión.
String fileExtensionOf(String url) {
  final uri = Uri.tryParse(url);
  final path = uri?.path ?? url;
  final dot = path.lastIndexOf('.');
  final slash = path.lastIndexOf('/');
  if (dot <= slash || dot == path.length - 1) return '';
  return path.substring(dot + 1).toLowerCase();
}

/// ImageProvider que reusa esta misma cache y su clave estable. Para widgets
/// que reciben un `ImageProvider` en vez de pintar la imagen ellos, como el
/// PhotoView del visor de documentos.
ImageProvider cachedImageProvider(String url) => CachedNetworkImageProvider(
  url,
  cacheKey: cacheKeyFor(url),
  cacheManager: SozuCacheManager.instance,
);
