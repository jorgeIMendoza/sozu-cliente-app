import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Título de la pantalla de acceso. Usa `context.s.text.h1`, que en móvil ya
/// baja un escalón por la densidad `compact`: no forzar el tamaño a mano.
class AuthTitle extends StatelessWidget {
  const AuthTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Text(
      text,
      textAlign: kAuthTextAlign,
      style: t.text.h1.copyWith(color: t.color.fg),
    );
  }
}
