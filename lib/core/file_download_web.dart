import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: descarga el archivo con nombre propio. Intenta traerlo como blob
/// (para forzar `download` con [filename]); si el fetch falla por CORS cae a
/// un anchor directo sobre la URL. Devuelve true si se lanzó la descarga.
Future<bool> downloadFile(String url, String filename) async {
  try {
    final resp = await web.window.fetch(url.toJS).toDart;
    if (resp.ok) {
      final blob = await resp.blob().toDart;
      final objUrl = web.URL.createObjectURL(blob);
      _triggerAnchor(objUrl, filename);
      Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(objUrl));
      return true;
    }
  } catch (_) {
    /* CORS u otro error: cae al anchor directo */
  }
  _triggerAnchor(url, filename);
  return true;
}

/// Web: dispara la descarga de [bytes] ya en memoria como un archivo con
/// nombre [filename] (crea un Blob + anchor `download`). Útil para archivos
/// generados en el cliente (p. ej. un ZIP de facturas). Devuelve true si se
/// lanzó la descarga.
Future<bool> downloadBytes(List<int> bytes, String filename,
    {String mimeType = 'application/octet-stream'}) async {
  try {
    final data = Uint8List.fromList(bytes).toJS;
    final blob = web.Blob(
      <JSAny>[data].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final objUrl = web.URL.createObjectURL(blob);
    _triggerAnchor(objUrl, filename);
    Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(objUrl));
    return true;
  } catch (_) {
    return false;
  }
}

void _triggerAnchor(String href, String filename) {
  final a = web.document.createElement('a') as web.HTMLAnchorElement;
  a.href = href;
  a.download = filename;
  a.target = '_blank';
  web.document.body?.appendChild(a);
  a.click();
  a.remove();
}
