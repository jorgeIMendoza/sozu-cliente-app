import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/ui.dart';

/// Área desplazable del admin: el scroll ocupa el viewport completo y el
/// contenido va centrado dentro de él.
///
/// WARN: El orden importa. Si el limitador de ancho envuelve al scroll, la rueda
/// solo mueve la columna central. Por lo mismo el contenido NO puede traer
/// scroll propio: listas con `shrinkWrap`, o mejor `Column`.
class AdminScrollArea extends StatelessWidget {
  const AdminScrollArea({
    super.key,
    required this.child,
    this.maxWidth = kSozuContentMaxWidth,
    this.onRefresh,
  });

  final Widget child;
  final double maxWidth;

  /// Pull-to-refresh. Solo se monta si se pasa: un `RefreshIndicator` sin
  /// callback añade un gesto que no hace nada.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final gutter = context.responsive(mobile: t.space.md, desktop: t.space.lg);

    // El teclado se dibuja ENCIMA del contenido (ver `AdminLayout`), así que el
    // padding inferior es lo que mantiene alcanzable el último elemento.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    Widget view = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, gutter + keyboard),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );

    if (onRefresh != null) {
      view = RefreshIndicator(onRefresh: onRefresh!, child: view);
    }
    return Scrollbar(child: view);
  }
}

/// Pantalla completa de super admin: fondo de página + [AdminScrollArea].
///
/// Es el ÚNICO layout de la feature: no tiene variantes, y las pantallas con
/// pestañas usan [STabs], que deja el cuerpo en línea.
///
/// `resizeToAvoidBottomInset: false` a propósito: con resize, en teléfono el
/// contenido desborda. Aquí se escribe arriba y los resultados van debajo, así
/// que es correcto que el teclado los tape.
class AdminLayout extends StatelessWidget {
  const AdminLayout({
    super.key,
    required this.child,
    this.maxWidth = kSozuContentMaxWidth,
    this.onRefresh,
  });

  final Widget child;
  final double maxWidth;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // `background`, no `surface`: el fondo de página es un nivel por DEBAJO de
      // las tarjetas. Usar surface aplanaba todo en un solo tono.
      backgroundColor: context.s.color.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: AdminScrollArea(
          maxWidth: maxWidth,
          onRefresh: onRefresh,
          child: child,
        ),
      ),
    );
  }
}
