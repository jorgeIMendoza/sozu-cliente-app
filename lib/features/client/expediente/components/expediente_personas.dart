import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/expediente/components/expediente_ficha_card.dart';
import 'package:sozu_cliente_app/features/client/expediente/providers/expediente_providers.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Representantes legales y accionistas de una persona moral: una tarjeta por
/// persona y un botón para agregar.
///
/// Los documentos de cada uno NO se pintan aquí. Con dos accionistas eso eran
/// dieciocho filas en la misma pantalla; ahora cada quien tiene la suya, a la
/// que se entra desde su tarjeta.
class ExpedientePersonas extends ConsumerStatefulWidget {
  final List<ExpedientePersona> personas;

  /// De quién cuelgan: el titular, o la empresa cuya ficha se está viendo.
  final int contexto;

  /// Porcentaje mínimo que el backend exige a un accionista.
  final double umbral;

  /// Abre la ficha de esa persona.
  final void Function(ExpedientePersona) onAbrir;

  /// Solo el boton de agregar, para ponerlo arriba de todo.
  final bool soloBoton;

  /// Solo las tarjetas, porque el boton ya se pinto arriba.
  final bool soloLista;

  const ExpedientePersonas({
    super.key,
    required this.personas,
    required this.contexto,
    required this.umbral,
    required this.onAbrir,
    this.soloBoton = false,
    this.soloLista = false,
  });

  @override
  ConsumerState<ExpedientePersonas> createState() => _ExpedientePersonasState();
}

class _ExpedientePersonasState extends ConsumerState<ExpedientePersonas> {
  bool _guardando = false;

  List<ExpedientePersona> get _representantes =>
      widget.personas.where((p) => !p.esAccionista).toList();
  List<ExpedientePersona> get _accionistas =>
      widget.personas.where((p) => p.esAccionista).toList();

  /// Recarga la lista de quien sea que cuelguen estas personas: el titular, o
  /// la empresa del árbol cuya ficha se está viendo. Invalidar solo la del
  /// titular dejaba la portada de una empresa anidada sin la persona que se
  /// acababa de registrar.
  void _refrescar() {
    ref.invalidate(identityFileProvider);
    ref.invalidate(personaExpedienteProvider(widget.contexto));
  }

  /// Porcentaje de acciones ya repartido. Lo que quede es el techo del
  /// siguiente accionista: entre todos no pueden pasar del 100%.
  double get _porcentajeUsado =>
      _accionistas.fold<double>(0, (s, p) => s + (p.porcentaje ?? 0));

