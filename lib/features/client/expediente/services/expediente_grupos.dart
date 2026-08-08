import 'package:sozu_cliente_app/data/models.dart';

/// Un grupo del expediente listo para pintar: su titulo y sus documentos en el
/// orden en que van.
typedef GrupoExpediente = ({
  String key,
  String titulo,
  String owner,
  List<ExpedienteSlot> slots,
});

/// Clave del grupo que lleva la fila de cuenta bancaria. La cuenta NO es un
/// documento: la pinta la pantalla leyendo el perfil, no `cliente-expediente`.
const String kGrupoFinanciero = 'financiero';

/// Ids de `tipos_documento` que este expediente conoce. Verificados contra
/// produccion el 2026-08-07.
abstract final class TipoDoc {
  static const actaNacimiento = 1;
  static const ineFrente = 2;
  static const ineReverso = 3;
  static const pasaporte = 4;
  static const curp = 5;
  static const csf = 6;
  static const actaConstitutiva = 7;
  static const domicilio = 8;
  static const poderNotarial = 9;
  static const registroComercio = 10;
  static const actaMatrimonio = 11;
  static const reformas = 57;
  static const ineCompleto = 63;
}

/// Grupos del expediente y las instrucciones de cada documento.
///
/// El backend nuevo manda `grupos` y el `grupo` de cada slot; mientras no este
/// desplegado, aqui se arma la agrupacion de persona fisica que la pantalla
/// tenia antes, para que la vista no quede en una sola lista sin titulos.
abstract final class ExpedienteGrupos {
  /// Grupos del expediente en el orden en que se pintan.
  ///
  /// [esMoral] solo manda en el respaldo: cuando el backend manda `grupos`, es
  /// el backend quien ya decidio que se le pide a esta persona.
  static List<GrupoExpediente> construir(
    ClienteExpediente exp, {
    bool esMoral = false,
  }) {
    if (exp.grupos.isNotEmpty) {
      return [
        for (final g in exp.grupos)
          (
            key: g.key,
            titulo: g.titulo.toUpperCase(),
            owner: g.owner,
            slots: exp.slots.where((s) => s.grupo == g.key).toList(),
          ),
      ];
    }
    return (exp.esMoral || esMoral)
        ? _legacyMoral(exp.slots)
        : _legacy(exp.slots);
  }

  /// Motivo de los documentos de persona moral que la edge function actual no
  /// sabe recibir: su lista de tipos es la de persona fisica.
  static const String _noHabilitado =
      'Este documento todavía no se puede subir desde el portal. Envíaselo a '
      'tu asesor.';

  /// Motivo del grupo del representante legal: sus documentos son de OTRA
  /// persona y la edge function actual no resuelve el vinculo, asi que
  /// subirlos aqui los guardaria en la empresa.
  static const String _sinRepLegal =
      'Los documentos de tu representante legal todavía no se pueden subir '
      'desde el portal. Contacta a tu asesor.';

