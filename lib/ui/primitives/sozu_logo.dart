import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/tokens/palette.dart';

/// Logotipo de SOZU. **Un solo PNG para todos los fondos.**
///
/// `assets/sozu-logo-black.png` es una silueta monocroma (píxeles opacos en
/// negro puro, el resto transparente), así que se recolorea en runtime con
/// `BlendMode.srcIn` y no hacen falta dos archivos.
///
/// El color por defecto es [SozuColorRoles.fg] (sigue el tema).
///
/// ```dart
/// const SozuLogo(height: 24)                    // sigue el tema
/// const SozuLogo.onBrand(height: 40)            // blanco, sobre el verde
/// SozuLogo(height: 20, color: context.s.color.fgMuted)  // atenuado
/// ```
///
/// Ojo: se dimensiona por ALTO y el ancho sale de la proporción; nunca fijar
/// ambos o se deforma.
class SozuLogo extends StatelessWidget {
  /// Alto en px lógicos. El ancho se deriva de la proporción del asset.
  final double height;

  /// `null` → [SozuColorRoles.fg].
  final Color? color;

  /// Texto alternativo para lectores de pantalla.
  final String semanticLabel;

  /// Solo importa si el padre estira el widget.
  final Alignment alignment;

  const SozuLogo({
    super.key,
    this.height = 24,
    this.color,
    this.semanticLabel = 'SOZU',
    this.alignment = Alignment.center,
  });

  /// Para fondos de marca y superficies oscuras saturadas: siempre blanco, sin
  /// importar el tema.
  const SozuLogo.onBrand({
    super.key,
    this.height = 24,
    this.semanticLabel = 'SOZU',
    this.alignment = Alignment.center,
  }) : color = SozuNeutral.n0;

  /// Para superficies **claras fijas**: siempre oscuro, sin importar el tema.
  /// Es la correcta en el shell y las cards del portal web (light-only).
  const SozuLogo.onLight({
    super.key,
    this.height = 24,
    this.semanticLabel = 'SOZU',
    this.alignment = Alignment.center,
  }) : color = SozuNeutral.n900;

  /// Proporción del asset (1043×300).
  static const double aspectRatio = 1043 / 300;

  /// Ruta del único asset del logo.
  static const String assetPath = 'assets/sozu-logo-black.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      // srcIn pinta `color` solo donde el asset tiene alfa; explícito para dejar
      // claro que el recoloreo es intencional.
      color: color ?? context.s.color.fg,
      colorBlendMode: BlendMode.srcIn,
      fit: BoxFit.contain,
      alignment: alignment,
      semanticLabel: semanticLabel,
      filterQuality: FilterQuality.medium,
    );
  }
}
