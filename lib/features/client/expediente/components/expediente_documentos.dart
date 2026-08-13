import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/core/open_media.dart';
import 'package:sozu_cliente_app/core/version.dart' show isPreviewBuild;
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/expediente/components/cuenta_bancaria_row.dart';
import 'package:sozu_cliente_app/features/client/expediente/components/expediente_slot_row.dart';
import 'package:sozu_cliente_app/features/client/expediente/ports/expediente_port.dart';
import 'package:sozu_cliente_app/features/client/expediente/providers/expediente_providers.dart';
import 'package:sozu_cliente_app/features/client/expediente/services/archivo_pdf.dart';
import 'package:sozu_cliente_app/features/client/expediente/services/campos_documento.dart';
import 'package:sozu_cliente_app/features/client/expediente/services/expediente_grupos.dart';
import 'package:sozu_cliente_app/features/client/profile/components/perfil_sheets.dart'
    show showCuentaBancariaSheet;
import 'package:sozu_cliente_app/features/client/profile/providers/profile_providers.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Lista de documentos del expediente y todo el flujo de carga:
/// elegir archivo → analizar → revisar los datos extraídos → subir.
///
/// La pantalla solo compone; el estado de la subida vive aquí.
class ExpedienteDocumentos extends ConsumerStatefulWidget {
  /// Abre la vista de cuentas bancarias del perfil.
  final VoidCallback onVerCuentas;

  const ExpedienteDocumentos({super.key, required this.onVerCuentas});

  @override
  ConsumerState<ExpedienteDocumentos> createState() =>
      _ExpedienteDocumentosState();
}

class _ExpedienteDocumentosState extends ConsumerState<ExpedienteDocumentos> {
  /// Fila cuya carga está en curso, por [_filaKey].
  String? _enCurso;

  /// Campo con el que se pide la descripción de un anexo. No es un dato del
  /// perfil: viaja aparte, en `descripcion`.
  static const _campoDescripcion = 'descripcion';

  /// Identidad de una FILA, no de un slot: un slot múltiple pinta una fila por
  /// anexo y cada una gira su propio indicador.
  static String _filaKey(ExpedienteSlot slot, int? docId) =>
      docId == null ? slot.key : '${slot.key}#$docId';

  /// Motivo que comparten TODOS los slots del grupo, o null. Cuando lo
  /// comparten es del grupo entero y se explica una vez, no fila por fila.
  static String? _motivoComun(List<ExpedienteSlot> slots) {
    if (slots.isEmpty) return null;
    final motivo = slots.first.bloqueadoMotivo;
    if (motivo == null) return null;
    return slots.every((s) => s.bloqueadoMotivo == motivo) ? motivo : null;
  }

  /// Fila de un anexo ya subido: su propio estatus, fecha y archivo.
  static ExpedienteSlot _filaDeAnexo(ExpedienteSlot slot, ExpedienteAnexo a) =>
      ExpedienteSlot(
        key: _filaKey(slot, a.id),
        tipoId: slot.tipoId,
        // La descripción ES el nombre de la fila: es lo que distingue este
        // anexo de los demás. Sin ella queda el del slot, que se repite.
        nombre: a.descripcion ?? slot.nombre,
        estatus: a.estatus,
        fecha: a.fecha,
        urlFirmada: a.urlFirmada,
        puedeSubir: slot.puedeSubir,
        grupo: slot.grupo,
        owner: slot.owner,
      );

  /// Fila para agregar OTRO anexo: nunca muestra uno existente, así que va sin
  /// fecha y con el texto de agregar.
  static ExpedienteSlot _filaDeAgregar(ExpedienteSlot slot) => ExpedienteSlot(
    key: slot.key,
    tipoId: slot.tipoId,
    nombre: slot.documentos.isEmpty ? slot.nombre : 'Agregar otro documento',
    estatus: 'opcional',
    puedeSubir: slot.puedeSubir,
    grupo: slot.grupo,
    owner: slot.owner,
    nota: slot.nota,
  );

  // ── Flujo de carga ────────────────────────────────────────────────────────