  /// Agrupacion de respaldo para PERSONA MORAL.
  ///
  /// A una empresa no se le piden acta de nacimiento, CURP ni acta de
  /// matrimonio; se le piden los suyos. Solo la CSF (6) y el comprobante de
  /// domicilio (8) llegan hoy a la persona correcta, asi que el resto se
  /// muestra pero bloqueado con su motivo: el cliente tiene que ver que su
  /// expediente esta incompleto y por que.
  static List<GrupoExpediente> _legacyMoral(List<ExpedienteSlot> slots) {
    ExpedienteSlot? deTipo(int t) {
      for (final s in slots) {
        if (s.tipoId == t) return s;
      }
      return null;
    }

    ExpedienteSlot renombrado(int tipoId, String key, String nombre) {
      final base = deTipo(tipoId);
      return ExpedienteSlot(
        key: key,
        tipoId: tipoId,
        nombre: nombre,
        estatus: base?.estatus ?? 'pendiente',
        requerido: true,
        fecha: base?.fecha,
        urlFirmada: base?.urlFirmada,
        puedeSubir: base?.puedeSubir ?? false,
        grupo: 'empresa',
      );
    }

    ExpedienteSlot bloqueado(
      int tipoId,
      String key,
      String nombre,
      String grupo,
      String motivo, {
      bool requerido = true,
    }) => ExpedienteSlot(
      key: key,
      tipoId: tipoId,
      nombre: nombre,
      estatus: 'pendiente',
      requerido: requerido,
      grupo: grupo,
      owner: grupo == 'rep_legal' ? 'rep' : 'self',
      puedeSubir: false,
      bloqueadoMotivo: motivo,
    );

    return [
      (
        key: 'empresa',
        titulo: 'DOCUMENTOS DE LA EMPRESA',
        owner: 'self',
        slots: [
          bloqueado(
            TipoDoc.actaConstitutiva,
            'acta_constitutiva',
            'Acta constitutiva',
            'empresa',
            _noHabilitado,
          ),
          renombrado(
            TipoDoc.domicilio,
            'domicilio_fiscal',
            'Comprobante de domicilio fiscal',
          ),
          renombrado(
            TipoDoc.csf,
            'csf_empresa',
            'Constancia de situación fiscal',
          ),
          bloqueado(
            TipoDoc.reformas,
            'reformas',
            'Reformas / protocolizaciones',
            'empresa',
            _noHabilitado,
            requerido: false,
          ),
          bloqueado(
            TipoDoc.registroComercio,
            'registro_comercio',
            'Registro público de comercio',
            'empresa',
            _noHabilitado,
          ),
        ],
      ),
      (
        key: 'rep_legal',
        titulo: 'DOCUMENTOS REPRESENTANTE LEGAL',
        owner: 'rep',
        slots: [
          bloqueado(
            TipoDoc.domicilio,
            'domicilio_rep',
            'Comprobante de domicilio',
            'rep_legal',
            _sinRepLegal,
          ),
          bloqueado(
            TipoDoc.csf,
            'csf_rep',
            'Constancia de situación fiscal',
            'rep_legal',
            _sinRepLegal,
          ),
          bloqueado(
            TipoDoc.curp,
            'curp_rep',
            'CURP',
            'rep_legal',
            _sinRepLegal,
          ),
          bloqueado(
            TipoDoc.ineCompleto,
            'identificacion_rep',
            'Identificación oficial',
            'rep_legal',
            _sinRepLegal,
          ),
          bloqueado(
            TipoDoc.poderNotarial,
            'poder_notarial',
            'Poder notarial',
            'rep_legal',
            _sinRepLegal,
          ),
        ],
      ),
      (
        key: kGrupoFinanciero,
        titulo: 'DOCUMENTOS FISCAL Y FINANCIERO',
        owner: 'self',
        slots: const [],
      ),
    ];
  }

  /// Tipos que satisfacen la identificacion oficial: INE completo, pasaporte y
  /// el par frente/reverso ya deprecado.
  static const List<int> tiposIdentidad = [
    TipoDoc.ineCompleto,
    TipoDoc.pasaporte,
    TipoDoc.ineFrente,
    TipoDoc.ineReverso,
  ];

  /// Las dos formas vigentes de acreditar la identidad. Se sube UNA.
  static const List<ExpedienteOpcion> opcionesIdentidad = [
    (tipoId: TipoDoc.ineCompleto, label: 'INE'),
    (tipoId: TipoDoc.pasaporte, label: 'Pasaporte'),
  ];

