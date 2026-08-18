import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sozu_cliente_app/ui/primitives/s_confirm_dialog.dart';
import 'package:sozu_cliente_app/ui/primitives/s_drop_zone.dart';
import 'package:sozu_cliente_app/ui/primitives/s_field_label.dart';
import 'package:sozu_cliente_app/ui/primitives/s_form_sheet.dart';
import 'package:sozu_cliente_app/ui/primitives/s_pdf_preview.dart';
import 'package:sozu_cliente_app/ui/primitives/s_select_field.dart';
import 'package:sozu_cliente_app/ui/primitives/s_text_field.dart';
import 'package:sozu_cliente_app/ui/theme/breakpoints.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';

/// Naturaleza de un campo a capturar. Gobierna teclado, formato y validación.
enum SDocFieldKind {
  texto,

  /// DD/MM/AAAA.
  fecha,
  curp,
  rfc,

  /// Código postal de 5 dígitos.
  cp,

  /// Hombre / Mujer. El valor que sale es `H` o `M`, como lo codifica la CURP;
  /// el backend lo convierte al `M`/`F` de la base.
  sexo,

  /// Valor de un catálogo cerrado ([SDocFieldSpec.opciones]).
  catalogo,
}

/// Un dato del documento que el usuario confirma o captura.
@immutable
class SDocFieldSpec {
  /// Identificador con el que sale el valor en el mapa de resultado.
  final String key;
  final String label;

  /// Lo detectado. `null` cuando no se pudo extraer: el usuario lo escribe.
  final String? valor;

  /// Sin él no se puede guardar.
  final bool requerido;

  /// Se muestra pero no se edita ni se guarda (dato sin destino todavía).
  final bool soloLectura;

  /// Nota bajo el campo.
  final String? ayuda;
  final SDocFieldKind kind;

  /// Valores admitidos cuando [kind] es [SDocFieldKind.catalogo].
  final List<({String id, String nombre})> opciones;

  const SDocFieldSpec({
    required this.key,
    required this.label,
    this.valor,
    this.requerido = false,
    this.soloLectura = false,
    this.ayuda,
    this.kind = SDocFieldKind.texto,
    this.opciones = const [],
  });
}

/// Peso del aviso que encabeza los campos.
enum SDocTone { info, warning }

/// Veredicto del archivo, que entrega quien abre la hoja.
///
/// - [rechazo] no vacío: el archivo no procede y no se puede guardar.
/// - [campos] vacío: el documento es solo evidencia, no hay nada que capturar.
/// - campos con `valor` nulo: no se pudo extraer y los escribe el usuario.
typedef SDocAnalisis = ({
  List<SDocFieldSpec> campos,
  String? aviso,
  SDocTone tono,
  String? rechazo,
});

/// Lo que devuelve la hoja al guardar.
typedef SDocUploadResult = ({
  int tipoId,
  String nombre,
  Uint8List bytes,
  Map<String, String> campos,
});

final _reCurp = RegExp(
  r'^[A-Z]{4}\d{6}[HM][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[0-9A-Z]\d$',
);
final _reRfc = RegExp(r'^[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}$');
final _reFecha = RegExp(r'^\d{2}/\d{2}/\d{4}$');
final _reCp = RegExp(r'^\d{5}$');

