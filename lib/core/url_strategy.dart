/// Estrategia de URL del navegador.
///
/// Se resuelve en tiempo de compilación con importación condicional, igual que
/// `core/file_download.dart`: en móvil entra el stub vacío, en web la versión
/// que llama a `usePathUrlStrategy()`. Así `flutter_web_plugins` nunca se
/// importa en los builds de Android/iOS.
library;

// ignore: always_use_package_imports -- export condicional: la
// resolucion por plataforma exige ruta relativa.
export 'url_strategy_stub.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart';
