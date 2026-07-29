import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/tokens/palette.dart';

/// Logotipo de SOZU. **Un solo PNG para todos los fondos.**
///
/// `assets/sozu-logo-black.png` es una silueta monocroma: todos sus píxeles
/// opacos son negro puro (#000000) y el resto es transparente. Eso permite
/// recolorearlo en tiempo de ejecución con `BlendMode.srcIn` -que reemplaza el
/// color conservando el canal alfa- así que NO hacen falta dos archivos
/// (negro y blanco) ni mantenerlos sincronizados.
///
/// El color por defecto es [SozuColorRoles.fg], o sea: negro en tema claro y
/// blanco en tema oscuro, automáticamente. Para el panel verde de marca del
/// login se pasa [SozuLogo.onBrand], que usa `onPrimary`.
///
/// ```dart
/// const SozuLogo(height: 24)                    // sigue el tema
/// const SozuLogo.onBrand(height: 40)            // blanco, sobre el verde
/// SozuLogo(height: 20, color: context.s.color.fgMuted)  // atenuado
/// ```
///
/// Ojo: el asset mide 1043×300 (proporción 3.48:1). Se dimensiona por ALTO y el
/// ancho sale de la proporción; nunca fijar ambos o se deforma.
class SozuLogo extends StatelessWidget {
  /// Alto en px lógicos. El ancho se deriva de la proporción del asset.
  final double height;

  /// Color del logo. `null` → [SozuColorRoles.fg] (negro en claro, blanco en
  /// oscuro).
  final Color? color;

  /// Texto alternativo para lectores de pantalla.
  final String semanticLabel;

  /// Alineación dentro del espacio disponible. Solo importa si el padre estira
  /// el widget (p. ej. dentro de una `Column` con `crossAxisAlignment.stretch`).
  final Alignment alignment;

  const SozuLogo({
    super.key,
    this.height = 24,
    this.color,
    this.semanticLabel = 'SOZU',
    this.alignment = Alignment.center,
  });

  /// Variante para fondos de marca (el verde del panel de login) y cualquier
  /// superficie oscura saturada: siempre blanco, sin importar el tema.
  const SozuLogo.onBrand({
    super.key,
    this.height = 24,
    this.semanticLabel = 'SOZU',
    this.alignment = Alignment.center,
  }) : color = SozuNeutral.n0;

  /// Variante para superficies **claras fijas**: siempre oscuro, sin importar el
  /// tema.
  ///
  /// Es la correcta dentro del shell y las cards del portal web, que son blancas
  /// por definición (el portal es light-only). Usar el default theme-aware ahí
  /// pintaría el logo blanco sobre blanco en cuanto alguien active tema oscuro.
  const SozuLogo.onLight({
    super.key,
    this.height = 24,
    this.semanticLabel = 'SOZU',
    this.alignment = Alignment.center,
  }) : color = SozuNeutral.n900;

  /// Proporción del asset (1043×300).
  static const double aspectRatio = 1043 / 300;

  /// Ruta del único asset del logo. Si algún día cambia el archivo, se cambia
  /// aquí y nada más.
  static const String assetPath = 'assets/sozu-logo-black.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      // srcIn es el blendMode por defecto de `Image.color`: pinta `color` solo
      // donde el asset tiene alfa. Se declara explícito para que quede claro que
      // el recoloreo es intencional y no un tinte accidental.
      color: color ?? context.s.color.fg,
      colorBlendMode: BlendMode.srcIn,
      fit: BoxFit.contain,
      alignment: alignment,
      semanticLabel: semanticLabel,
      filterQuality: FilterQuality.medium,
    );
  }
}
