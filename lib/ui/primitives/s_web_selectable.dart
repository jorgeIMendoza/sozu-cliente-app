import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Habilita seleccionar y copiar texto con el mouse - SOLO en web.
///
/// Flutter web rasteriza el texto en un `<canvas>`, así que el navegador no lo
/// ve como texto; `SelectionArea` reimplementa la selección dentro de Flutter.
///
/// OJO: `SelectionArea` necesita un `Overlay` ancestro, que lo crea el
/// `Navigator`, así que NO puede ir en el `builder` de `MaterialApp` (revienta
/// con "No Overlay widget found"). Tiene que ir dentro de una ruta: aquí se
/// monta una sola vez en el `ShellRoute` de `router.dart`.
///
/// Limitado a web a propósito: en móvil el gesto nativo ya funciona.
class WebSelectable extends StatelessWidget {
  final Widget child;

  const WebSelectable({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      kIsWeb ? SelectionArea(child: child) : child;
}