/// Carga de un documento: elegir el tipo, adjuntar el PDF, verlo, y confirmar
/// o capturar los datos que salen de él. Todo en una hoja.
///
/// Es el componente global de "sube esto y confírmame lo que dice": sirve para
/// el expediente, para la carátula bancaria y para cualquier otro documento.
/// Es tonto - la extracción, la validación de negocio y la subida las hace
/// quien lo abre, a través de [onAnalizar] y del resultado.
///
/// Antes de adjuntar, la zona de carga ocupa el centro de la hoja; al adjuntar
/// se encoge a una línea y su lugar lo toman los campos.
///
/// Devuelve el archivo con los valores confirmados, o `null` si se canceló.
/// En escritorio, `Esc` cancela.
Future<SDocUploadResult?> showSDocUpload(
  BuildContext context, {
  required String titulo,
  String? descripcion,

  /// Documentos alternos entre los que se elige uno (INE o pasaporte). Vacío
  /// cuando solo hay uno, y entonces manda [tipoId].
  List<SSelectOption<int>> tipos = const [],
  int? tipoId,

  /// Abre el selector del sistema.
  required Future<({String nombre, Uint8List bytes})?> Function() onSeleccionar,

  /// Rechazo inmediato del archivo (no es PDF, pesa de más). Null = está bien.
  String? Function(Uint8List bytes)? validar,

  /// Analiza el archivo y dice qué campos pedir. Sin esto, el documento es
  /// solo evidencia.
  Future<SDocAnalisis> Function(int tipoId, String nombre, Uint8List bytes)?
  onAnalizar,

  /// Condiciones que se aceptan al guardar. Vacío las omite.
  List<String> Function(int tipoId)? condiciones,

  /// Cómo se previsualiza el archivo adjunto. Por defecto [SPdfPreview]; se
  /// cambia cuando el documento no siempre es PDF (una carátula bancaria puede
  /// venir como imagen).
  Widget Function(Uint8List bytes, String? nombre)? preview,
  String etiquetaGuardar = 'Guardar',
}) {
  final ancho = context.bp.hasTwoColumns;
  final contenido = _SDocUploadBody(
    titulo: titulo,
    descripcion: descripcion,
    tipos: tipos,
    tipoInicial: tipoId,
    onSeleccionar: onSeleccionar,
    validar: validar,
    onAnalizar: onAnalizar,
    condiciones: condiciones,
    preview: preview ?? (b, n) => SPdfPreview(bytes: b, nombre: n),
    etiquetaGuardar: etiquetaGuardar,
    apilado: !ancho,
  );

  return showSDocModal<SDocUploadResult>(context, child: contenido);
}

/// Presenta [child] como la hoja estándar de carga: diálogo centrado en
/// escritorio (con `Esc` para cancelar) y hoja de pantalla completa en
/// angosto.
///
/// Se expone aparte de [showSDocUpload] porque hay cargas que traen su propio
/// formulario (la carátula de una cuenta bancaria) y necesitan el mismo
/// envoltorio sin pasar por el flujo de extracción.
Future<T?> showSDocModal<T>(
  BuildContext context, {
  required Widget child,
  double maxWidth = 980,
}) {
  // TRAMPA: dentro de `builder` se usa SU context, nunca el del llamador. La
  // hoja vive en otra ruta y se reconstruye por su cuenta; si lee el context de
  // quien la abrió, al reconstruirse busca un ancestro de un widget ya
  // desmontado y revienta con "Looking up a deactivated widget's ancestor".
  if (context.bp.hasTwoColumns) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EscCierra(
        child: Dialog(
          clipBehavior: Clip.antiAlias,
          insetPadding: EdgeInsets.all(ctx.s.space.lg),
          shape: RoundedRectangleBorder(borderRadius: ctx.s.radius.lgBorder),
          // TRAMPA: nada de `IntrinsicHeight` aquí. Mide al hijo dos veces y con
          // contenido desplazable (el formulario va en un scroll) el costo se
          // dispara hasta colgar la pestaña. El alto lo da el contenido y el
          // tope evita que la modal se coma la pantalla.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(ctx).top + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ctx.s.radius.lg),
        ),
        child: Material(color: ctx.s.color.surface, child: child),
      ),
    ),
  );
}

/// `Esc` cierra la hoja en escritorio. El atajo sube por el árbol de foco, así
/// que funciona también con el cursor dentro de un campo de texto (`TextField`
/// no consume `Escape`).
class _EscCierra extends StatelessWidget {
  final Widget child;
  const _EscCierra({required this.child});

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.of(context).maybePop(),
    },
    // `autofocus`: sin un nodo con foco dentro del subárbol el atajo nunca
    // llega. Al tocar un campo el foco baja y Escape sigue subiendo hasta aquí.
    child: Focus(autofocus: true, child: child),
  );
}

