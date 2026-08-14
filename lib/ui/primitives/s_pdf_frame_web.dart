import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Visor de PDF en web: un `<iframe>` con el visor nativo del navegador.
///
/// NO se rasteriza nada del lado de Flutter. `pdfx` dibuja cada página en un
/// canvas y en web eso traba la pestaña varios segundos en documentos de varias
/// hojas; el navegador ya trae un visor con zoom, búsqueda e impresión que corre
/// fuera del hilo de la app.
///
/// El documento sigue DENTRO de la plataforma: es un embed, no una pestaña
/// nueva. Son documentos internos y sacar al usuario al navegador rompe el
/// contexto.
class SPdfFrame extends StatefulWidget {
  final String url;
  const SPdfFrame({super.key, required this.url});

  @override
  State<SPdfFrame> createState() => _SPdfFrameState();
}

class _SPdfFrameState extends State<SPdfFrame> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    // Un tipo de vista por URL: registrar dos veces el mismo id deja el primer
    // iframe pegado y el segundo documento nunca aparece.
    _viewType = 'pdf-${widget.url.hashCode}-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final el = web.document.createElement('iframe') as web.HTMLIFrameElement;
      el.src = widget.url;
      el.style
        ..border = 'none'
        ..width = '100%'
        ..height = '100%';
      return el;
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