  /// Funde INE frente, INE reverso y pasaporte en un solo slot
  /// "Identificacion oficial" con las dos opciones.
  ///
  /// Con una identificacion basta, asi que ofrecer tres filas hace que el
  /// cliente suba de mas y deja dos identificaciones vigentes: verificacion no
  /// sabe cual manda. El backend nuevo ya manda el slot fusionado; esto es el
  /// respaldo mientras no este desplegado.
  static List<ExpedienteSlot> _fusionarIdentidad(List<ExpedienteSlot> slots) {
    final identidad = slots.where((s) => tiposIdentidad.contains(s.tipoId));
    if (identidad.isEmpty) return slots;

    // El que manda: aprobado > en revision > el mas reciente con documento.
    ExpedienteSlot? mejor;
    for (final s in identidad) {
      if (s.estatus == 'aprobado') {
        mejor = s;
        break;
      }
      if (s.estatus == 'revision') {
        mejor ??= s;
      } else if (mejor == null && s.fecha != null) {
        mejor = s;
      }
    }
    final base = mejor ?? identidad.first;
    final resuelto = base.fecha != null;

    return [
      ExpedienteSlot(
        key: 'identificacion',
        // Por defecto el canal vigente (INE completo); el cliente elige cual.
        tipoId: TipoDoc.ineCompleto,
        nombre: 'Identificación oficial',
        estatus: resuelto ? base.estatus : 'pendiente',
        requerido: true,
        fecha: base.fecha,
        urlFirmada: base.urlFirmada,
        puedeSubir: !resuelto || base.puedeSubir,
        grupo: 'personales',
        opciones: opcionesIdentidad,
      ),
      ...slots.where((s) => !tiposIdentidad.contains(s.tipoId)),
    ];
  }

  /// Agrupacion de respaldo: los slots planos del backend anterior, todos de
  /// persona fisica, ordenados alfabeticamente como los pintaba el portal.
  static List<GrupoExpediente> _legacy(List<ExpedienteSlot> planos) {
    final slots = _fusionarIdentidad(planos);
    List<ExpedienteSlot> de(bool Function(ExpedienteSlot) test) =>
        slots.where(test).toList()..sort(
          (a, b) => _sinAcentos(a.nombre).compareTo(_sinAcentos(b.nombre)),
        );

    final financieros = de((s) => s.tipoId == TipoDoc.csf);
    return [
      (
        key: 'personales',
        titulo: 'DOCUMENTOS PERSONALES',
        owner: 'self',
        slots: de((s) => s.tipoId != TipoDoc.csf),
      ),
      (
        key: kGrupoFinanciero,
        titulo: 'DOCUMENTOS FISCAL Y FINANCIERO',
        owner: 'self',
        slots: financieros,
      ),
    ];
  }

  /// Minusculas sin acentos, para ordenar como `localeCompare('es')`.
  static String _sinAcentos(String s) => s.toLowerCase().replaceAllMapped(
    RegExp('[áàäâéèëêíìïîóòöôúùüûñ]'),
    (m) => const {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    }[m[0]]!,
  );

  /// Instruccion que aplica a TODOS los documentos. Va a la vista, no a un
  /// tooltip: se tiene que leer antes de elegir el archivo.
  static const String notaGeneral =
      'Sube el archivo en PDF y legible; de lo contrario puede ser rechazado '
      'y tendrás que subirlo otra vez.';

  /// Instrucciones propias del documento, sobre [notaGeneral].
  static List<String> notas(int tipoId) => switch (tipoId) {
    TipoDoc.ineCompleto || TipoDoc.ineFrente || TipoDoc.ineReverso => const [
      'Un solo PDF con el frente y el reverso escaneados completos, en buen '
          'tamaño y sin recortes.',
    ],
    TipoDoc.pasaporte => const [
      'La hoja de datos del pasaporte (foto y datos), completa y legible.',
    ],
    TipoDoc.csf => const [
      'Descárgala del portal del SAT. No se acepta si tiene más de 3 meses.',
    ],
    TipoDoc.curp => const [
      'Descárgala de gob.mx/curp. No se acepta si tiene más de 3 meses.',
    ],
    TipoDoc.domicilio => const [
      'Recibo de luz, agua, teléfono o estado de cuenta bancario.',
      'No se acepta si tiene más de 3 meses.',
    ],
    TipoDoc.actaNacimiento => const [
      'El acta digital oficial en PDF. Si subes un escaneo, se acepta pero '
          'queda en revisión manual.',
    ],
    _ => const [],
  };

  /// Todas las instrucciones del documento, la general primero.
  static List<String> notasCompletas(int tipoId) => [
    notaGeneral,
    ...notas(tipoId),
  ];
}
