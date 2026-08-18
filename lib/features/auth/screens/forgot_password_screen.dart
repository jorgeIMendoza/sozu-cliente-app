import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/features/auth/components/forgot_password_form.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';

/// Recuperar contraseña. Solo compone: el andamio de acceso y el formulario.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const AuthLayout(child: ForgotPasswordForm());
}
