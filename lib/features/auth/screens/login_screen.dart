import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_brand_image.dart';
import 'package:sozu_cliente_app/features/auth/components/login_form.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';

/// Pantalla de acceso. Solo compone: andamio responsive, panel de marca y
/// formulario. Todo el estado y la validación viven en [LoginForm].
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthLayout(brand: AuthBrandImage(), child: LoginForm());
  }
}
