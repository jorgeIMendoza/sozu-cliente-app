import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/features/auth/components/change_password_form.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';

/// Cambio OBLIGATORIO de contraseña temporal (`debe_cambiar_password`). Solo
/// compone: el andamio de acceso y el formulario.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const AuthLayout(child: ChangePasswordForm());
}
