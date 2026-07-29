import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_brand_image.dart';
import 'package:sozu_cliente_app/features/auth/components/login_form.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';

/// Pantalla de acceso.
///
/// Solo **compone**: el andamio responsive, el panel de marca y el formulario.
/// No tiene estado, no habla con providers y no valida nada — todo eso vive en
/// [LoginForm].
///
/// ```
/// features/auth/
/// ├── layouts/          ← ESTRUCTURA: impone tema, scroll y breakpoints
/// │   └── auth_layout.dart      (AuthLayout + AuthFormBody)
/// ├── screens/          ← las páginas: solo composición, sin estado
/// │   ├── login_screen.dart
/// │   ├── forgot_password_screen.dart
/// │   └── change_password_screen.dart
/// └── components/       ← piezas REUTILIZABLES (las usan 2+ pantallas)
///     ├── auth_brand_image.dart  la imagen
///     ├── auth_header.dart       logo, título, subtítulo
///     ├── auth_text_field.dart   campo + etiqueta
///     ├── auth_buttons.dart      primario, contorno, enlace
///     ├── auth_alert.dart        alertas
///     └── login_form.dart        el formulario (único del login, 1 componente)
/// ```
///
/// Criterio de las tres carpetas:
/// * `layouts/` — envuelve pantallas y decide tema/scroll/breakpoints.
/// * `components/` — se reutiliza. `login_form` es la excepción deliberada: es
///   único del login, pero partirlo en sub-componentes por partirlo solo agrega
///   archivos sin quitar acoplamiento.
/// * `screens/` — una pantalla no tiene lógica propia, ensambla.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthLayout(brand: AuthBrandImage(), child: LoginForm());
  }
}
