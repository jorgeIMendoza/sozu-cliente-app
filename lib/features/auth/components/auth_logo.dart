import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Logo SOZU centrado. Se oculta en el layout partido, donde la columna
/// izquierda ya es el elemento de marca.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.bp.isDesktop) return const SizedBox.shrink();
    return const Center(child: SLogo(height: 40));
  }
}
