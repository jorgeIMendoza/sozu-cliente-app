/// Descarga de archivos multiplataforma.
///
/// - Web: descarga el archivo como blob con nombre de archivo (anchor
///   `download`), con fallback a abrir la URL si CORS bloquea el fetch.
/// - Móvil/escritorio: no hay blob; abre el archivo con el visor del sistema
///   (el usuario lo guarda desde ahí).
///
/// Se resuelve en tiempo de compilación con importación condicional, igual que
/// `core/portal_tracking.dart`.
library;

export 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart';
