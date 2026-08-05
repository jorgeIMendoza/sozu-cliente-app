import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/features/app_download/components/app_download.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_brand_image.dart';
import 'package:sozu_cliente_app/features/auth/components/login_form.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Pantalla de acceso. Solo compone: andamio responsive, panel de marca,
/// formulario y -solo en web- el QR para descargar la app.
///
/// El QR se ofrece únicamente en web (`kIsWeb`): dentro de la app nativa no
/// tiene sentido. En escritorio va sobre el panel de marca; en móvil-web,
/// debajo del formulario.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.bp.isDesktop;
    // Escritorio-web: QR sobre la foto (se escanea con el teléfono).
    final qrOnBrand = kIsWeb && isDesktop;
    // Móvil-web: sin QR (no se escanea la propia pantalla); botón a la tienda.
    final storeButton = kIsWeb && !isDesktop;

    return AuthLayout(
      brand: qrOnBrand ? const _BrandWithQr() : const AuthBrandImage(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LoginForm(),
          if (storeButton) ...[
            const SizedBox(height: 24),
            const AppStoreDownloadButton(),
          ],
        ],
      ),
    );
  }
}

/// Panel de marca con la card del QR sobrepuesta abajo (login en escritorio).
class _BrandWithQr extends StatelessWidget {
  const _BrandWithQr();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        AuthBrandImage(),
        Positioned(
          left: 32,
          right: 32,
          bottom: 32,
          child: Align(
            alignment: Alignment.bottomRight,
            child: AppQrCard(),
          ),
        ),
      ],
    );
  }
}
