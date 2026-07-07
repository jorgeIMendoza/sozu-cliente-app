import 'package:flutter/material.dart';

import '../screens/doc_viewer_screen.dart';

/// Abre un documento/imagen en el visor in-app (pantalla dentro de la app,
/// sin salir al navegador). Reemplaza a `openDoc` en los call sites de la UI.
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