class _SDocUploadBody extends StatefulWidget {
  final String titulo;
  final String? descripcion;
  final List<SSelectOption<int>> tipos;
  final int? tipoInicial;
  final Future<({String nombre, Uint8List bytes})?> Function() onSeleccionar;
  final String? Function(Uint8List bytes)? validar;
  final Future<SDocAnalisis> Function(int, String, Uint8List)? onAnalizar;
  final List<String> Function(int tipoId)? condiciones;
  final Widget Function(Uint8List bytes, String? nombre) preview;
  final String etiquetaGuardar;
  final bool apilado;

  const _SDocUploadBody({
    required this.titulo,
    required this.descripcion,
    required this.tipos,
    required this.tipoInicial,
    required this.onSeleccionar,
    required this.validar,
    required this.onAnalizar,
    required this.condiciones,
    required this.preview,
    required this.etiquetaGuardar,
    required this.apilado,
  });

  @override
  State<_SDocUploadBody> createState() => _SDocUploadBodyState();
}

class _SDocUploadBodyState extends State<_SDocUploadBody> {
  final _form = GlobalKey<FormState>();

  int? _tipoId;
  String? _nombre;
  Uint8List? _bytes;
  String? _error;

  SDocAnalisis? _analisis;
  bool _analizando = false;

  /// El análisis reventó. Distinto de `_analisis == null` (todavía no corre) y
  /// de un rechazo (el backend sí contestó).
  bool _falloAnalisis = false;

  final _ctrl = <String, TextEditingController>{};
  final _seleccion = <String, String?>{};

  @override
  void initState() {
    super.initState();
    _tipoId = widget.tipos.isEmpty
        ? widget.tipoInicial
        : (widget.tipos.length == 1 ? widget.tipos.first.value : null);
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<SDocFieldSpec> get _campos => _analisis?.campos ?? const [];
  bool get _hayArchivo => _bytes != null;
  bool get _puedeGuardar =>
      _tipoId != null &&
      _hayArchivo &&
      !_analizando &&
      !_falloAnalisis &&
      (_analisis?.rechazo == null);

  static bool _esLista(SDocFieldSpec c) =>
      c.kind == SDocFieldKind.sexo || c.kind == SDocFieldKind.catalogo;

  Future<void> _adjuntar(String nombre, Uint8List bytes) async {
    final motivo = widget.validar?.call(bytes);
    if (motivo != null) {
      setState(() {
        _error = motivo;
        _nombre = null;
        _bytes = null;
        _analisis = null;
      });
      return;
    }
    setState(() {
      _error = null;
      _nombre = nombre;
      _bytes = bytes;
      _analisis = null;
      _falloAnalisis = false;
      _analizando = widget.onAnalizar != null;
    });

    final analizar = widget.onAnalizar;
    if (analizar == null) return;
    try {
      final res = await analizar(_tipoId!, nombre, bytes);
      if (!mounted) return;
      setState(() {
        _analisis = res;
        _analizando = false;
        for (final c in res.campos) {
          if (_esLista(c)) {
            _seleccion[c.key] = c.valor;
          } else {
            _ctrl[c.key] = TextEditingController(text: c.valor ?? '');
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analizando = false;
        _falloAnalisis = true;
        _error = 'No pudimos revisar el archivo. Vuelve a seleccionarlo.';
      });
    }
  }

  /// Quita el archivo para elegir otro; los campos capturados se van con él.
  void _quitarArchivo() {
    setState(() {
      _nombre = null;
      _bytes = null;
      _analisis = null;
      _falloAnalisis = false;
      _error = null;
      for (final c in _ctrl.values) {
        c.dispose();
      }
      _ctrl.clear();
      _seleccion.clear();
    });
  }

  String? _validar(SDocFieldSpec spec, String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) {
      return spec.requerido ? 'Escribe ${spec.label.toLowerCase()}' : null;
    }
    return switch (spec.kind) {
      SDocFieldKind.curp =>
        _reCurp.hasMatch(t.toUpperCase()) ? null : 'CURP de 18 caracteres',
      SDocFieldKind.rfc =>
        _reRfc.hasMatch(t.toUpperCase()) ? null : 'RFC de 12 o 13 caracteres',
      SDocFieldKind.fecha => _reFecha.hasMatch(t) ? null : 'Usa DD/MM/AAAA',
      SDocFieldKind.cp => _reCp.hasMatch(t) ? null : '5 dígitos',
      _ => null,
    };
  }

  Future<void> _guardar() async {
    if (!_puedeGuardar) return;
    if (_campos.isNotEmpty && !(_form.currentState?.validate() ?? false)) {
      return;
    }
    final faltaLista = _campos
        .where(_esLista)
        .any((c) => c.requerido && (_seleccion[c.key] ?? '').isEmpty);
    if (faltaLista) {
      setState(() {});
      return;
    }

    final tipo = _tipoId!;
    final puntos = widget.condiciones?.call(tipo) ?? const <String>[];
    if (puntos.isNotEmpty) {
      final ok = await showSConfirm(
        context,
        titulo: 'Antes de subir tu documento',
        mensaje:
            'Al aceptar confirmas que el archivo cumple con lo siguiente. Si '
            'no lo cumple, la revisión lo rechazará y tendrás que cargarlo de '
            'nuevo.',
        puntos: puntos,
        etiquetaAceptar: 'Acepto y subir',
        tono: SConfirmTone.warning,
      );
      if (ok != true || !mounted) return;
    }

    final out = <String, String>{};
    for (final c in _campos) {
      if (c.soloLectura) continue;
      final v = _esLista(c)
          ? (_seleccion[c.key] ?? '')
          : (_ctrl[c.key]?.text.trim() ?? '');
      if (v.isEmpty) continue;
      out[c.key] = switch (c.kind) {
        SDocFieldKind.curp || SDocFieldKind.rfc => v.toUpperCase(),
        _ => v,
      };
    }
    if (!mounted) return;
    // Red de seguridad: un archivo vacío nunca sale de aquí. Si el buffer se
    // quedó sin bytes (en web basta con que alguien lo transfiera a un worker),
    // el backend responde "no llegó el archivo" y el cliente no entiende nada.
    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() {
        _error = 'El archivo se perdió al prepararlo. Vuelve a seleccionarlo.';
        _bytes = null;
        _nombre = null;
        _analisis = null;
      });
      return;
    }
    Navigator.of(
      context,
    ).pop((tipoId: tipo, nombre: _nombre!, bytes: bytes, campos: out));
  }

