import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/media_cache.dart';
import '../core/theme.dart';
import 'common.dart';

/// ImageProvider cacheado (misma clave estable y cache manager). Para usar en
/// widgets que reciben un ImageProvider, ej. PhotoView del visor.
ImageProvider cachedImageProvider(String url) => CachedNetworkImageProvider(
  url,
  cacheKey: cacheKeyFor(url),
  cacheManager: SozuCacheManager.instance,
);

/// Imagen de red con cache en disco (7 días) y clave estable (ignora el token
/// de las URLs firmadas de Supabase). Placeholder de carga + fallback de error.
/// Reemplaza los `Image.network` sueltos de la app.
class SozuNetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final IconData placeholderIcon;

  const SozuNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.business_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    if (url == null || url!.isEmpty) return _fallback(tone);
    return CachedNetworkImage(
      imageUrl: url!,
      cacheKey: cacheKeyFor(url!),
      cacheManager: SozuCacheManager.instance,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => const Skeleton(height: double.infinity),
      errorWidget: (_, __, ___) => _fallback(tone),
    );
  }

  Widget _fallback(SozuTone tone) => Container(
    color: tone.surfaceAlt,
    alignment: Alignment.center,
    child: Icon(placeholderIcon, size: 40, color: tone.textMuted),
  );
}