  Future<void> _agregar() async {
    final alta = await showSDocModal<_AltaPersona>(
      context,
      child: _AltaPersonaDialog(umbral: widget.umbral, usado: _porcentajeUsado),
      maxWidth: 720,
    );
    if (alta == null || !mounted) return;

    setState(() => _guardando = true);
    int? id;
    var registrada = false;
    try {
      id = await ref
          .read(expedientePortProvider)
          .addPerson(
            rol: alta.rol,
            nombre: alta.nombre,
            tipoPersona: alta.tipoPersona,
            correo: alta.correo,
            telefono: alta.telefono,
            porcentaje: alta.porcentaje,
            contexto: widget.contexto,
          );
      _refrescar();
      registrada = true;
    } on DocumentoInvalidoError catch (e) {
      _aviso(e.reason, error: true);
    } on ApiError catch (e) {
      _aviso(_mensajeDe(e), error: true);
    } catch (_) {
      _aviso('No se pudo guardar. Intenta de nuevo.', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
    // La invitación a subir documentos va FUERA del try: espera al cliente, y
    // con el indicador encendido el botón se quedaba girando debajo del
    // diálogo todo ese rato.
    if (registrada && mounted) await _invitarASubir(alta, id);
  }

  /// El alta solo registra a la persona: sus documentos son el trabajo que
  /// sigue y desde aqui se entra directo a subirlos, sin volver a buscarla en
  /// la lista.
  Future<void> _invitarASubir(_AltaPersona alta, int? id) async {
    final esRep = alta.rol == 'representante';
    final ok = await showSConfirm(
      context,
      titulo: esRep
          ? 'Listo, ya registramos a tu representante legal'
          : 'Listo, ya registramos al accionista',
      mensaje: alta.tipoPersona == 'pm'
          ? 'Completa su información subiendo los documentos de esa empresa y '
                'registrando a su representante y a sus accionistas.'
          : 'Completa su información subiendo su documentación: '
                'identificación, acta de nacimiento, CURP, constancia fiscal y '
                'comprobante de domicilio.',
      etiquetaAceptar: 'Subir documentos',
      etiquetaCancelar: 'Más tarde',
    );
    if (!mounted) return;
    if (ok != true) return;
    if (id == null) {
      // Sin id no hay a dónde entrar: la tarjeta ya está en la lista.
      _aviso('Abre su tarjeta para subir sus documentos');
      return;
    }
    widget.onAbrir(
      ExpedientePersona.recienCreada(
        idPersona: id,
        nombre: alta.nombre,
        tipoPersona: alta.tipoPersona,
        rol: alta.rol,
        porcentaje: alta.porcentaje,
      ),
    );
  }

  Future<void> _quitar(ExpedientePersona p) async {
    final ok = await showSConfirm(
      context,
      titulo: 'Quitar a ${p.nombre}',
      mensaje:
          'Se saca de tu expediente. Puedes volver a agregarla cuando quieras.',
      etiquetaAceptar: 'Quitar',
      tono: SConfirmTone.warning,
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(expedientePortProvider)
          .removePerson(idPersona: p.idPersona, contexto: widget.contexto);
      _refrescar();
    } on DocumentoInvalidoError catch (e) {
      _aviso(e.reason, error: true);
    } on ApiError catch (e) {
      _aviso(_mensajeDe(e), error: true);
    }
  }

  String _mensajeDe(ApiError e) => switch (e.code) {
    'porcentaje_menor' =>
      'Solo hace falta el expediente de accionistas con más del '
          '${widget.umbral.toStringAsFixed(0)}%.',
    'tiene_documentos' =>
      'Ya subiste documentos suyos. Pídele a tu asesor que lo quite.',
    'ligada_por_asesor' =>
      'A esta persona la registró tu asesor. Pídele a él que la quite.',
    'solo_persona_moral' => 'Esto solo aplica a empresas.',
    'nombre_requerido' => 'Escribe el nombre completo.',
    'correo_invalido' => 'Revisa el correo: no tiene formato válido.',
    'correo_duplicado' =>
      'Ese correo ya está registrado con otra persona. Usa otro, o pídele a tu '
          'asesor que la ligue a tu expediente.',
    'telefono_invalido' => 'Revisa el teléfono: son 10 dígitos.',
    'porcentaje_invalido' => 'El porcentaje debe estar entre 1 y 100.',
    'porcentaje_total' =>
      'Entre todos los accionistas no pueden pasar del 100%.',
    'ciclo' => 'Esa empresa ya cuelga de esta.',
    _ => 'No se pudo guardar (${e.code}).',
  };

  void _aviso(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: Duration(seconds: error ? 7 : 4),
      ),
    );
  }

