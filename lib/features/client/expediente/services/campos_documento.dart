import 'package:sozu_cliente_app/features/client/expediente/services/expediente_grupos.dart';

/// Campo que el cliente confirma o captura al subir un documento.
///
/// `tipo` es la clave que la hoja de carga traduce a su editor: texto | fecha |
/// curp | rfc | cp | sexo | regimen.
typedef CampoDoc = ({String key, String label, String tipo, bool requerido});

/// Qué datos alimenta cada documento del expediente.
///
/// Documento que NO aparece aquí es **solo evidencia**: se sube, se ve y ya. No
/// se le inventan campos al cliente (comprobante de domicilio, acta de
/// matrimonio, identificación oficial, y todos los de persona moral).
///
/// Qué es obligatorio sale de las mismas reglas que ya usa el back office
/// (`sozu-admin/src/utils/fiscalDataValidation.ts` → `isFiscalDataComplete`):
/// RFC, régimen, calle, colonia y código postal bloquean; los números exterior
/// e interior no. `personas.nombre_legal` es la única columna NOT NULL de las
/// que se tocan aquí (verificado contra producción el 2026-08-07).
abstract final class CamposDocumento {
  /// Acta de nacimiento y CURP alimentan la identidad de la persona.
  static const List<CampoDoc> _identidad = [
    (key: 'nombre', label: 'Nombre completo', tipo: 'texto', requerido: true),
    (key: 'curp', label: 'CURP', tipo: 'curp', requerido: true),
    (
      key: 'fecha_nacimiento',
      label: 'Fecha de nacimiento',
      tipo: 'fecha',
      requerido: true,
    ),
    (key: 'sexo', label: 'Sexo', tipo: 'sexo', requerido: true),
  ];

  /// La CSF alimenta los datos fiscales y el domicilio fiscal.
  static const List<CampoDoc> _fiscales = [
    (key: 'rfc', label: 'RFC', tipo: 'rfc', requerido: true),
    (
      key: 'nombre',
      label: 'Nombre o razón social',
      tipo: 'texto',
      requerido: true,
    ),
    (
      key: 'nombre_comercial',
      label: 'Nombre comercial',
      tipo: 'texto',
      requerido: false,
    ),
    (key: 'curp', label: 'CURP', tipo: 'curp', requerido: false),
    (key: 'regimen', label: 'Régimen fiscal', tipo: 'regimen', requerido: true),
    (key: 'codigo_postal', label: 'Código postal', tipo: 'cp', requerido: true),
    (key: 'calle', label: 'Calle', tipo: 'texto', requerido: true),
    (key: 'num_ext', label: 'Núm. exterior', tipo: 'texto', requerido: false),
    (key: 'num_int', label: 'Núm. interior', tipo: 'texto', requerido: false),
    (key: 'colonia', label: 'Colonia', tipo: 'texto', requerido: true),
  ];

  /// Campos del documento; lista vacía = solo evidencia.
  ///
  /// A una persona moral no se le pide CURP: no tiene. Y el acta de nacimiento
  /// y la CURP no son documentos suyos, así que no llegan aquí.
  static List<CampoDoc> de(int tipoId, {bool esMoral = false}) =>
      switch (tipoId) {
        TipoDoc.actaNacimiento ||
        TipoDoc.curp => esMoral ? const <CampoDoc>[] : _identidad,
        TipoDoc.csf =>
          esMoral
              ? [
                  for (final c in _fiscales)
                    if (c.key != 'curp') c,
                ]
              : _fiscales,
        _ => const [],
      };

  /// true si del documento sale información que el cliente debe confirmar.
  static bool extrae(int tipoId, {bool esMoral = false}) =>
      de(tipoId, esMoral: esMoral).isNotEmpty;
}
