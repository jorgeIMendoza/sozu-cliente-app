import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/ui.dart';

/// Panel decorativo de la columna izquierda del acceso (solo desktop).
///
/// Es una sola imagen a sangre, sin texto ni logo encima. Antes traía titular +
/// promesa + pie: tres bloques de texto que competían con el formulario y que en
/// pantallas bajas había que reescalar a mano con tres escalones tipográficos.
/// Una fotografía comunica lo mismo sin mantenimiento y no se rompe a ningún
/// alto.
///
/// **Vive en `auth/components/` y no en `auth/login/components/`** porque lo
/// comparten las tres páginas de acceso (login, recuperar contraseña y cambio
/// forzado). Es el mismo criterio de hoisting que en React: un componente sube
/// al nivel donde está su consumidor común.
///
/// Puramente decorativo: `excludeFromSemantics` para que los lectores de
/// pantalla no anuncien una imagen sin contenido.
class AuthBrandImage extends StatelessWidget {
  const AuthBrandImage({super.key});

  /// Ruta del asset. Declarada en `pubspec.yaml`; hay un test que lo verifica
  /// (`test/assets_declarados_test.dart`).
  static const String assetPath = 'assets/images/bg-sozu.jpg';

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Se ve durante el decode de la imagen y en el sobrante si alguna vez la
      // proporción no alcanza a cubrir: verde de marca, no gris.
      color: SozuBrand.green,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        // La imagen es cuadrada (1403x1403) y el panel es una columna alta:
        // cover recorta los lados. Se ancla al centro para no perder el sujeto.
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        excludeFromSemantics: true,
        filterQuality: FilterQuality.medium,
        // Sin esto, un asset ausente pinta la X roja de Flutter cruzando el
        // panel entero. El caso más común no es que falte el archivo, sino que
        // `flutter run` siga corriendo desde antes de declararlo en
        // pubspec.yaml: un cambio de pubspec NO lo toma el hot restart.
        errorBuilder: (context, error, stack) => const ColoredBox(
          color: SozuBrand.green,
          child: Center(child: SozuLogo.onBrand(height: 40)),
        ),
      ),
    );
  }
}
