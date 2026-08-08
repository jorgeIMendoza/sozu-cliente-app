import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';

import 'package:web/web.dart' as web;

/// Suscripción viva a los eventos de arrastre del navegador.
class _DropHandle {
  final JSFunction over;
  final JSFunction leave;
  final JSFunction drop;

  _DropHandle(this.over, this.leave, this.drop);
}

/// Escucha el arrastre en toda la ventana y entrega por [onFile] el primer
/// archivo soltado dentro de [rect].
///
/// [rect] se consulta en CADA evento a propósito: la zona se mueve con el
/// scroll y un rectángulo capturado al suscribir dejaría de coincidir. Va en
/// píxeles lógicos de Flutter, que en web son los mismos píxeles CSS del
/// evento del navegador.
///
/// El `preventDefault` del `dragover` es obligatorio: sin él el navegador
/// abre el PDF en la pestaña y la app desaparece.
Object? registerFileDrop({
  required Rect Function() rect,
  required void Function(bool encima) onHover,
  required void Function(String nombre, Uint8List bytes) onFile,
}) {
  bool dentro(web.MouseEvent e) =>
      rect().contains(Offset(e.clientX.toDouble(), e.clientY.toDouble()));

  void onOver(web.Event ev) {
    final e = ev as web.MouseEvent;
    e.preventDefault();
    onHover(dentro(e));
  }

  void onLeave(web.Event ev) => onHover(false);

  void onDrop(web.Event ev) {
    final e = ev as web.DragEvent;
    e.preventDefault();
    onHover(false);
    if (!dentro(e)) return;
    final files = e.dataTransfer?.files;
    if (files == null || files.length == 0) return;
    final file = files.item(0);
    if (file == null) return;
    file.arrayBuffer().toDart.then((buf) {
      onFile(file.name, buf.toDart.asUint8List());
    });
  }

  final over = onOver.toJS;
  final leave = onLeave.toJS;
  final drop = onDrop.toJS;
  web.window.addEventListener('dragover', over);
  web.window.addEventListener('dragleave', leave);
  web.window.addEventListener('drop', drop);
  return _DropHandle(over, leave, drop);
}

/// Quita los listeners. Con las MISMAS referencias que se registraron: cada
/// `.toJS` crea una función JS nueva, así que rehacerlo aquí no quitaría nada.
void cancelFileDrop(Object? handle) {
  if (handle is! _DropHandle) return;
  web.window.removeEventListener('dragover', handle.over);
  web.window.removeEventListener('dragleave', handle.leave);
  web.window.removeEventListener('drop', handle.drop);
}
