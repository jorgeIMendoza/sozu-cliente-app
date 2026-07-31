/// Versión de la app mostrada en el login (misma metodología que sozu-admin:
/// `vX.Y.Z-YYMMDD.HHMM`, hora local de México al momento del build).
///
/// ACTUALIZAR `buildTimestamp` en cada build/entrega:
///   PowerShell:  Get-Date -Format "yyMMdd.HHmm"
/// O sobreescribir al compilar sin tocar el archivo:
///   flutter build web --dart-define=BUILD_TIMESTAMP=YYMMDD.HHMM
library;

const String appVersionBase = '1.0.0';

const String _buildTimestampDefault = '260728.1907';

const String buildTimestamp = String.fromEnvironment(
  'BUILD_TIMESTAMP',
  defaultValue: _buildTimestampDefault,
);

/// Etiqueta completa, ej. `v1.0.0-260706.1729`.
const String appVersionLabel = 'v$appVersionBase-$buildTimestamp';

/// Entorno del build. Los pipelines productivos (deploy web a Firebase y
/// builds de tiendas en Codemagic) compilan con `--dart-define=APP_ENV=prod`;
/// cualquier otro build (local, ramas de prueba) queda como "preview" y
/// muestra el cintillo de desarrollo.
const String appEnv = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'preview',
);

const bool isPreviewBuild = appEnv != 'prod';

/// Compara dos versiones SemVer por X.Y.Z (ignora sufijos `-build`/`+meta` y
/// cualquier caracter no numérico dentro de cada segmento). Web-safe.
/// Devuelve `<0` si `a<b`, 0 si iguales, `>0` si `a>b`. Segmentos faltantes = 0.
int compareSemver(String a, String b) {
  List<int> parse(String v) {
    final core = v.trim().split(RegExp(r'[-+ ]')).first;
    final parts = core.split('.');
    return List<int>.generate(3, (i) {
      if (i >= parts.length) return 0;
      final digits = parts[i].replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(digits) ?? 0;
    });
  }

  final pa = parse(a);
  final pb = parse(b);
  for (var i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
  }
  return 0;
}
