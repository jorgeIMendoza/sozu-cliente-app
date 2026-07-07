import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre un documento (PDF/imagen) para ver/descargar.
/// Móvil: navegador in-app; Web: nueva pestaña.
Future<void> openDoc(BuildContext context, String? url) async {
  if (url == null || url.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Este documento no tiene un archivo asociado.'),
      ));
    }
    return;
  }
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final ok = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('No se pudo abrir el documento.'),
    ));
  }
}
