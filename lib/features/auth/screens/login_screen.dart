import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sozu_cliente_app/features/app_download/components/app_download.dart';
import 'package:sozu_cliente_app/features/auth/components/login_form.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/shared/providers/shared_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Pantalla de acceso. Solo compone: andamio responsive, panel de marca,
/// formulario y -solo en web- el QR para descargar la app.
///
/// El QR se ofrece únicamente en web (`kIsWeb`): dentro de la app nativa no
/// tiene sentido. En escritorio va sobre el panel de marca; en móvil-web,
/// debajo del formulario.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = context.bp.isDesktop;
    // Móvil-web: sin QR (no se escanea la propia pantalla); botón a la tienda.
    final storeButton = kIsWeb && !isDesktop;

    return AuthLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LoginForm(),
          if (storeButton) ...[
            const SizedBox(height: 24),
            // Las URLs vienen del mismo gate de versión que ya corre pre-login
            // (llave anónima, degrada a null): así iOS se enciende cambiando
            // una fila en la BD, sin recompilar.
            Builder(
              builder: (context) {
                final cfg = ref.watch(appVersionGateProvider).valueOrNull;
                return AppStoreDownloadButton(
                  androidStoreUrl: cfg?.androidStoreUrl,
                  iosStoreUrl: cfg?.iosStoreUrl,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
