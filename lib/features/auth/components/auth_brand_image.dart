import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/features/app_download/components/app_download.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Panel de la columna izquierda del acceso (solo desktop): imagen a sangre y,
/// en web, la tarjeta del QR para instalar la app.
///
/// El QR vive AQUI y no en cada pantalla: lo pintaba solo el login y
/// recuperar contrasena se quedaba sin el.
class AuthBrandImage extends StatelessWidget {
  const AuthBrandImage({super.key});

  /// Ruta del asset. Declarada en `pubspec.yaml`; lo verifica
  /// `test/assets_declarados_test.dart`.
  static const String assetPath = 'assets/images/bg-sozu.jpg';

  @override
  Widget build(BuildContext context) {
    // Solo en web de escritorio: el QR se escanea con OTRO dispositivo, asi que
    // en un telefono no tiene sentido, y dentro de la app nativa menos.
    if (kIsWeb && context.bp.isDesktop) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _imagen(),
          Positioned(
            left: 32,
            right: 32,
            bottom: 32,
            child: const Align(
              alignment: Alignment.bottomRight,
              child: AppQrCard(),
            ),
          ),
        ],
      );
    }
    return _imagen();
  }

  Widget _imagen() {
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
          child: Center(child: SLogo.onBrand(height: 40)),
        ),
      ),
    );
  }
}
