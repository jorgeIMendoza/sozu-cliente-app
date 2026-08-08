import 'dart:typed_data';
import 'dart:ui';

/// Sin arrastre fuera del navegador: devuelve null y la zona de carga sigue
/// funcionando con el selector de archivos.
Object? registerFileDrop({
  required Rect Function() rect,
  required void Function(bool encima) onHover,
  required void Function(String nombre, Uint8List bytes) onFile,
}) => null;

/// No-op: no hay nada suscrito.
void cancelFileDrop(Object? handle) {}