  /// [docId] reemplaza un anexo concreto de un slot múltiple; sin él, un slot
  /// múltiple agrega uno nuevo.
  Future<void> _cargar(ExpedienteSlot slot, {int? docId}) async {
    final res = await showSDocUpload(
      context,
      titulo: slot.nombre,
      descripcion: slot.opciones.isNotEmpty
          ? 'Elige el tipo de documento, adjunta el PDF y revísalo antes de '
                'guardar'
          : 'Adjunta el PDF y revísalo antes de guardar',
      tipos: [for (final o in slot.opciones) (value: o.tipoId, label: o.label)],
      tipoId: slot.tipoId,
      onSeleccionar: abrirPdf,
      validar: motivoArchivoInvalido,
      onAnalizar: (tipo, nombre, bytes) => _analizar(slot, tipo, nombre, bytes),
      condiciones: ExpedienteGrupos.notasCompletas,
    );
    if (res == null || !mounted) return;

    setState(() => _enCurso = _filaKey(slot, docId));
    try {
      // La descripción del anexo NO es un campo del perfil: viaja aparte, y por
      // eso sale del mapa antes de mandarlo.
      final delPerfil = Map<String, String>.from(res.campos);
      final descripcion = delPerfil.remove(_campoDescripcion);
      final subida = await ref
          .read(expedientePortProvider)
          .uploadDocument(
            typeId: res.tipoId,
            fileName: res.nombre,
            fileBase64: base64Encode(res.bytes),
            slotKey: slot.key,
            hash: _hashPorArchivo[res.nombre],
            fields: delPerfil,
            docId: docId,
            descripcion: descripcion,
          );
      _refrescar();
      // Con el backend anterior la extracción ocurre AL SUBIR, no antes: lo que
      // detectó rellena solo lo que el cliente dejó vacío, nunca lo pisa.
      final campos = _mezclarDetectado(delPerfil, subida);
      if (campos.isNotEmpty) await _guardarEnPerfil(campos);
      _aviso(
        subida.estatus == 'aprobado'
            ? 'Documento verificado y aprobado'
            : 'Documento enviado para revisión',
      );
    } on DocumentoInvalidoError catch (e) {
      _aviso(e.reason, error: true);
    } on ApiError catch (e) {
      _aviso(_mensajeDe(e), error: true);
    } catch (_) {
      _aviso('No se pudo subir el documento. Intenta de nuevo.', error: true);
    } finally {
      if (mounted) setState(() => _enCurso = null);
    }
  }

  /// Persona moral: cambia qué documentos se piden y qué datos aplican.
  bool get _esMoral => ref.read(profileProvider).valueOrNull?.esMoral ?? false;

  /// Hash que devolvió `analizar`, por nombre de archivo: viaja de vuelta en
  /// `subir` para que el backend confirme que guarda lo que se revisó.
  final _hashPorArchivo = <String, String>{};

  /// Qué campos pedir para este archivo. Con el backend nuevo salen del
  /// análisis; con el anterior salen del catálogo, vacíos, porque no hay forma
  /// de leer el PDF sin guardarlo antes.
  Future<SDocAnalisis> _analizar(
    ExpedienteSlot slot,
    int tipoId,
    String nombre,
    Uint8List bytes,
  ) async {
    // Un anexo no se analiza: no hay nada que extraerle. Lo único que se le
    // pide es cómo llamarlo, porque es lo que lo distingue de los otros.
    if (slot.multiple) {
      return (
        campos: const [
          SDocFieldSpec(
            key: _campoDescripcion,
            label: 'Descripción',
            requerido: true,
            ayuda:
                'Cómo distinguirlo de los demás anexos. Ej: "Reforma de '
                'estatutos 2024".',
          ),
        ],
        aviso: null,
        tono: SDocTone.info,
        rechazo: null,
      );
    }

    final delCatalogo = CamposDocumento.de(tipoId, esMoral: _esMoral);
    final analisis = await ref
        .read(expedientePortProvider)
        .analyzeDocument(
          slotKey: slot.key,
          typeId: tipoId,
          fileName: nombre,
          fileBase64: base64Encode(bytes),
        );

    if (analisis == null) {
      // Backend anterior: sin acción `analizar`.
      return (
        campos: [for (final c in delCatalogo) _delCatalogo(c)],
        aviso: delCatalogo.isEmpty
            ? null
            : 'Captura tus datos para continuar: no pudimos leerlos del '
                  'archivo. Verifica que sean correctos, se guardarán en tu '
                  'perfil.',
        tono: SDocTone.warning,
        rechazo: null,
      );
    }
    if (analisis.hash != null) _hashPorArchivo[nombre] = analisis.hash!;
    if (analisis.rechazado) {
      return (
        campos: const <SDocFieldSpec>[],
        aviso: null,
        tono: SDocTone.warning,
        rechazo: analisis.motivo ?? 'El documento no procede. Elige otro.',
      );
    }
    // `sin_texto` cubre DOS casos del backend (no se pudo leer el PDF, y no
    // corresponde al documento) y en los dos manda `campos: []`. Los campos
    // salen entonces del catálogo: sin ellos el cliente guardaría un documento
    // en revisión sin un solo dato, que es justo lo que se quería evitar.
    final campos = analisis.campos.isNotEmpty
        ? analisis.campos.map(_aCampo).toList()
        : [for (final c in delCatalogo) _delCatalogo(c)];

    return (
      campos: campos,
      // El porqué lo redacta el backend y viaja en `motivo`; aquí solo se le
      // pega qué tiene que hacer el cliente.
      aviso: analisis.sinTexto
          ? [
              if (analisis.motivo != null) analisis.motivo!,
              campos.isEmpty
                  ? 'El documento se acepta, pero quedará en revisión manual.'
                  : 'Captura tus datos para continuar; el documento quedará '
                        'en revisión manual.',
            ].join(' ')
          : null,
      tono: analisis.sinTexto ? SDocTone.warning : SDocTone.info,
      rechazo: null,
    );
  }

