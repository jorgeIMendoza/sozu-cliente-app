import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/expediente/services/archivo_pdf.dart';
import 'package:sozu_cliente_app/features/client/expediente/services/expediente_grupos.dart';

ClienteExpediente _exp(Map<String, dynamic> j) => ClienteExpediente.fromJson({
  'requeridos_total': 0,
  'requeridos_aprobados': 0,
  'subidos': 0,
  ...j,
});

Map<String, dynamic> _slot(
  String key,
  int tipoId, {
  String? grupo,
  String nombre = 'Documento',
}) => {
  'key': key,
  'tipo_id': tipoId,
  'nombre': nombre,
  'requerido': true,
  'estatus': 'pendiente',
  'puede_subir': true,
  'solo_pdf': true,
  if (grupo != null) 'grupo': grupo,
};

void main() {
  group('ExpedienteGrupos.construir', () {
    test('con grupos del backend respeta su orden y reparto', () {
      final exp = _exp({
        'tipo_persona': 'pm',
        'grupos': [
          {'key': 'empresa', 'titulo': 'Documentos de la empresa'},
          {
            'key': 'rep_legal',
            'titulo': 'Documentos representante legal',
            'owner': 'rep',
          },
        ],
        'slots': [
          _slot('acta_constitutiva', 7, grupo: 'empresa'),
          _slot('curp_rep', 5, grupo: 'rep_legal'),
          _slot('csf_empresa', 6, grupo: 'empresa'),
        ],
      });

      final grupos = ExpedienteGrupos.construir(exp);

      expect(grupos.map((g) => g.key), ['empresa', 'rep_legal']);
      expect(grupos[0].titulo, 'DOCUMENTOS DE LA EMPRESA');
      expect(grupos[0].slots.map((s) => s.key), [
        'acta_constitutiva',
        'csf_empresa',
      ]);
      expect(grupos[1].owner, 'rep');
      expect(grupos[1].slots.single.key, 'curp_rep');
      expect(exp.esMoral, isTrue);
    });

    test('sin grupos cae a los dos de persona fisica, alfabeticos', () {
      final exp = _exp({
        'slots': [
          _slot('curp', 5, nombre: 'CURP'),
          _slot('csf', 6, nombre: 'Constancia de situación fiscal'),
          _slot('acta_nacimiento', 1, nombre: 'Acta de nacimiento'),
        ],
      });

      final grupos = ExpedienteGrupos.construir(exp);

      expect(grupos.map((g) => g.key), ['personales', kGrupoFinanciero]);
      expect(grupos[0].slots.map((s) => s.key), ['acta_nacimiento', 'curp']);
      expect(grupos[1].slots.single.key, 'csf');
      // Sin `tipo_persona` el backend anterior se trata como persona fisica.
      expect(exp.esMoral, isFalse);
    });

    test('sin grupos, INE y pasaporte se funden en un solo slot', () {
      final exp = _exp({
        'slots': [
          _slot('ine_frente', 2, nombre: 'Frente INE'),
          _slot('ine_reverso', 3, nombre: 'Reverso INE'),
          _slot('pasaporte', 4, nombre: 'Pasaporte'),
          _slot('curp', 5, nombre: 'CURP'),
        ],
      });

      final personales = ExpedienteGrupos.construir(exp).first.slots;

      // Una sola fila de identidad: con una identificacion basta y ofrecer
      // tres deja dos vigentes.
      expect(personales.map((s) => s.key), ['curp', 'identificacion']);
      final identidad = personales.firstWhere((s) => s.key == 'identificacion');
      expect(identidad.nombre, 'Identificación oficial');
      expect(identidad.requerido, isTrue);
      expect(identidad.opciones.map((o) => o.tipoId), [
        TipoDoc.ineCompleto,
        TipoDoc.pasaporte,
      ]);
    });

    test('la identidad fundida hereda el documento ya aprobado', () {
      final exp = _exp({
        'slots': [
          {
            ..._slot('ine_frente', 2, nombre: 'Frente INE'),
            'estatus': 'aprobado',
            'fecha': '2026-07-29T00:00:00',
            'url_firmada': 'https://x/ine.pdf',
            'puede_subir': false,
          },
          _slot('pasaporte', 4, nombre: 'Pasaporte'),
        ],
      });

      final identidad = ExpedienteGrupos.construir(exp).first.slots.single;

      expect(identidad.estatus, 'aprobado');
      expect(identidad.urlFirmada, 'https://x/ine.pdf');
      expect(identidad.puedeSubir, isFalse);
    });

    test('el grupo financiero se conserva aunque no tenga documentos', () {
      final exp = _exp({
        'tipo_persona': 'pm',
        'grupos': [
          {'key': 'financiero', 'titulo': 'Documentos fiscal y financiero'},
        ],
        'slots': [_slot('acta_constitutiva', 7, grupo: 'empresa')],
      });

      final grupos = ExpedienteGrupos.construir(exp);

      expect(grupos.single.key, kGrupoFinanciero);
      expect(grupos.single.slots, isEmpty);
    });
  });

  group('notas del documento', () {
    test('la nota general va primero en todos', () {
      for (final tipo in [TipoDoc.csf, TipoDoc.pasaporte, TipoDoc.reformas]) {
        expect(
          ExpedienteGrupos.notasCompletas(tipo).first,
          ExpedienteGrupos.notaGeneral,
        );
      }
    });

    test('la identificacion pide frente y reverso en un solo PDF', () {
      expect(
        ExpedienteGrupos.notas(TipoDoc.ineCompleto).single,
        contains('frente y el reverso'),
      );
    });
  });

  group('archivo PDF', () {
    Uint8List bytes(List<int> b) => Uint8List.fromList(b);
    final pdf = bytes([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x37]);

    test('acepta un PDF real', () {
      expect(esPdf(pdf), isTrue);
      expect(motivoArchivoInvalido(pdf), isNull);
    });

    test('rechaza un JPEG aunque el nombre diga .pdf', () {
      // La extension del nombre no interviene: solo los bytes.
      final jpg = bytes([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46]);
      expect(esPdf(jpg), isFalse);
      expect(motivoArchivoInvalido(jpg), contains('no es un PDF'));
    });

    test('rechaza el archivo vacio y el que pasa de 10 MB', () {
      expect(motivoArchivoInvalido(bytes([])), contains('vacío'));
      final grande = Uint8List(kMaxArchivoBytes + 1)
        ..setRange(0, 5, [0x25, 0x50, 0x44, 0x46, 0x2d]);
      expect(motivoArchivoInvalido(grande), contains('10 MB'));
    });
  });
}
