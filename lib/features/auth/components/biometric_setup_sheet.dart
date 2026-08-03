import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/features/auth/services/biometric_service.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Ofrece activar el desbloqueo con huella/rostro y lo activa si el usuario
/// acepta. No hace nada si la plataforma no lo soporta, ya está activo, hubo un
/// "Ahora no" en esta ejecución, o la cuenta no es de cliente.
///
/// El otro camino para activarla es la card de Perfil
/// (`biometric_toggle_card.dart`), que se oculta con las mismas reglas.
///
/// Recibe [auth] por parámetro en vez de leer el provider: quien conoce la
/// sesión es la pantalla.
///
/// El llamador debe mantener `authFlowInProgress` en true mientras esto corre:
/// el sheet vive sobre una ruta que el router abandona en cuanto el perfil deja
/// de exigir el cambio de contraseña, y sin el candado se desmonta a medias.
Future<void> offerBiometricSetup(
  BuildContext context,
  AuthController auth,
) async {
  if (!await auth.debeOfrecerBiometria()) return;
  if (!context.mounted) return;

  final t = context.s;
  final shouldEnable = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: t.color.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(t.radius.sheet)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.lg,
        t.space.lg + 4,
        t.space.lg,
        t.space.lg + MediaQuery.of(sheetContext).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.fingerprint, size: 48, color: t.color.primary),
          SizedBox(height: t.space.md),
          Text(
            'Entra más rápido',
            textAlign: TextAlign.center,
            style: t.text.h3.copyWith(color: t.color.fg),
          ),
          SizedBox(height: t.space.xs),
          Text(
            '¿Quieres usar tu huella o rostro para entrar sin escribir tu '
            'correo y contraseña la próxima vez?',
            textAlign: TextAlign.center,
            style: t.text.bodySmall.copyWith(color: t.color.fgMuted),
          ),
          SizedBox(height: t.space.lg),
          FilledButton(
            onPressed: () => Navigator.pop(sheetContext, true),
            child: const Text('Activar'),
          ),
          SizedBox(height: t.space.xs),
          TextButton(
            onPressed: () => Navigator.pop(sheetContext, false),
            child: Text(
              'Ahora no',
              style: t.text.label.copyWith(color: t.color.fgMuted),
            ),
          ),
        ],
      ),
    ),
  );

  if (shouldEnable != true) {
    BiometricService.instance.ofertaRechazada = true;
    return;
  }
  final ok = await BiometricService.instance.habilitar();
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo activar la biometría. Puedes hacerlo desde Perfil.',
        ),
      ),
    );
  }
}