  /// Campo del catálogo, sin valor: lo captura el cliente.
  SDocFieldSpec _delCatalogo(CampoDoc c) => SDocFieldSpec(
    key: c.key,
    label: c.label,
    requerido: c.requerido,
    kind: _kind(c.tipo),
  );

  /// Campo que el backend ya extrajo.
  SDocFieldSpec _aCampo(CampoExtraido c) => SDocFieldSpec(
    key: c.key,
    label: c.label,
    valor: c.key == 'nombre' ? toTitleCaseEs(c.valor) : c.valor,
    requerido: c.requerido,
    soloLectura: c.soloLectura,
    ayuda: c.ayuda,
    kind: _kind(c.tipo),
    opciones: c.opciones,
  );

  static SDocFieldKind _kind(String tipo) => switch (tipo) {
    'fecha' => SDocFieldKind.fecha,
    'curp' => SDocFieldKind.curp,
    'rfc' => SDocFieldKind.rfc,
    'cp' => SDocFieldKind.cp,
    'sexo' => SDocFieldKind.sexo,
    'regimen' => SDocFieldKind.catalogo,
    _ => SDocFieldKind.texto,
  };

  /// Rellena con lo que el backend detectó AL SUBIR solo las claves que el
  /// cliente dejó vacías. Lo que él escribió manda.
  Map<String, String> _mezclarDetectado(
    Map<String, String> campos,
    ExpedienteUpload res,
  ) {
    final out = Map<String, String>.from(campos);
    void poner(String k, String? v) {
      final s = v?.trim();
      if (s != null && s.isNotEmpty && (out[k] ?? '').isEmpty) out[k] = s;
    }

    final f = res.datosFiscales;
    if (f != null) {
      poner('rfc', f.rfc);
      poner('curp', f.curp);
      poner('nombre', toTitleCaseEs(f.nombre));
      poner('regimen', f.regimen);
      poner('codigo_postal', f.codigoPostal);
      poner('calle', f.calle);
      poner('num_ext', f.numExt);
      poner('num_int', f.numInt);
      poner('colonia', f.colonia);
    }
    final c = res.datosCurp;
    final a = res.datosActa;
    if (c != null || a != null) {
      poner('curp', c?.curp ?? a?.curp);
      poner('nombre', toTitleCaseEs(c?.nombre ?? a?.nombre));
      poner('fecha_nacimiento', c?.fechaNacimiento ?? a?.fechaNacimiento);
      poner('sexo', c?.sexo ?? a?.sexo);
    }
    return out;
  }

