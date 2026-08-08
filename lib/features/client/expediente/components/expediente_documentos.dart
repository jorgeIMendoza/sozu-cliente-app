import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/core/open_media.dart';
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
  /// key del slot cuya carga está en curso.
  String? _enCurso;

  // ── Flujo de carga ────────────────────────────────────────────────────────

  Future<void> _cargar(ExpedienteSlot slot) async {
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

    setState(() => _enCurso = slot.key);
    try {
      final subida = await ref
          .read(expedientePortProvider)
          .uploadDocument(
            typeId: res.tipoId,
            fileName: res.nombre,
            fileBase64: base64Encode(res.bytes),
            slotKey: slot.key,
            hash: _hashPorArchivo[res.nombre],
            fields: res.campos,
          );
      _refrescar();
      // Con el backend anterior la extracción ocurre AL SUBIR, no antes: lo que
      // detectó rellena solo lo que el cliente dejó vacío, nunca lo pisa.
      final campos = _mezclarDetectado(res.campos, subida);
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
  String _mensajeDe(ApiError e) => switch (e.code) {
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
          // Motivo del bloqueo del grupo del representante legal: se explica
          // una vez arriba, no en cada fila.
          if (grupo.owner == 'rep' && rep != null && rep.bloqueado) {
            hijos.add(SizedBox(height: context.s.space.xs));
            hijos.add(_AvisoBloqueo(motivo: rep.motivo));
          }
          hijos.add(SizedBox(height: context.s.space.xs));

          for (final slot in grupo.slots) {
            hijos.add(
              ExpedienteSlotRow(
                slot: slot,
                subiendo: _enCurso == slot.key,
                bloqueado: _enCurso != null,
                onSubir: () => _cargar(slot),
                onVer: slot.urlFirmada == null
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
                onAgregar: () => showCuentaBancariaSheet(context),
                onVer: cuentas.any((c) => c.evidencia != null)
                    ? widget.onVerCuentas
                    : null,
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
