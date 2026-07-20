import 'package:url_launcher/url_launcher.dart';

/// Móvil/escritorio: no hay descarga con blob. Abre el archivo con el visor
/// externo del sistema (desde ahí el usuario puede guardarlo). Devuelve true
/// si se pudo abrir.
Future<bool> downloadFile(String url, String filename) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
