import 'package:url_launcher/url_launcher.dart';

/// Móvil/escritorio: no hay descarga con blob. Abre el archivo con el visor
/// externo del sistema (desde ahí el usuario puede guardarlo). Devuelve true
/// si se pudo abrir.
Future<bool> downloadFile(String url, String filename) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Móvil/escritorio: no hay descarga de bytes con blob (eso es propio del
/// navegador). Devuelve false para que quien la llame recurra a descargar los
/// archivos originales por su URL. La firma existe para paridad con la versión
/// web (importación condicional).
Future<bool> downloadBytes(
  List<int> bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) async {
  return false;
}
