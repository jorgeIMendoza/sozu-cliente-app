/// Versión de la app mostrada en el login (misma metodología que sozu-admin:
/// `vX.Y.Z-YYMMDD.HHMM`, hora local de México al momento del build).
///
/// ACTUALIZAR `buildTimestamp` en cada build/entrega:
///   PowerShell:  Get-Date -Format "yyMMdd.HHmm"
/// O sobreescribir al compilar sin tocar el archivo:
///   flutter build web --dart-define=BUILD_TIMESTAMP=YYMMDD.HHMM
library;

const String appVersionBase = '1.0.0';

const String _buildTimestampDefault = '260714.2225';

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
