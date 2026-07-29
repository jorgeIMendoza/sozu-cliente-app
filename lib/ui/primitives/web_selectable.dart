import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Habilita seleccionar y copiar texto con el mouse — SOLO en web.
///
/// Flutter web usa CanvasKit: el texto se rasteriza en un `<canvas>`, así que el
/// navegador no lo ve como texto y "seleccionar con el mouse" no existe por
/// defecto. (El renderer HTML, que sí generaba DOM, se eliminó del SDK; en
/// Flutter 3.44 solo hay canvaskit/skwasm.) `SelectionArea` reimplementa la
/// selección dentro de Flutter: pinta el resaltado, maneja el arrastre y expone
/// Ctrl+C.
///
/// ## Dónde SÍ y dónde NO se puede montar
///
/// `SelectionArea` necesita un `Overlay` ancestro —lo usa para el menú flotante
/// de copiar— y el `Overlay` lo crea el `Navigator`. Por eso **NO** puede ir en
/// el `builder` de `MaterialApp`: ahí el árbol está por ENCIMA del `Navigator` y
/// revienta con:
///
/// ```
/// No Overlay widget found.
/// SelectableRegion widgets require an Overlay widget ancestor
/// ```
///
/// Tiene que ir dentro de una ruta: el builder de un `ShellRoute`, o el body de
/// una pantalla. En esta app se monta una sola vez, en el `ShellRoute` de
/// `router.dart`, que envuelve todas las pantallas del cliente (tabs +
/// secundarias).
///
/// Limitado a web a propósito: en móvil la selección global cambia el long-press
/// de toda la app y no aporta nada — ahí el gesto nativo ya funciona sobre los
/// campos de texto.
class WebSelectable extends StatelessWidget {
  final Widget child;

  const WebSelectable({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      kIsWeb ? SelectionArea(child: child) : child;
}