  /// Guarda en el perfil los datos confirmados. Campo vacío = no se toca la
  /// columna: una extracción incompleta no debe borrar lo que ya estaba.
  Future<void> _guardarEnPerfil(Map<String, String> campos) async {
    try {
      final p = ref.read(profileProvider).valueOrNull;
      final port = ref.read(profilePortProvider);
      String? v(String k) {
        final s = campos[k]?.trim();
        return (s == null || s.isEmpty) ? null : s;
      }

      await port.updatePersonalData(
        legalName: v('nombre') ?? p?.nombreLegal ?? '',
        rfc: v('rfc') ?? p?.rfc,
        curp: v('curp') ?? p?.curp,
        phoneCountryCode: p?.clavePaisTelefono,
        phone: p?.telefono,
        occupation: p?.ocupacion,
      );
      if (campos.keys.any(_esCampoFiscal)) {
        await port.updateTaxData(
          regime: v('regimen') ?? p?.regimen,
          cfdiUse: p?.usoCfdi,
          postalCode: v('codigo_postal') ?? p?.cp ?? '',
          street: v('calle') ?? p?.calle ?? '',
          exteriorNumber: v('num_ext') ?? p?.numExt ?? '',
          interiorNumber: v('num_int') ?? p?.numInt ?? '',
          neighborhood: v('colonia') ?? p?.colonia ?? '',
        );
      }
      ref.invalidate(profileProvider);
    } catch (_) {
      _aviso(
        'El documento se subió, pero no pudimos guardar los datos en tu '
        'perfil. Revísalos desde Perfil.',
        error: true,
      );
    }
  }

  static bool _esCampoFiscal(String k) => const {
    'regimen',
    'codigo_postal',
    'calle',
    'num_ext',
    'num_int',
    'colonia',
  }.contains(k);

  /// Qué decirle al cliente por cada fallo del backend.
  ///
  /// El código va en el texto cuando NO se reconoce: un "intenta de nuevo"
  /// pelón deja al cliente atorado y a quien depura sin nada que buscar en los
  /// logs. Los códigos son los de `cliente-expediente`.
  /// En build de preview el codigo viaja SIEMPRE en el texto: un 400 puede ser
  /// cuatro cosas distintas y el mensaje las une, asi que sin esto diagnosticar
  /// desde un reporte obliga a abrir DevTools.
  String _mensajeDe(ApiError e) =>
      isPreviewBuild ? '${_textoDe(e)} [${e.status} ${e.code}]' : _textoDe(e);

  String _textoDe(ApiError e) => switch (e.code) {
    'slot_invalido' =>
      'Ese documento ya no está en tu expediente. Recarga la página e intenta '
          'de nuevo.',
    'tipo_invalido' =>
      'El tipo de documento que elegiste no corresponde a este requisito.',
    'archivo_requerido' => 'No llegó el archivo. Vuelve a seleccionarlo.',
    'archivo_invalido' => 'No pudimos leer el archivo. Vuelve a seleccionarlo.',
    'archivo_demasiado_grande' => 'El archivo supera el límite de 10 MB.',
    'slot_no_subible' =>
      'Este documento ya está cargado y en revisión. No hace falta subirlo '
          'otra vez.',
    'archivo_no_coincide' =>
      'El archivo cambió después de revisarlo. Vuelve a seleccionarlo.',
    'network_error' =>
      'No pudimos conectar. Revisa tu conexión e intenta de nuevo.',
    _ => 'No se pudo subir el documento (${e.code}). Intenta de nuevo.',
  };

  void _refrescar() => ref.invalidate(identityFileProvider);

