import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Limite de tamano del backend (`MAX_FILE_BYTES` de `cliente-expediente`).
const int kMaxArchivoBytes = 10 * 1024 * 1024;

/// Firma de un PDF: los bytes `%PDF-` al inicio del archivo.
const List<int> _firmaPdf = [0x25, 0x50, 0x44, 0x46, 0x2d];

/// true si los bytes son realmente un PDF.
///
/// Se mira el CONTENIDO, no la extension del nombre: un `.jpg` renombrado a
/// `.pdf` pasa cualquier filtro por extension. El backend repite esta
/// comprobacion - esta de aqui solo evita el viaje y da respuesta inmediata.
bool esPdf(Uint8List bytes) {
  if (bytes.length <= _firmaPdf.length) return false;
  for (var i = 0; i < _firmaPdf.length; i++) {
    if (bytes[i] != _firmaPdf[i]) return false;
  }
  return true;
}

/// Motivo por el que el archivo no se puede mandar, o null si esta bien.
/// El texto se muestra tal cual al cliente.
String? motivoArchivoInvalido(Uint8List bytes) {
  if (bytes.isEmpty) {
    return 'El archivo está vacío. Elige otro.';
  }
  if (!esPdf(bytes)) {
    return 'El archivo no es un PDF. Vuelve a exportarlo o descargarlo en '
        'PDF y súbelo de nuevo.';
  }
  if (bytes.length > kMaxArchivoBytes) {
    return 'El archivo supera el límite de 10 MB.';
  }
  return null;
}

/// Abre el selector del sistema filtrado a PDF. Devuelve null si se cancelo.
Future<({String nombre, Uint8List bytes})?> abrirPdf() async {
  const grupo = XTypeGroup(
    label: 'PDF',
    extensions: ['pdf'],
    mimeTypes: ['application/pdf'],
  );
  final file = await openFile(acceptedTypeGroups: [grupo]);
  if (file == null) return null;
  return (nombre: file.name, bytes: await file.readAsBytes());
}