  // ── Render ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final bytes = _bytes;
    return SDocUploadLayout(
      titulo: widget.titulo,
      descripcion: widget.descripcion,
      apilado: widget.apilado,
      izquierda: _izquierda(tone),
      // Sin archivo la columna solo lleva la zona de carga, y pegada arriba se
      // lee como si faltara algo.
      centrarIzquierda: !_hayArchivo,
      preview: bytes != null ? widget.preview(bytes, _nombre) : null,
      etiquetaGuardar: widget.etiquetaGuardar,
      guardando: _analizando,
      etiquetaGuardando: 'Revisando…',
      onGuardar: _puedeGuardar ? _guardar : null,
    );
  }

  /// Columna izquierda: selector de tipo, archivo y campos.
  Widget _izquierda(SozuColorRoles tone) {
    final hayCampos = _campos.isNotEmpty;
    return Column(
      mainAxisAlignment: _hayArchivo
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.tipos.length > 1) ...[
          SSelectField<int>(
            label: 'Tipo de documento',
            requerido: true,
            hint: 'Elige uno',
            value: _tipoId,
            opciones: widget.tipos,
            // Cambiar de tipo invalida lo analizado: el archivo se vuelve a
            // pedir en vez de guardar un pasaporte como si fuera un INE.
            onChanged: _hayArchivo
                ? (v) => setState(() {
                    _tipoId = v;
                    _quitarArchivo();
                  })
                : (v) => setState(() => _tipoId = v),
          ),
          SizedBox(height: context.s.space.md),
        ],
        if (!_hayArchivo)
          _zonaCentrada(tone)
        else ...[
          _archivoAdjunto(tone),
          if (_analizando) ...[
            SizedBox(height: context.s.space.md),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: context.s.space.xs),
                Text(
                  'Revisando el documento…',
                  style: context.s.text.caption.copyWith(color: tone.fgMuted),
                ),
              ],
            ),
          ],
          if (_analisis?.rechazo != null) ...[
            SizedBox(height: context.s.space.md),
            _Banda(
              texto: _analisis!.rechazo!,
              icono: Icons.error_outline,
              fondo: tone.dangerSoft,
              acento: tone.danger,
            ),
          ] else if (_analisis?.aviso != null) ...[
            SizedBox(height: context.s.space.md),
            _Banda(
              texto: _analisis!.aviso!,
              icono: _analisis!.tono == SDocTone.warning
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline,
              fondo: _analisis!.tono == SDocTone.warning
                  ? tone.warningSoft
                  : tone.infoSoft,
              acento: _analisis!.tono == SDocTone.warning
                  ? tone.warningFg
                  : tone.infoFg,
            ),
          ],
          if (hayCampos) ...[
            SizedBox(height: context.s.space.md),
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in _campos)
                    Padding(
                      padding: EdgeInsets.only(bottom: context.s.space.sm),
                      child: _campo(c),
                    ),
                ],
              ),
            ),
          ],
        ],
        if (_error != null) ...[
          SizedBox(height: context.s.space.sm),
          _Banda(
            texto: _error!,
            icono: Icons.error_outline,
            fondo: tone.dangerSoft,
            acento: tone.danger,
          ),
        ],
      ],
    );
  }

  /// Zona de carga mientras no hay archivo.
  Widget _zonaCentrada(SozuColorRoles tone) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SDropZone(
        titulo: 'Adjuntar PDF',
        subtitulo: 'Solo PDF, escaneado y legible',
        habilitado: _tipoId != null,
        onSeleccionar: widget.onSeleccionar,
        onArchivo: _adjuntar,
      ),
      if (_tipoId == null) ...[
        SizedBox(height: context.s.space.xs),
        Text(
          'Elige primero el tipo de documento.',
          textAlign: TextAlign.center,
          style: context.s.text.caption.copyWith(color: tone.fgSubtle),
        ),
      ],
    ],
  );

  /// Archivo ya adjunto, en una línea: deja el espacio para los campos.
  Widget _archivoAdjunto(SozuColorRoles tone) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: context.s.space.sm,
      vertical: context.s.space.xs,
    ),
    decoration: BoxDecoration(
      color: tone.primarySoft,
      borderRadius: context.s.radius.mdBorder,
      border: Border.all(color: tone.primaryBorder),
    ),
    child: Row(
      children: [
        Icon(Icons.picture_as_pdf_outlined, size: 18, color: tone.primary),
        SizedBox(width: context.s.space.xs),
        Expanded(
          child: Text(
            _nombre ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.s.text.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: tone.fg,
            ),
          ),
        ),
        TextButton(
          onPressed: _analizando ? null : _quitarArchivo,
          child: const Text('Cambiar'),
        ),
      ],
    ),
  );

  Widget _campo(SDocFieldSpec c) {
    if (_esLista(c)) {
      final items = c.kind == SDocFieldKind.sexo
          ? const [(id: 'H', nombre: 'Hombre'), (id: 'M', nombre: 'Mujer')]
          : c.opciones;
      final valor = _seleccion[c.key];
      return SSelectField<String>(
        label: c.label,
        requerido: c.requerido,
        value: valor,
        opciones: [for (final o in items) (value: o.id, label: o.nombre)],
        errorText: c.requerido && (valor ?? '').isEmpty
            ? 'Elige una opción'
            : null,
        onChanged: c.soloLectura
            ? null
            : (v) => setState(() => _seleccion[c.key] = v),
      );
    }
    // La etiqueta va aparte y en `caption`: la de STextField es `label` (16) y
    // en un formulario de nueve campos compite con el contenido.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SFieldLabel(
          c.label,
          requerido: c.requerido,
          habilitado: !c.soloLectura,
        ),
        STextField(
          controller: _ctrl.putIfAbsent(c.key, TextEditingController.new),
          helper: c.ayuda,
          readOnly: c.soloLectura,
          enabled: !c.soloLectura,
          size: STextFieldSize.md,
          keyboardType: switch (c.kind) {
            SDocFieldKind.cp => TextInputType.number,
            SDocFieldKind.fecha => TextInputType.datetime,
            _ => null,
          },
          validator: c.soloLectura ? null : (v) => _validar(c, v),
        ),
      ],
    );
  }
}

