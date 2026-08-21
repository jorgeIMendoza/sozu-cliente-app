import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/shared/components/doc_viewer.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

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
  // En escritorio es una MODAL con tope de tamaño: se ve el portal detrás y se
  // entiende que es una capa, no otra pantalla. A pantalla completa parecía que
  // la app había navegado a otro sitio.
  if (context.bp.hasTwoColumns) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ctx.s.space.xl,
          vertical: ctx.s.space.lg,
        ),
        shape: RoundedRectangleBorder(borderRadius: ctx.s.radius.lgBorder),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: DocViewer(url: url, titulo: titulo ?? 'Documento'),
        ),
      ),
    );
    return;
  }
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => DocViewer(url: url, titulo: titulo ?? 'Documento'),
      fullscreenDialog: true,
    ),
  );
}
