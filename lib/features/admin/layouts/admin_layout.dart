import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/ui.dart';

/// Área desplazable del admin: el scroll ocupa el **viewport completo** y el
/// contenido va centrado con ancho máximo dentro de él.
///
/// El orden importa y es el arreglo: cuando el limitador de ancho envolvía al
/// scroll, la rueda del ratón solo movía la columna de contenido. Fuera de esos
/// ~800 px la página no respondía, y en escritorio ancho eso es la mayor parte de
/// la pantalla.
///
/// Consecuencia para el contenido: NO puede traer scroll propio. Las listas van
/// con `shrinkWrap: true` y `physics: NeverScrollableScrollPhysics()`, o mejor
/// como `Column`.
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
/// **Es el ÚNICO layout de la feature y no tiene variantes.** Hubo una,
/// `AdminLayout.fixed`, sin scroll de página, para la pantalla de avisos: su
/// `TabBarView` no tiene alto intrínseco y no cabía dentro de un scroll. El
/// resultado era que las dos pantallas de admin se desplazaban distinto y en
/// avisos la rueda del ratón solo respondía sobre la columna central. Se quitó
/// junto con el `TabBarView`: hoy las pestañas son [STabs], que solo pinta la
/// fila de etiquetas y deja el cuerpo en linea (ver `ui/primitives/s_tabs.dart`).
///
/// `resizeToAvoidBottomInset: false` a propósito: con el resize, en un teléfono
/// el encabezado y los filtros no caben en lo que queda y el contenido desborda
/// ("BOTTOM OVERFLOWED BY N PIXELS"). Aquí se escribe arriba y los resultados van
/// debajo, así que es correcto que el teclado los tape.
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