/// Hoja de carga: dos columnas (contenido a la izquierda, previsualización a
/// la derecha) dentro del chasis de [SFormSheet].
///
/// [showSDocUpload] lo usa para el flujo de extracción, y cualquier hoja que
/// suba un archivo con su propio formulario lo usa igual (la carátula de una
/// cuenta bancaria). Así el formato es uno solo y lo que se arregle aquí sirve
/// en todas.
///
/// En pantalla angosta apila: previsualización arriba, contenido abajo.
class SDocUploadLayout extends StatelessWidget {
  final String titulo;
  final String? descripcion;

  /// Formulario y/o campos. Es el contenido propio de cada hoja.
  final Widget izquierda;

  /// Previsualización del archivo; `null` pinta el hueco con su instrucción.
  final Widget? preview;

  /// Apila en vez de repartir en dos columnas (pantalla angosta).
  final bool apilado;

  /// Centra [izquierda] contra el alto de la previsualización. Se usa mientras
  /// no hay archivo, cuando la columna lleva poco contenido.
  final bool centrarIzquierda;

  final String etiquetaGuardar;
  final String? etiquetaGuardando;
  final bool guardando;

  /// `null` deshabilita Guardar.
  final VoidCallback? onGuardar;

  const SDocUploadLayout({
    super.key,
    required this.titulo,
    required this.izquierda,
    this.descripcion,
    this.preview,
    this.apilado = false,
    this.centrarIzquierda = false,
    this.etiquetaGuardar = 'Guardar',
    this.etiquetaGuardando,
    this.guardando = false,
    this.onGuardar,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;

    final columna = SingleChildScrollView(
      padding: EdgeInsets.all(t.space.md),
      child: centrarIzquierda
          ? ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height * 0.6,
              ),
              child: izquierda,
            )
          : izquierda,
    );