  /// Tarjeta de una persona ligada. Es la misma ficha que la de la empresa, así
  /// que hay un solo componente de tarjeta y no dos parecidos.
  Widget _ficha(ExpedientePersona p) => ExpedienteFichaCard(
    titulo: p.nombre,
    subtitulo: [
      if (p.porcentaje != null) '${_pct(p.porcentaje!)}% de las acciones',
      if (p.esMoral) 'Empresa' else 'Persona física',
    ].join(' · '),
    icono: p.esMoral ? Icons.apartment_outlined : Icons.person_outline,
    total: p.requeridosTotal,
    aprobados: p.requeridosAprobados,
    onAbrir: () => widget.onAbrir(p),
    accion: p.puedeEliminar
        ? IconButton(
            tooltip: 'Quitar',
            iconSize: 17,
            color: context.s.color.fgSubtle,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _quitar(p),
          )
        : null,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.s;

    // El encabezado de la pantalla solo quiere el botón: ahí se ve sin escanear
    // la página, y las tarjetas van abajo con su título.
    if (widget.soloBoton) {
      return SButton(
        label: 'Agregar persona',
        icon: Icons.person_add_alt_outlined,
        loading: _guardando,
        fullWidth: false,
        size: SButtonSize.sm,
        onPressed: _agregar,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // El título va SIEMPRE, con o sin representante: es el que dice qué
        // falta. Sin él, el recuadro vacío quedaba huérfano y solo el de
        // accionistas llevaba encabezado.
        _Titulo('Representante legal'),
        SizedBox(height: t.space.xs),
        if (_representantes.isEmpty)
          _Vacio(
            texto: 'Agrega a tu representante legal para subir sus documentos.',
          )
        else
          for (final p in _representantes) ...[
            _ficha(p),
            SizedBox(height: t.space.xs),
          ],

        SizedBox(height: t.space.md),
        _Titulo('Accionistas con más del ${widget.umbral.toStringAsFixed(0)}%'),
        SizedBox(height: t.space.xs),
        if (_accionistas.isEmpty)
          _Vacio(
            texto:
                'Agrega a los accionistas que superen el '
                '${widget.umbral.toStringAsFixed(0)}% de las acciones.',
          )
        else ...[
          for (final p in _accionistas) ...[
            _ficha(p),
            SizedBox(height: t.space.xs),
          ],
          // Cuánto queda por repartir: es el techo del siguiente accionista y
          // el cliente tiene que verlo antes de abrir el alta.
          Text(
            'Registrado: ${_pct(_porcentajeUsado)}% · '
            'disponible: ${_pct(100 - _porcentajeUsado)}%',
            style: t.text.caption.copyWith(color: t.color.fgMuted),
          ),
        ],

        // Sin `soloLista` el botón va aquí: es el caso de una empresa anidada,
        // cuya pantalla no tiene encabezado propio donde ponerlo.
        if (!widget.soloLista) ...[
          SizedBox(height: t.space.sm),
          SButton.secondary(
            label: 'Agregar persona',
            icon: Icons.person_add_alt_outlined,
            loading: _guardando,
            onPressed: _agregar,
          ),
        ],
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) => Text(
    texto.toUpperCase(),
    style: context.s.text.overline.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: context.s.color.fgSubtle,
    ),
  );
}

class _Vacio extends StatelessWidget {
  final String texto;
  const _Vacio({required this.texto});

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.s.space.md,
        vertical: context.s.space.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: tone.border),
        borderRadius: context.s.radius.smBorder,
        color: tone.surfaceAlt,
      ),
      child: Text(
        texto,
        style: context.s.text.caption.copyWith(color: tone.fgMuted),
      ),
    );
  }
}

/// Porcentaje legible: sin decimales cuando es entero.
String _pct(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 2);

/// Lo que el cliente captura al agregar a alguien.
typedef _AltaPersona = ({
  String rol,
  String nombre,
  String tipoPersona,
  String correo,
  String telefono,
  double? porcentaje,
});

/// Alta de una persona ligada: rol, nombre, correo y teléfono. Con eso queda
/// registrada.
///
/// Aquí NO se adjunta nada. Sus documentos se suben después, en su propia
/// ficha, que es donde vive la lista de lo que se le pide: pedirlos en el alta
/// obligaba a tener el PDF a la mano para poder registrar a alguien.
class _AltaPersonaDialog extends StatefulWidget {
  /// Porcentaje mínimo que el backend exige a un accionista.
  final double umbral;

  /// Porcentaje ya repartido entre los accionistas registrados.
  final double usado;

  const _AltaPersonaDialog({required this.umbral, required this.usado});

  @override
  State<_AltaPersonaDialog> createState() => _AltaPersonaDialogState();
}

