/// Visor de PDF embebido, resuelto por plataforma.
///
/// En web es un `<iframe>` con el visor del navegador: rapido, con zoom y
/// busqueda, y sin rasterizar en el hilo de la app. Fuera de web no aplica.
// ignore: always_use_package_imports
export 's_pdf_frame_stub.dart'
    if (dart.library.js_interop) 's_pdf_frame_web.dart';
