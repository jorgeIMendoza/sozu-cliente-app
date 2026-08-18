import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/features/auth/components/email_confirmation_status.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';

/// Aterrizaje del enlace "Confirma tu correo" que manda `reset-user-password`.
/// Solo compone: el andamio de acceso y el canje del token.
///
/// La ruta es `/auth/confirmacion-email` porque es la que ya viaja en los
/// correos enviados: la fija la Edge Function y no se puede cambiar sin dejar
/// muertos los enlaces en circulación.
class ConfirmacionEmailScreen extends StatelessWidget {
  const ConfirmacionEmailScreen({
    super.key,
    this.tokenHash,
    this.type,
    this.email,
    this.nombre,
  });

  final String? tokenHash;
  final String? type;
  final String? email;
  final String? nombre;

  @override
  Widget build(BuildContext context) => AuthLayout(
    child: EmailConfirmationStatus(
      tokenHash: tokenHash,
      type: type,
      email: email,
      nombre: nombre,
    ),
  );
}