class _AltaPersonaDialogState extends State<_AltaPersonaDialog> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _porcentaje = TextEditingController();
  String _rol = 'representante';
  String _tipo = 'pf';

  /// Lo que queda por repartir: entre todos los accionistas no pueden pasar
  /// del 100% de las acciones.
  double get _disponible => 100 - widget.usado;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _telefono.dispose();
    _porcentaje.dispose();
    super.dispose();
  }

  void _guardar() {
    if (_form.currentState?.validate() != true) return;
    Navigator.of(context).pop((
      rol: _rol,
      nombre: _nombre.text.trim(),
      tipoPersona: _tipo,
      correo: _correo.text.trim(),
      telefono: _telefono.text.trim(),
      porcentaje: _rol == 'accionista'
          ? double.tryParse(_porcentaje.text.trim().replaceAll(',', '.'))
          : null,
    ));
  }

  /// Ataja el dedazo, no comprueba que el buzón exista: eso solo lo dice
  /// mandarle un correo.
  ///
  /// El patrón es el MISMO del `CHECK` de `personas.email`. Con uno más laxo,
  /// un correo con acentos pasaba el formulario y moría en el INSERT, donde ya
  /// no hay un campo al que señalar.
  String? _validarCorreo(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Escribe su correo';
    return RegExp(
          r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
        ).hasMatch(s)
        ? null
        : 'Correo no válido';
  }

  String? _validarTelefono(String? v) =>
      (v ?? '').trim().length == 10 ? null : 'Son 10 dígitos';

  String? _validarPorcentaje(String? v) {
    final p = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
    if (p == null || p <= 0 || p > 100) return 'Un número entre 1 y 100';
    if (p <= widget.umbral) {
      return 'Solo se piden los que pasan del ${_pct(widget.umbral)}%';
    }
    if (p > _disponible) {
      return 'Solo quedan ${_pct(_disponible)}% por repartir';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final dosColumnas = context.bp.hasTwoColumns;

    return SFormSheet(
      titulo: 'Agregar persona',
      descripcion:
          'Con su nombre, correo y teléfono queda registrada. Su documentación '
          'se sube después, en su propia ficha.',
      etiquetaGuardar: 'Agregar',
      onGuardar: _guardar,
      cuerpo: SingleChildScrollView(
        padding: EdgeInsets.all(t.space.lg),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Pareja(
                dosColumnas: dosColumnas,
                izquierda: SSelectField<String>(
                  label: 'Rol',
                  value: _rol,
                  opciones: const [
                    (value: 'representante', label: 'Representante legal'),
                    (value: 'accionista', label: 'Accionista mayoritario'),
                  ],
                  onChanged: (v) => setState(() => _rol = v ?? 'representante'),
                ),
                derecha: SSelectField<String>(
                  label: 'Tipo de persona',
                  value: _tipo,
                  opciones: const [
                    (value: 'pf', label: 'Persona física'),
                    (value: 'pm', label: 'Persona moral'),
                  ],
                  onChanged: (v) => setState(() => _tipo = v ?? 'pf'),
                ),
              ),
              SizedBox(height: t.space.md),
              STextField(
                controller: _nombre,
                label: _tipo == 'pm' ? 'Razón social' : 'Nombre completo',
                hint: _tipo == 'pm'
                    ? 'Como aparece en su acta constitutiva'
                    : 'Como aparece en su identificación',
                autofocus: dosColumnas,
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().length < 3
                    ? 'Escribe el nombre completo'
                    : null,
              ),
              SizedBox(height: t.space.md),
              _Pareja(
                dosColumnas: dosColumnas,
                izquierda: STextField(
                  controller: _correo,
                  label: 'Correo',
                  hint: 'nombre@correo.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: _validarCorreo,
                ),
                derecha: STextField(
                  controller: _telefono,
                  label: 'Teléfono',
                  hint: '10 dígitos',
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validarTelefono,
                ),
              ),
              if (_rol == 'accionista') ...[
                SizedBox(height: t.space.md),
                _Pareja(
                  dosColumnas: dosColumnas,
                  izquierda: STextField(
                    controller: _porcentaje,
                    label: '% de acciones',
                    hint: 'Ej: 30',
                    helper: 'Disponible: ${_pct(_disponible)}%',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _validarPorcentaje,
                  ),
                ),
              ],
              if (_tipo == 'pm') ...[
                SizedBox(height: t.space.md),
                _Nota(
                  'Al ser empresa, después habrá que registrar a su propio '
                  'representante y a sus accionistas.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dos campos que van en la misma línea en escritorio y apilados en móvil.
class _Pareja extends StatelessWidget {
  final Widget izquierda;

  /// null deja la mitad derecha vacía: un campo corto (el porcentaje) no tiene
  /// por qué ocupar el ancho entero.
  final Widget? derecha;
  final bool dosColumnas;

  const _Pareja({
    required this.izquierda,
    required this.dosColumnas,
    this.derecha,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    if (!dosColumnas) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          izquierda,
          if (derecha != null) ...[SizedBox(height: t.space.md), derecha!],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: izquierda),
        SizedBox(width: t.space.md),
        Expanded(child: derecha ?? const SizedBox.shrink()),
      ],
    );
  }
}

/// Aviso informativo dentro del formulario.
class _Nota extends StatelessWidget {
  final String texto;
  const _Nota(this.texto);

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      padding: EdgeInsets.all(t.space.sm),
      decoration: BoxDecoration(
        color: t.color.surfaceAlt,
        borderRadius: t.radius.mdBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: t.color.fgMuted),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(
              texto,
              style: t.text.caption.copyWith(color: t.color.fgMuted),
            ),
          ),
        ],
      ),
    );
  }
}
