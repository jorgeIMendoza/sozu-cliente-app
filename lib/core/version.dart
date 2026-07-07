/// Versión de la app mostrada en el login (misma metodología que sozu-admin:
/// `vX.Y.Z-YYMMDD.HHMM`, hora local de México al momento del build).
///
/// ACTUALIZAR `buildTimestamp` en cada build/entrega:
///   PowerShell:  Get-Date -Format "yyMMdd.HHmm"
/// O sobreescribir al compilar sin tocar el archivo:
///   flutter build web --dart-define=BUILD_TIMESTAMP=YYMMDD.HHMM
library;

const String appVersionBase = '1.0.0';

const String _buildTimestampDefault = '260707.1441';

const String buildTimestamp = String.fromEnvironment(
  'BUILD_TIMESTAMP',
  defaultValue: _buildTimestampDefault,
);

/// Etiqueta completa, ej. `v1.0.0-260706.1729`.
const String appVersionLabel = 'v$appVersionBase-$buildTimestamp';
