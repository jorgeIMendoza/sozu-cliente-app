import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/features/client/facturacion/screens/doc_viewer_screen.dart';

/// Abre un documento o imagen.
///
/// Siempre DENTRO de la plataforma: son documentos internos y mandar al usuario
/// a otra pestaña rompe el contexto.
///
/// En web el visor embebe el PDF en un iframe (`SPdfFrame`) y lo dibuja el
/// navegador; `pdfx` rasteriza cada página en un canvas y ahí es donde se
/// trababa. En móvil sigue `pdfx`, que es el bueno en esa plataforma.
Future<void> openMedia(
  BuildContext context,
  String? url, {
  String? titulo,
}) async {
  if (url == null || url.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Este documento no tiene un archivo asociado.'),
      ),
    );
    return;
  }
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => DocViewerScreen(url: url, titulo: titulo ?? 'Documento'),
      fullscreenDialog: true,
    ),
  );
}
