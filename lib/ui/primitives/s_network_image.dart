import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/core/media_cache.dart';
import 'package:sozu_cliente_app/ui/primitives/s_skeleton.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';

/// Imagen de red con cache en disco (7 dias) y clave estable, que ignora el
/// token de las URLs firmadas. Trae su propio esqueleto de carga y su respaldo
/// de error, asi que sustituye a un `Image.network` suelto.
class SNetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final IconData placeholderIcon;

  const SNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.business_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    if (url == null || url!.isEmpty) return _fallback(tone);
    return CachedNetworkImage(
      imageUrl: url!,
      cacheKey: cacheKeyFor(url!),
      cacheManager: SozuCacheManager.instance,
      fit: fit,
      // El cruce esqueleto -> foto es la entrada de un elemento: `normal`, el
      // mismo token que usan las cards al aparecer.
      fadeInDuration: context.s.motion.normal,
      placeholder: (_, __) => const SSkeleton(height: double.infinity),
      errorWidget: (_, __, ___) => _fallback(tone),
    );
  }

  Widget _fallback(SozuColorRoles tone) => Container(
    color: tone.surfaceAlt,
    alignment: Alignment.center,
    child: Icon(placeholderIcon, size: 40, color: tone.fgSubtle),
  );
}