    return SFormSheet(
      titulo: titulo,
      descripcion: descripcion,
      etiquetaGuardar: etiquetaGuardar,
      etiquetaGuardando: etiquetaGuardando,
      guardando: guardando,
      onGuardar: onGuardar,
      // `cuerpoAlAlto` + `stretch` es lo que da alto a la previsualización: con
      // restricciones sueltas el visor resuelve a cero y la columna derecha
      // sale en blanco. Apilado no aplica: ahí la previsualización lleva alto
      // fijo y el cuerpo crece con su contenido.
      cuerpoAlAlto: !apilado,
      cuerpo: apilado
          ? SingleChildScrollView(
              padding: EdgeInsets.all(t.space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (preview != null) ...[
                    SizedBox(height: 280, child: preview),
                    SizedBox(height: t.space.md),
                  ],
                  izquierda,
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: columna),
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      t.space.md,
                      t.space.md,
                      t.space.md,
                    ),
                    child: preview ?? _SinVistaPrevia(),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Banda de aviso, rechazo o error dentro de la columna de campos.
class _Banda extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color fondo;
  final Color acento;

  const _Banda({
    required this.texto,
    required this.icono,
    required this.fondo,
    required this.acento,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(context.s.space.sm),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: context.s.radius.mdBorder,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 16, color: acento),
        SizedBox(width: context.s.space.xs),
        Expanded(
          child: Text(
            texto,
            style: context.s.text.caption.copyWith(color: context.s.color.fg),
          ),
        ),
      ],
    ),
  );
}

/// Hueco de la previsualización mientras no hay archivo.
class _SinVistaPrevia extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Container(
      decoration: BoxDecoration(
        color: tone.muted,
        borderRadius: context.s.radius.mdBorder,
        border: Border.all(color: tone.border),
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.all(context.s.space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 34, color: tone.fgSubtle),
          SizedBox(height: context.s.space.xs),
          Text(
            'Vista previa',
            style: context.s.text.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: tone.fgMuted,
            ),
          ),
          SizedBox(height: context.s.space.xxs),
          Text(
            'Adjunta tu PDF para revisarlo aquí antes de guardarlo.',
            textAlign: TextAlign.center,
            style: context.s.text.caption.copyWith(color: tone.fgSubtle),
          ),
        ],
      ),
    );
  }
}
