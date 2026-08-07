import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Andamio de `web/index.html`. El `<meta name="viewport">` faltó en
/// producción y nada lo delató: compila, analyze calla y en Chrome de
/// escritorio se ve bien. Solo se rompe en un teléfono real.
void main() {
  late String html;

  setUpAll(() {
    html = File('web/index.html').readAsStringSync();
  });

  test('declara el viewport', () {
    final meta = RegExp(
      r'<meta\s+name="viewport"\s+content="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(html);

    expect(
      meta,
      isNotNull,
      reason:
          'sin <meta name="viewport"> Safari en iOS renderiza a 980 px: los '
          'toques se desalinean y los campos de texto no reciben escritura',
    );

    final content = meta!.group(1)!;
    expect(
      content,
      contains('width=device-width'),
      reason: 'es lo que ata el viewport al ancho real del dispositivo',
    );
    expect(content, contains('initial-scale=1'));
  });

  test('la tarjeta al compartir está completa', () {
    // Un og:image relativo lo ignoran WhatsApp y Meta: la tarjeta sale sin
    // imagen y el enlace parece roto.
    for (final tag in [
      'og:title',
      'og:description',
      'og:image',
      'og:url',
      'twitter:card',
      'twitter:image',
    ]) {
      expect(html, contains(tag), reason: 'falta $tag');
    }
    expect(html, contains('https://clientes.sozu.com/og-image.jpg'));
    expect(File('web/og-image.jpg').existsSync(), isTrue);
  });

  test('el portal no se indexa: vive detrás del login', () {
    expect(html, contains('noindex'));
  });

  test('el título de la pestaña es el acordado', () {
    expect(html, contains('<title>SOZU • Portal del Cliente</title>'));
  });

  test('no bloquea el zoom: es un requisito de accesibilidad', () {
    final meta = RegExp(
      r'<meta\s+name="viewport"\s+content="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(html);
    final content = meta!.group(1)!;

    expect(
      content,
      isNot(contains('user-scalable=no')),
      reason:
          'iOS lo ignora, pero Android sí lo respeta y dejaría a un usuario '
          'con baja visión sin poder acercar la pantalla',
    );
  });
}
