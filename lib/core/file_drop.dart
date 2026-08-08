/// Arrastrar y soltar archivos sobre una zona de la pantalla.
///
/// - Web: escucha los eventos de arrastre del navegador y entrega el archivo
///   soltado DENTRO del rectángulo que la zona declara.
/// - Móvil/escritorio: no hay arrastre; queda en nada y la zona funciona solo
///   con el selector de archivos.
///
/// Se resuelve en tiempo de compilación con importación condicional, igual que
/// `core/file_download.dart`.
library;

// ignore: always_use_package_imports -- export condicional: la
// resolucion por plataforma exige ruta relativa.
export 'file_drop_stub.dart' if (dart.library.js_interop) 'file_drop_web.dart';
