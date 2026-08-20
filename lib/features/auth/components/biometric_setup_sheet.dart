import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/features/auth/services/biometric_service.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Ofrece activar el desbloqueo con huella/rostro. No hace nada si la
/// plataforma no lo soporta, ya está activo, hubo un "Ahora no" en esta
/// ejecución, o la cuenta no es de cliente.
///
/// WARN: El llamador debe mantener `authFlowInProgress` en true mientras corre: el
/// router abandona esta ruta en cuanto el perfil deja de exigir el cambio de
/// contraseña, y sin el candado el sheet se desmonta a medias.
Future<void> offerBiometricSetup(
  BuildContext context,
  AuthController auth,
) async {
  if (!await auth.shouldOfferBiometrics()) return;
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
        // Arriba un pelo más: la hoja no trae asa, así que sin ese aire el
        // título queda lamiendo el borde redondeado.
        t.space.lg + t.space.xxs,
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
          // `lg` porque es la accion principal de una hoja modal, que es el
          // caso que ese tamano describe.
          SButton(
            label: 'Activar',
            size: SButtonSize.lg,
            onPressed: () => Navigator.pop(sheetContext, true),
          ),
          SizedBox(height: t.space.xs),
          SButton.ghost(
            label: 'Ahora no',
            fullWidth: true,
            onPressed: () => Navigator.pop(sheetContext, false),
          ),
        ],
      ),
    ),
  );

  if (shouldEnable != true) {
    BiometricService.instance.offerDeclined = true;
    return;
  }
  final ok = await BiometricService.instance.enable();
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
