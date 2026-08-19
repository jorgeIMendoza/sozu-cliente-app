import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/client/layouts/client_shell.dart';

/// El menú del portal vive en CÓDIGO, no en la BD: `cliente-menu` existe pero
/// su menú padre está apagado, así que devolvía cero ítems y encenderlo
/// borraría de la navegación todo lo que allá falte.
///
/// Con una sola fuente, el riesgo se mueve: un ítem puede apuntar a una ruta
/// que el router no registra, y eso solo se ve al tocarlo. Este test lo caza
/// leyendo el router, sin montar nada.
void main() {
  test('cada ítem del menú apunta a una ruta que el router registra', () {
    final router = File('lib/router.dart').readAsStringSync();
    final rutas = RegExp(
      r"path: '([^']+)'",
    ).allMatches(router).map((m) => m.group(1)!).toSet();

    expect(rutas, isNotEmpty, reason: 'el barrido del router no encontró nada');

    final huerfanas = clienteMenuTabs()
        .map((t) => t.route)
        .where((r) => !rutas.contains(r))
        .toList();

    expect(
      huerfanas,
      isEmpty,
      reason: 'estas rutas del menú no existen en el router: $huerfanas',
    );
  });

  test('el menú y las rutas permitidas no se desincronizan', () {
    expect(
      portalAllowedRoutes(),
      clienteMenuTabs().map((t) => t.route).toSet(),
    );
  });

  test('no hay rutas repetidas: cada ítem es un destino distinto', () {
    final rutas = clienteMenuTabs().map((t) => t.route).toList();
    expect(rutas.toSet().length, rutas.length);
  });
}
