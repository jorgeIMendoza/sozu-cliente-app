import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/core/open_document.dart';
import 'package:sozu_cliente_app/features/client/facturacion/screens/doc_viewer_screen.dart';

/// Abre un documento o imagen.
///
/// En WEB va a una pestaña nueva, al visor del navegador. El visor in-app usa
/// `PdfViewPinch`, que rasteriza TODAS las páginas mientras el usuario lee: en
/// web eso traba la pestaña varios segundos y se come la pantalla completa por
/// un documento de una hoja. El navegador ya trae un visor con zoom, impresión
/// y descarga, y no cuesta un frame.
///
/// En móvil se queda el visor in-app: ahí salir al navegador saca al usuario de
/// la app y perder el contexto sí se nota.
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
  if (kIsWeb) {
    await openDoc(context, url);
    return;
  }
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => DocViewerScreen(url: url, titulo: titulo ?? 'Documento'),
      fullscreenDialog: true,
    ),
  );
}
