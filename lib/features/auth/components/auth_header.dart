import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Logo SOZU centrado.
///
/// Se oculta en el layout partido: ahí la columna izquierda ya es el elemento de
/// marca, y repetir el logo a 30 cm se lee como error de maquetación.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.bp.isDesktop) return const SizedBox.shrink();
    return const Center(child: SozuLogo(height: 40));
  }
}

/// Título de la pantalla de acceso.
///
/// Usa `context.s.text.h1`, que en móvil ya viene un escalón más chico por la
/// densidad `compact` del design system. Antes esto se resolvía a mano con
/// `SozuType.h1.copyWith(fontSize: 25)` - el mismo cálculo que la densidad hace
/// para toda la app.
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

/// Subtítulo de apoyo.
class AuthSubtitle extends StatelessWidget {
  const AuthSubtitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Text(
      text,
      textAlign: kAuthTextAlign,
      style: t.text.body.copyWith(color: t.color.fgMuted),
    );
  }
}
