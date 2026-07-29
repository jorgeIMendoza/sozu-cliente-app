import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Verifica que TODO asset referenciado en `lib/` esté declarado en
/// `pubspec.yaml`.
///
/// Por qué existe: usar un asset sin declararlo compila, pasa `flutter analyze`
/// y hasta funciona en algunos arranques de debug - y explota en runtime con
/// `Unable to load asset: "…". The asset does not exist or has empty data.`
/// En `build web --release` es peor, porque el asset simplemente no viaja.
///
/// Es un test de archivos, no de widgets: no necesita `pumpWidget` y corre en
/// milisegundos.
void main() {
  test('todo asset usado en lib/ está declarado en pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declarados = _assetsDeclarados(pubspec);

    final usados = <String, List<String>>{};
    for (final f in _dartFiles('lib')) {
      final src = f.readAsStringSync();
      for (final ruta in _assetsReferenciados(src)) {
        usados.putIfAbsent(ruta, () => []).add(f.path);
      }
    }

    expect(
      usados,
      isNotEmpty,
      reason: 'El barrido no encontró ningún asset: revisa el regex.',
    );

    final faltantes = <String, List<String>>{};
    for (final entry in usados.entries) {
      if (!_estaCubierto(entry.key, declarados)) {
        faltantes[entry.key] = entry.value;
      }
    }

    expect(
      faltantes,
      isEmpty,
      reason:
          'Estos assets se usan en el código pero NO están en pubspec.yaml:\n'
          '${faltantes.entries.map((e) => '  ${e.key}\n    ← ${e.value.join('\n    ← ')}').join('\n')}',
    );
  });

  test('todo asset declarado en pubspec.yaml existe en disco', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final faltantes = <String>[];

    for (final d in _assetsDeclarados(pubspec)) {
      // Las entradas que terminan en '/' son directorios completos.
      if (d.endsWith('/')) {
        if (!Directory(d).existsSync()) faltantes.add('$d (directorio)');
      } else if (!File(d).existsSync()) {
        faltantes.add(d);
      }
    }

    // `assets/env` es gitignored (se genera en CI y en local desde
    // .env.example), así que se tolera su ausencia.
    faltantes.removeWhere((f) => f == 'assets/env');

    expect(
      faltantes,
      isEmpty,
      reason: 'Declarados en pubspec.yaml pero no existen en disco: $faltantes',
    );
  });
}

/// Lee las rutas bajo `flutter: assets:` del pubspec.
///
/// Parseo por líneas a propósito: agregar un paquete de YAML solo para esto no
/// se justifica, y el bloque tiene una forma fija (`    - ruta`).
Set<String> _assetsDeclarados(String pubspec) {
  final out = <String>{};
  var enAssets = false;
  for (final linea in pubspec.split('\n')) {
    final trim = linea.trim();
    if (trim.startsWith('#') || trim.isEmpty) continue;

    if (trim == 'assets:') {
      enAssets = true;
      continue;
    }
    if (enAssets) {
      if (trim.startsWith('- ')) {
        out.add(trim.substring(2).trim());
        continue;
      }
      // Cualquier otra clave al mismo nivel cierra el bloque (p. ej. `fonts:`).
      enAssets = false;
    }
  }
  return out;
}

/// Un asset está cubierto si se declaró exacto, o si se declaró su directorio.
bool _estaCubierto(String ruta, Set<String> declarados) {
  if (declarados.contains(ruta)) return true;
  return declarados.any((d) => d.endsWith('/') && ruta.startsWith(d));
}

/// Extrae rutas `assets/...` de literales de string del código.
///
/// Cubre `Image.asset('…')`, `AssetImage('…')`, `rootBundle.load('…')` y las
/// constantes tipo `static const assetPath = 'assets/…'`, que es como quedan
/// tras componentizar.
Iterable<String> _assetsReferenciados(String src) {
  final re = RegExp(r'''['"](assets/[^'"$\s]+\.[A-Za-z0-9]+)['"]''');
  return re.allMatches(src).map((m) => m.group(1)!).toSet();
}

List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();
