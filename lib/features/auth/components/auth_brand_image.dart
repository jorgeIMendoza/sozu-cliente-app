import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/ui.dart';

/// Panel decorativo de la columna izquierda del acceso (solo desktop): una sola
/// imagen a sangre, sin texto ni logo encima. La comparten las tres
/// pantallas de acceso. Puramente decorativa (`excludeFromSemantics`).
class AuthBrandImage extends StatelessWidget {
  const AuthBrandImage({super.key});

  /// Ruta del asset. Declarada en `pubspec.yaml`; lo verifica
  /// `test/assets_declarados_test.dart`.
  static const String assetPath = 'assets/images/bg-sozu.jpg';

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Se ve durante el decode y en el sobrante si la proporción no cubre.
      color: SozuBrand.green,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        // Imagen cuadrada (1403x1403) en columna alta: cover recorta los lados,
        // anclado al centro para no perder el sujeto.
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        excludeFromSemantics: true,
        filterQuality: FilterQuality.medium,
        // Sin esto, un asset ausente pinta la X roja de Flutter cruzando el
        // panel. Ojo: un cambio de pubspec.yaml NO lo toma el hot restart, hay
        // que relanzar `flutter run`.
        errorBuilder: (context, error, stack) => const ColoredBox(
          color: SozuBrand.green,
          child: Center(child: SozuLogo.onBrand(height: 40)),
        ),
      ),
    );
  }
}