  void _aviso(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: Duration(seconds: error ? 7 : 4),
      ),
    );
  }

  // ── Render ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final exp = ref.watch(identityFileProvider);
    final cuentas =
        ref.watch(profileProvider).valueOrNull?.cuentasBancarias ??
        const <CuentaBancariaPerfil>[];

    return exp.when(
      loading: () => const Column(
        children: [
          SSkeleton(height: 56),
          SizedBox(height: 10),
          SSkeleton(height: 56),
          SizedBox(height: 10),
          SSkeleton(height: 56),
        ],
      ),
      error: (_, __) => SErrorState(
        title: 'No pudimos cargar tu expediente',
        onRetry: _refrescar,
      ),
      data: (data) {
        if (data.slots.isEmpty) {
          return const SEmptyState.card(
            icon: Icons.folder_open_outlined,
            title: 'Aún no hay documentos configurados en tu expediente.',
          );
        }

        final grupos = ExpedienteGrupos.construir(
          data,
          esMoral: ref.watch(profileProvider).valueOrNull?.esMoral ?? false,
        );
        final rep = data.repLegal;
        final hijos = <Widget>[];

        for (var g = 0; g < grupos.length; g++) {
          final grupo = grupos[g];
          final esFinanciero = grupo.key == kGrupoFinanciero;
          if (grupo.slots.isEmpty && !esFinanciero) continue;
          if (hijos.isNotEmpty) hijos.add(SizedBox(height: context.s.space.lg));

          hijos.add(_Encabezado(titulo: grupo.titulo));
          // Motivo del bloqueo de un grupo entero (representante legal o
          // accionista sin ligar): se explica una vez arriba, no en cada fila.
          final motivoGrupo =
              grupo.owner == 'rep' && rep != null && rep.bloqueado
              ? rep.motivo
              : _motivoComun(grupo.slots);
          if (motivoGrupo != null) {
            hijos.add(SizedBox(height: context.s.space.xs));
            hijos.add(_AvisoBloqueo(motivo: motivoGrupo));
          }
          hijos.add(SizedBox(height: context.s.space.xs));

          for (final slot in grupo.slots) {
            // Un slot múltiple son varias filas: una por anexo ya subido, más
            // la de agregar otro. Reemplazar dentro de una fila solo toca ese
            // anexo; los demás siguen vigentes.
            if (slot.multiple) {
              for (final anexo in slot.documentos) {
                hijos.add(
                  ExpedienteSlotRow(
                    slot: _filaDeAnexo(slot, anexo),
                    subiendo: _enCurso == _filaKey(slot, anexo.id),
                    bloqueado: _enCurso != null,
                    onSubir: () => _cargar(slot, docId: anexo.id),
                    onVer: anexo.urlFirmada == null
                        ? null
                        : () => openMedia(
                            context,
                            anexo.urlFirmada,
                            titulo: slot.nombre,
                          ),
                  ),
                );
                hijos.add(SizedBox(height: context.s.space.xs));
              }
            }

            hijos.add(
              ExpedienteSlotRow(
                slot: slot.multiple ? _filaDeAgregar(slot) : slot,
                subiendo: _enCurso == slot.key,
                bloqueado: _enCurso != null,
                onSubir: () => _cargar(slot),
                onVer: slot.multiple || slot.urlFirmada == null
                    ? null
                    : () => openMedia(
                        context,
                        slot.urlFirmada,
                        titulo: slot.nombre,
                      ),
              ),
            );
            hijos.add(SizedBox(height: context.s.space.xs));
          }

          if (esFinanciero) {
            hijos.add(
              CuentaBancariaRow(
                cuentas: cuentas,
                // Con una cuenta ya registrada el botón EDITA esa, no abre un
                // alta en blanco: sin esto cada corrección creaba una cuenta
                // más y el cliente terminaba con duplicados. Con varias, la
                // lista es el único sitio donde se puede elegir cuál.
                onAgregar: () => cuentas.length == 1
                    ? showCuentaBancariaSheet(context, cuenta: cuentas.single)
                    : cuentas.isEmpty
                    ? showCuentaBancariaSheet(context)
                    : widget.onVerCuentas(),
                onVer: cuentas.isEmpty ? null : widget.onVerCuentas,
              ),
            );
          } else if (hijos.isNotEmpty) {
            hijos.removeLast(); // separador sobrante tras el último documento
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: hijos,
        );
      },
    );
  }
}

class _Encabezado extends StatelessWidget {
  final String titulo;
  const _Encabezado({required this.titulo});

  @override
  Widget build(BuildContext context) => Text(
    titulo,
    style: context.s.text.overline.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: context.s.color.fgSubtle,
    ),
  );
}

/// Por qué un grupo entero está deshabilitado (persona moral sin
/// representante legal ligado). El grupo se muestra igual: el cliente tiene
/// que ver que su expediente está incompleto y por qué.
class _AvisoBloqueo extends StatelessWidget {
  final String? motivo;
  const _AvisoBloqueo({required this.motivo});

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Container(
      padding: EdgeInsets.all(context.s.space.sm),
      decoration: BoxDecoration(
        color: tone.warningSoft,
        borderRadius: context.s.radius.mdBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: tone.warningFg),
          SizedBox(width: context.s.space.xs),
          Expanded(
            child: Text(
              motivo ??
                  'Aún no tenemos registrado a tu representante legal. '
                      'Contacta a tu asesor para subir sus documentos.',
              style: context.s.text.caption.copyWith(color: tone.fg),
            ),
          ),
        ],
      ),
    );
  }
}
