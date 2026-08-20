import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Candado de TEMA: fuerza el claro mientras el usuario todavia no entro.
/// Dentro de la app manda su preferencia (`themeProvider`).
///
/// El area de acceso -login, recuperacion, cambio forzado, splash y el gate de
/// correo- es la cara publica del producto y va siempre en claro.
///
/// El criterio NO es el ancho ni la plataforma: es el mismo del guard del
/// router (sin sesion, con candado biometrico, resolviendo, cuenta bloqueada o
/// cambio de contrasena pendiente). Cuando era el ancho, cruzar el breakpoint
/// saltaba de claro a oscuro de golpe y cada pixel de resize reconstruia el
/// arbol con un `ThemeData` nuevo.
class LightThemeLock extends ConsumerWidget {
  const LightThemeLock({super.key, required this.child});

  final Widget child;

  /// Una sola instancia: un `ThemeData` nuevo por build invalida a todo widget
  /// que dependa de `Theme.of`.
  static final ThemeData _claro = sozuLightTheme();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final dentro =
        auth.session != null &&
        !auth.locked &&
        !auth.isLoading &&
        auth.blockedAccess == null &&
        !auth.mustChangePassword;
    if (dentro) return child;
    return Theme(data: _claro, child: child);
  }
}
