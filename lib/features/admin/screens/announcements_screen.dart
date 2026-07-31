import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sozu_cliente_app/data/api_client.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/widgets/animacion_llegada.dart';
import 'package:sozu_cliente_app/features/admin/layouts/admin_layout.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Lado del spinner que sustituye al icono mientras se envía o se guarda.
/// No es espaciado: iguala el `size` del icono al que reemplaza.
const double _kSpinnerSize = 18;

/// Lienzo del diálogo del selector múltiple. Alto fijo para que la lista
/// scrollee en vez de estirar el diálogo.
const double _kSelectorDialogWidth = 380;
const double _kSelectorDialogHeight = 420;

/// Lado del icono al final de los campos que abren un selector. Igual que el
/// del prefijo de `STextField`.
const double _kSelectorIconSize = 20;

/// Señal del selector MÚLTIPLE: abre un diálogo con buscador y casillas, no un
/// menú. Sin flecha a propósito: prometía un desplegable que el toque no abre
/// (mismo motivo por el que `SAutocompleteField` no la lleva).
const IconData _kSelectorMultipleIcon = Icons.checklist;

/// Señal del selector de UNA opción: aquí el menú sí se despliega bajo el campo.
const IconData _kSelectorUnicoIcon = Icons.expand_more;

/// Cuántos nombres se enumeran en el resumen antes de cortar con "+N".
const int _kResumenMaxNombres = 3;

/// "informativa" -> "Informativa". Los catálogos vienen en minúsculas.
String _capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _tipos = ['informativa', 'accionable', 'urgente', 'exito'];
const _categorias = [
  'pagos',
  'documentos',
  'mantenimiento',
  'construccion',
  'reventa',
  'entrega',
];

/// Envío de avisos a clientes del app (solo super admin): inmediato o
/// calendarizado, a todos o filtrado por proyecto/modelo/propiedad, por
/// canales push / correo / WhatsApp. Espejo ligero de "Administrar avisos"
/// de sozu-admin, apoyado en la edge function admin-avisos-app.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _mensaje = TextEditingController();

  String _tipo = 'informativa';
  String _categoria = 'pagos';
  final Set<String> _canales = {'push'};

  List<CatalogoItem> _proyectos = [];
  List<CatalogoItem> _modelos = [];
  List<CatalogoItem> _niveles = [];
  List<CatalogoItem> _propiedades = [];
  final Set<int> _proyectosSel = {};
  final Set<int> _modelosSel = {};
  final Set<int> _nivelesSel = {};
  final Set<int> _propiedadesSel = {};
  bool _cargandoModelos = false;
  bool _cargandoNiveles = false;
  bool _cargandoPropiedades = false;

  bool _programar = false;
  DateTime? _fechaHora;

  bool _enviando = false;
  bool _cargandoAvisos = true;
  List<AvisoApp> _avisos = [];

  // Configuración general: animación de llegada en la campana.
  String _animacion = 'gol';
  bool _guardandoAnimacion = false;

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
    _cargarAvisos();
    _cargarAnimacion();
  }

  Future<void> _cargarAnimacion() async {
    try {
      final anim = await fetchAnimacionCampana();
      if (mounted) setState(() => _animacion = anim);
    } catch (_) {
      /* queda el default */
    }
  }

  Future<void> _guardarAnimacion(String? valor) async {
    if (valor == null || valor == _animacion) return;
    final previa = _animacion;
    setState(() {
      _animacion = valor;
      _guardandoAnimacion = true;
    });
    try {
      await setAnimacionCampana(valor);
      _snack('Animación actualizada para todos los clientes.');
    } catch (_) {
      if (mounted) setState(() => _animacion = previa);
      _snack('No se pudo guardar la animación.');
    } finally {
      if (mounted) setState(() => _guardandoAnimacion = false);
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _mensaje.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogos() async {
    try {
      final proyectos = await fetchAvisosProyectos();
      if (!mounted) return;
      setState(() => _proyectos = proyectos);
    } catch (_) {
      /* selector queda vacío; el envío a todos sigue posible */
    }
  }

  Future<void> _cargarAvisos() async {
    setState(() => _cargandoAvisos = true);
    try {
      final avisos = await fetchAvisosApp();
      if (!mounted) return;
      setState(() {
        _avisos = avisos;
        _cargandoAvisos = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoAvisos = false);
    }
  }

  /// Cascada: al cambiar proyectos se recargan modelos, niveles y propiedades
  /// y se limpian las selecciones dependientes.
  Future<void> _onProyectosChanged(Set<int> sel) async {
    setState(() {
      _proyectosSel
        ..clear()
        ..addAll(sel);
      _modelosSel.clear();
      _nivelesSel.clear();
      _propiedadesSel.clear();
      _modelos = [];
      _niveles = [];
      _propiedades = [];
    });
    if (sel.isEmpty) return;
    setState(() {
      _cargandoModelos = true;
      _cargandoNiveles = true;
      _cargandoPropiedades = true;
    });
    try {
      final res = await Future.wait([
        fetchAvisosModelos(sel.toList()),
        // Tolerante: si el backend aún no expone "niveles" no debe tumbar
        // la carga de modelos/propiedades.
        fetchAvisosNiveles(sel.toList()).catchError((_) => <CatalogoItem>[]),
        fetchAvisosPropiedades(sel.toList()),
      ]);
      if (!mounted) return;
      setState(() {
        _modelos = res[0];
        _niveles = res[1];
        _propiedades = res[2];
      });
    } catch (_) {
      /* filtros finos no disponibles */
    } finally {
      if (mounted) {
        setState(() {
          _cargandoModelos = false;
          _cargandoNiveles = false;
          _cargandoPropiedades = false;
        });
      }
    }
  }

  /// Cascada: con modelos seleccionados se recalculan niveles y propiedades.
  Future<void> _onModelosChanged(Set<int> sel) async {
    setState(() {
      _modelosSel
        ..clear()
        ..addAll(sel);
      _nivelesSel.clear();
      _propiedadesSel.clear();
      _niveles = [];
      _propiedades = [];
      _cargandoNiveles = true;
      _cargandoPropiedades = true;
    });
    try {
      final res = await Future.wait([
        fetchAvisosNiveles(
          _proyectosSel.toList(),
          idsModelos: sel.toList(),
        ).catchError((_) => <CatalogoItem>[]),
        fetchAvisosPropiedades(
          _proyectosSel.toList(),
          idsModelos: sel.toList(),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _niveles = res[0];
        _propiedades = res[1];
      });
    } catch (_) {
      /* filtro fino no disponible */
    } finally {
      if (mounted) {
        setState(() {
          _cargandoNiveles = false;
          _cargandoPropiedades = false;
        });
      }
    }
  }

  /// Cascada: con niveles seleccionados solo se listan sus propiedades.
  Future<void> _onNivelesChanged(Set<int> sel) async {
    setState(() {
      _nivelesSel
        ..clear()
        ..addAll(sel);
      _propiedadesSel.clear();
      _propiedades = [];
      _cargandoPropiedades = true;
    });
    try {
      final props = await fetchAvisosPropiedades(
        _proyectosSel.toList(),
        idsModelos: _modelosSel.toList(),
        idsNiveles: sel.toList(),
      );
      if (mounted) setState(() => _propiedades = props);
    } catch (_) {
      /* filtro fino no disponible */
    } finally {
      if (mounted) setState(() => _cargandoPropiedades = false);
    }
  }

  Future<void> _elegirFechaHora() async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaHora ?? ahora.add(const Duration(hours: 1)),
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 365)),
    );
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _fechaHora ?? ahora.add(const Duration(hours: 1)),
      ),
    );
    if (hora == null) return;
    setState(() {
      _fechaHora = DateTime(
        fecha.year,
        fecha.month,
        fecha.day,
        hora.hour,
        hora.minute,
      );
    });
  }

  String get _resumenDestino {
    if (_proyectosSel.isEmpty) return 'Todos los clientes';
    String nombres(
      List<CatalogoItem> items,
      Set<int> sel, [
      String pref = '',
    ]) => items
        .where((e) => sel.contains(e.id))
        .map((e) => '$pref${e.nombre}')
        .join(', ');
    return [
      nombres(_proyectos, _proyectosSel),
      if (_modelosSel.isNotEmpty) 'Modelos: ${nombres(_modelos, _modelosSel)}',
      if (_nivelesSel.isNotEmpty) 'Niveles: ${nombres(_niveles, _nivelesSel)}',
      if (_propiedadesSel.isNotEmpty)
        'Unidades: ${nombres(_propiedades, _propiedadesSel, 'U-')}',
    ].join(' · ');
  }

  Future<void> _enviar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_canales.isEmpty) {
      _snack('Selecciona al menos un canal.');
      return;
    }
    if (_programar && _fechaHora == null) {
      _snack('Elige fecha y hora para programar.');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_programar ? 'Programar aviso' : 'Enviar aviso ahora'),
        content: Text(
          'Destino: $_resumenDestino\n'
          'Canales: ${_canales.join(', ')}'
          '${_programar ? '\nEnvío: ${DateFormat('dd/MM/yyyy HH:mm').format(_fechaHora!)}' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_programar ? 'Programar' : 'Enviar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _enviando = true);
    try {
      await crearAvisoApp(
        titulo: _titulo.text.trim(),
        mensaje: _mensaje.text.trim(),
        tipo: _tipo,
        categoria: _categoria,
        canales: _canales.toList(),
        idsProyectos: _proyectosSel.toList(),
        idsModelos: _modelosSel.toList(),
        idsNiveles: _nivelesSel.toList(),
        idsPropiedades: _propiedadesSel.toList(),
        programadoPara: _programar ? _fechaHora : null,
      );
      if (!mounted) return;
      _snack(_programar ? 'Aviso programado.' : 'Aviso enviado.');
      _titulo.clear();
      _mensaje.clear();
      setState(() {
        _programar = false;
        _fechaHora = null;
      });
      await _cargarAvisos();
    } catch (_) {
      _snack('No se pudo enviar el aviso. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cancelar(AvisoApp a) async {
    try {
      final okc = await cancelarAvisoApp(a.id);
      _snack(okc ? 'Aviso cancelado.' : 'Ya no se puede cancelar.');
      await _cargarAvisos();
    } catch (_) {
      _snack('No se pudo cancelar.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: t.color.surface,
        appBar: AppBar(
          title: const Text('Enviar avisos'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Nuevo aviso'),
              Tab(text: 'Configuración'),
            ],
          ),
        ),
        body: TabBarView(children: [_tabNuevoAviso(t), _tabConfiguracion(t)]),
      ),
    );
  }

  Widget _tabNuevoAviso(SozuTheme t) {
    final tone = t.color;
    return AdminScrollArea(
      maxWidth: 760,
      onRefresh: _cargarAvisos,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: _formKey,
            child: SCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nuevo aviso',
                    style: t.text.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                  SizedBox(height: t.space.sm),
                  // `lg` en los dos campos que son el contenido del aviso; los
                  // seis selectores de abajo van en filas de dos, y ahí manda
                  // `md` (lo mismo que usa `SAutocompleteField`).
                  STextField(
                    controller: _titulo,
                    label: 'Título',
                    hint: 'Corte de agua programado',
                    maxLength: 120,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Escribe el título'
                        : null,
                  ),
                  SizedBox(height: t.space.sm),
                  STextField(
                    controller: _mensaje,
                    label: 'Mensaje',
                    maxLines: 8,
                    maxLength: 1000,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Escribe el mensaje'
                        : null,
                  ),
                  SizedBox(height: t.space.sm),

                  // Tipo y Categoría describen el aviso, así que van con el
                  // título y el mensaje: debajo de los chips se leían como parte
                  // del grupo "Canales".
                  _dosColumnas(
                    t,
                    _SelectField(
                      label: 'Tipo',
                      value: _tipo,
                      opciones: _tipos,
                      onChanged: (v) => setState(() => _tipo = v ?? _tipo),
                    ),
                    _SelectField(
                      label: 'Categoría',
                      value: _categoria,
                      opciones: _categorias,
                      onChanged: (v) =>
                          setState(() => _categoria = v ?? _categoria),
                    ),
                  ),
                  SizedBox(height: t.space.md),

                  const SSectionLabel(text: 'Canales'),
                  Wrap(
                    spacing: t.space.xs,
                    runSpacing: t.space.xxs,
                    children: [
                      _canalChip(
                        'push',
                        'Push (app)',
                        Icons.notifications_active_outlined,
                      ),
                      _canalChip('email', 'Correo', Icons.mail_outline),
                      _canalChip('wa', 'WhatsApp', Icons.chat_outlined),
                    ],
                  ),
                  SizedBox(height: t.space.md),

                  const SSectionLabel(text: 'Destinatarios'),
                  _dosColumnas(
                    t,
                    _MultiSelectField(
                      label: 'Proyectos',
                      items: _proyectos,
                      selected: _proyectosSel,
                      placeholder: 'Todos los clientes',
                      onChanged: _onProyectosChanged,
                    ),
                    _MultiSelectField(
                      label: 'Modelos',
                      items: _modelos,
                      selected: _modelosSel,
                      placeholder: _proyectosSel.isEmpty
                          ? 'Primero elige proyecto'
                          : _cargandoModelos
                          ? 'Cargando…'
                          : 'Todos los modelos',
                      enabled: _proyectosSel.isNotEmpty && !_cargandoModelos,
                      onChanged: _onModelosChanged,
                    ),
                  ),
                  SizedBox(height: t.space.xs),
                  _dosColumnas(
                    t,
                    _MultiSelectField(
                      label: 'Niveles',
                      items: _niveles,
                      selected: _nivelesSel,
                      placeholder: _proyectosSel.isEmpty
                          ? 'Primero elige proyecto'
                          : _cargandoNiveles
                          ? 'Cargando…'
                          : _niveles.isEmpty
                          ? 'Niveles no disponibles'
                          : 'Todos los niveles',
                      enabled: _proyectosSel.isNotEmpty && !_cargandoNiveles,
                      onChanged: _onNivelesChanged,
                    ),
                    _MultiSelectField(
                      label: 'Propiedades',
                      items: _propiedades,
                      prefijo: 'U-',
                      selected: _propiedadesSel,
                      placeholder: _proyectosSel.isEmpty
                          ? 'Primero elige proyecto'
                          : _cargandoPropiedades
                          ? 'Cargando…'
                          : 'Todas las propiedades',
                      enabled:
                          _proyectosSel.isNotEmpty && !_cargandoPropiedades,
                      onChanged: (sel) => setState(
                        () => _propiedadesSel
                          ..clear()
                          ..addAll(sel),
                      ),
                    ),
                  ),
                  SizedBox(height: t.space.xs),
                  Text(
                    'Destino: $_resumenDestino',
                    style: t.text.caption.copyWith(color: tone.fgMuted),
                  ),
                  SizedBox(height: t.space.md),

                  const SSectionLabel(text: 'Programación'),
                  Row(
                    children: [
                      Switch(
                        value: _programar,
                        onChanged: (v) => setState(() => _programar = v),
                      ),
                      SizedBox(width: t.space.xxs),
                      Expanded(
                        child: Text(
                          _programar
                              ? (_fechaHora == null
                                    ? 'Elige fecha y hora'
                                    : DateFormat(
                                        'dd/MM/yyyy HH:mm',
                                      ).format(_fechaHora!))
                              : 'Enviar de inmediato',
                          style: t.text.body.copyWith(color: tone.fg),
                        ),
                      ),
                      if (_programar)
                        TextButton.icon(
                          onPressed: _elegirFechaHora,
                          icon: const Icon(Icons.event_outlined, size: 18),
                          label: const Text('Fecha y hora'),
                        ),
                    ],
                  ),
                  SizedBox(height: t.space.sm),
                  FilledButton.icon(
                    onPressed: _enviando ? null : _enviar,
                    icon: _enviando
                        ? SizedBox(
                            width: _kSpinnerSize,
                            height: _kSpinnerSize,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: tone.onPrimary,
                            ),
                          )
                        : Icon(
                            _programar
                                ? Icons.schedule_send_outlined
                                : Icons.send_outlined,
                            size: 18,
                          ),
                    label: Text(
                      _programar ? 'Programar aviso' : 'Enviar ahora',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SSectionLabel.heading(
            icon: Icons.history_outlined,
            text: 'Avisos recientes',
          ),
          if (_cargandoAvisos)
            const SSkeleton(height: 80, radius: 16)
          else if (_avisos.isEmpty)
            const SEmptyState.card(
              icon: Icons.campaign_outlined,
              title: 'Aún no hay avisos',
            )
          else
            for (final a in _avisos) ...[
              _AvisoRow(a: a, onCancelar: () => _cancelar(a)),
              SizedBox(height: t.space.sm),
            ],
        ],
      ),
    );
  }

  Widget _tabConfiguracion(SozuTheme t) {
    final tone = t.color;
    return AdminScrollArea(
      maxWidth: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Animación al llegar una notificación',
                        style: t.text.label.copyWith(color: tone.fg),
                      ),
                      Text(
                        'Aplica a todos los clientes (configuración general, '
                        'no por notificación).',
                        style: t.text.caption.copyWith(color: tone.fgMuted),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: t.space.sm),
                if (_guardandoAnimacion)
                  const SizedBox(
                    width: _kSpinnerSize,
                    height: _kSpinnerSize,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  DropdownButton<String>(
                    value: _animacion,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final a in AnimacionCampana.values)
                        DropdownMenuItem(
                          value: a.clave,
                          child: Text(a.etiqueta, style: t.text.label),
                        ),
                    ],
                    onChanged: _guardarAnimacion,
                  ),
              ],
            ),
          ),
          SizedBox(height: t.space.sm),
          // Vista previa en vivo de la animación seleccionada.
          _DemoAnimacion(variante: AnimacionCampana.desde(_animacion)),
        ],
      ),
    );
  }

  /// Dos campos por fila; en teléfono se apilan. Mismo mecanismo que
  /// `ClientFilters`: lo decide `context.bp`, nunca `kIsWeb`.
  Widget _dosColumnas(SozuTheme t, Widget izquierda, Widget derecha) {
    if (context.bp.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          izquierda,
          SizedBox(height: t.space.xs),
          derecha,
        ],
      );
    }
    // `start` y no `stretch`: con un campo en error el otro no debe crecer.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: izquierda),
        SizedBox(width: t.space.xs),
        Expanded(child: derecha),
      ],
    );
  }

  /// `SChoiceChip` y no un `FilterChip` de Material: el `chipTheme` dejaba el
  /// chip seleccionado en verde sobre verde (1.01:1 de contraste, ilegible en
  /// claro y en oscuro). La primitiva resuelve el par de roles y trae foco de
  /// teclado.
  Widget _canalChip(String canal, String label, IconData icon) {
    return SChoiceChip(
      label: label,
      icon: icon,
      selected: _canales.contains(canal),
      onSelected: (activo) => setState(() {
        activo ? _canales.add(canal) : _canales.remove(canal);
      }),
    );
  }
}

/// Vista previa en vivo de la animación de llegada: reproduce el mismo motor
/// que usa la campana real dentro de un lienzo, con la campana en la esquina
/// superior derecha como destino. Se reproduce al cambiar de variante y con
/// el botón de replay.
class _DemoAnimacion extends StatefulWidget {
  final AnimacionCampana variante;

  const _DemoAnimacion({required this.variante});

  @override
  State<_DemoAnimacion> createState() => _DemoAnimacionState();
}

class _DemoAnimacionState extends State<_DemoAnimacion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _vuelo = AnimationController(
    vsync: this,
    duration: kDuracionAnimacion,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reproducir());
  }

  @override
  void didUpdateWidget(covariant _DemoAnimacion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variante != widget.variante) _reproducir();
  }

  @override
  void dispose() {
    _vuelo.dispose();
    super.dispose();
  }

  void _reproducir() {
    _vuelo
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Vista previa · ${widget.variante.etiqueta}',
                  style: t.text.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.fgMuted,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Reproducir de nuevo',
                onPressed: _reproducir,
                icon: Icon(Icons.replay, color: tone.primaryHover),
              ),
            ],
          ),
          SizedBox(height: t.space.xxs),
          ClipRRect(
            borderRadius: t.radius.lgBorder,
            child: Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: tone.surface,
                border: Border.all(color: tone.border),
                borderRadius: t.radius.lgBorder,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final destino = Offset(w - 36, 30); // centro de la campana
                  final centro = Offset(w / 2, 175);
                  return AnimatedBuilder(
                    animation: _vuelo,
                    builder: (_, __) => Stack(
                      children: [
                        // Campana destino (portería durante el gol).
                        Positioned(
                          right: 20,
                          top: 16,
                          child: CampanaDestino(
                            variante: widget.variante,
                            animando: _vuelo.isAnimating,
                            v: _vuelo.value,
                            color: tone.fgMuted,
                          ),
                        ),
                        if (_vuelo.isAnimating)
                          frameAnimacionLlegada(
                            variante: widget.variante,
                            v: _vuelo.value,
                            centro: centro,
                            destino: destino,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de una sola opción con la etiqueta ARRIBA: se ve igual que los demás
/// campos del formulario y al tocarlo despliega el menú bajo el campo.
///
/// `DropdownButtonFormField` no sirve: su etiqueta va dentro de su propio
/// `InputDecoration`, así que solo puede ser flotante.
class _SelectField extends StatefulWidget {
  final String label;
  final String value;
  final List<String> opciones;
  final ValueChanged<String?> onChanged;

  const _SelectField({
    required this.label,
    required this.value,
    required this.opciones,
    required this.onChanged,
  });

  @override
  State<_SelectField> createState() => _SelectFieldState();
}

class _SelectFieldState extends State<_SelectField> {
  /// [STextField] es un campo de texto real, así que el valor visible vive en un
  /// controller.
  late final TextEditingController _texto = TextEditingController(
    text: _capitalizar(widget.value),
  );

  /// TRAMPA: el texto se sincroniza DESPUÉS del frame. Escribir en el controller
  /// dentro de `didUpdateWidget` notifica a sus listeners en plena fase de build
  /// y el `Form` de arriba muere con "setState() called during build".
  @override
  void didUpdateWidget(covariant _SelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_texto.text == _capitalizar(widget.value)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final visible = _capitalizar(widget.value);
      if (_texto.text != visible) _texto.text = visible;
    });
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    // Los parámetros del menú son los de `ThemeModeButton`, incluidas sus dos
    // trampas: sin `clipBehavior` y sin `menuPadding` los items se pintan
    // cuadrados sobre las esquinas del `shape`.
    return LayoutBuilder(
      builder: (context, constraints) => PopupMenuButton<String>(
        initialValue: widget.value,
        tooltip: 'Elegir ${widget.label.toLowerCase()}',
        position: PopupMenuPosition.under,
        color: tone.surface,
        clipBehavior: Clip.antiAlias,
        menuPadding: EdgeInsets.zero,
        borderRadius: t.radius.mdBorder,
        shape: RoundedRectangleBorder(
          borderRadius: t.radius.mdBorder,
          side: BorderSide(color: tone.border),
        ),
        // El menú mide lo mismo que el campo, como el de `SAutocompleteField`.
        constraints: constraints.hasBoundedWidth
            ? BoxConstraints(minWidth: constraints.maxWidth)
            : null,
        onSelected: widget.onChanged,
        itemBuilder: (context) => [
          for (final o in widget.opciones)
            PopupMenuItem<String>(
              value: o,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _capitalizar(o),
                      style: t.text.body.copyWith(
                        color: o == widget.value ? tone.primaryHover : tone.fg,
                        fontWeight: o == widget.value
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (o == widget.value)
                    Icon(
                      Icons.check,
                      size: _kSelectorIconSize,
                      color: tone.primaryHover,
                    ),
                ],
              ),
            ),
        ],
        // El campo NO debe recibir el toque: si lo recibe se enfoca y el menú no
        // abre. El gesto y el foco de teclado los da el `PopupMenuButton`.
        child: IgnorePointer(
          child: STextField(
            controller: _texto,
            label: widget.label,
            readOnly: true,
            size: STextFieldSize.md,
            suffix: Icon(
              _kSelectorUnicoIcon,
              size: _kSelectorIconSize,
              color: tone.fgSubtle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector múltiple con buscador en tiempo real: campo de solo lectura con la
/// etiqueta ARRIBA que resume la selección y abre un diálogo con búsqueda +
/// casillas.
class _MultiSelectField extends StatefulWidget {
  final String label;
  final List<CatalogoItem> items;
  final Set<int> selected;
  final String placeholder;
  final String prefijo;
  final bool enabled;
  final ValueChanged<Set<int>> onChanged;

  const _MultiSelectField({
    required this.label,
    required this.items,
    required this.selected,
    required this.placeholder,
    required this.onChanged,
    this.prefijo = '',
    this.enabled = true,
  });

  @override
  State<_MultiSelectField> createState() => _MultiSelectFieldState();
}

class _MultiSelectFieldState extends State<_MultiSelectField> {
  late final TextEditingController _resumenCtrl = TextEditingController(
    text: _resumen,
  );

  /// No se compara contra `oldWidget`: la pantalla muta SIEMPRE el mismo `Set`,
  /// así que los dos widgets comparten la selección y nunca difieren.
  ///
  /// TRAMPA: la escritura va DESPUÉS del frame. Hacerla aquí notifica a los
  /// listeners del controller en plena fase de build y el `Form` de arriba muere
  /// con "setState() called during build".
  @override
  void didUpdateWidget(covariant _MultiSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_resumenCtrl.text == _resumen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _resumenCtrl.text != _resumen) {
        _resumenCtrl.text = _resumen;
      }
    });
  }

  @override
  void dispose() {
    _resumenCtrl.dispose();
    super.dispose();
  }

  /// Vacío sin selección: ahí lo que se ve es el `hint` del campo.
  String get _resumen {
    if (widget.selected.isEmpty) return '';
    final nombres = widget.items
        .where((e) => widget.selected.contains(e.id))
        .map((e) => '${widget.prefijo}${e.nombre}')
        .toList();
    if (nombres.length <= _kResumenMaxNombres) return nombres.join(', ');
    final visibles = nombres.take(_kResumenMaxNombres).join(', ');
    return '$visibles +${nombres.length - _kResumenMaxNombres}';
  }

  Future<void> _abrir() async {
    final resultado = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _MultiSelectDialog(
        label: widget.label,
        items: widget.items,
        prefijo: widget.prefijo,
        inicial: widget.selected,
      ),
    );
    if (resultado != null) widget.onChanged(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final puedeAbrir = widget.enabled && widget.items.isNotEmpty;
    return InkWell(
      onTap: puedeAbrir ? _abrir : null,
      borderRadius: t.radius.mdBorder,
      // Ver la nota de `_SelectField`: el campo no puede quedarse el toque.
      child: IgnorePointer(
        child: STextField(
          controller: _resumenCtrl,
          label: widget.label,
          hint: widget.placeholder,
          enabled: widget.enabled,
          readOnly: true,
          size: STextFieldSize.md,
          suffix: Icon(
            _kSelectorMultipleIcon,
            size: _kSelectorIconSize,
            color: t.color.fgSubtle,
          ),
        ),
      ),
    );
  }
}

class _MultiSelectDialog extends StatefulWidget {
  final String label;
  final List<CatalogoItem> items;
  final String prefijo;
  final Set<int> inicial;

  const _MultiSelectDialog({
    required this.label,
    required this.items,
    required this.prefijo,
    required this.inicial,
  });

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late final Set<int> _sel = {...widget.inicial};
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final filtrados = _busqueda.trim().isEmpty
        ? widget.items
        : widget.items
              .where(
                (e) => e.nombre.toLowerCase().contains(
                  _busqueda.trim().toLowerCase(),
                ),
              )
              .toList();
    return AlertDialog(
      title: Text(widget.label),
      contentPadding: EdgeInsets.fromLTRB(
        t.space.lg,
        t.space.sm,
        t.space.lg,
        0,
      ),
      content: SizedBox(
        width: _kSelectorDialogWidth,
        height: _kSelectorDialogHeight,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
            SizedBox(height: t.space.xxs),
            Row(
              children: [
                Text(
                  '${_sel.length} seleccionados',
                  style: t.text.caption.copyWith(color: tone.fgSubtle),
                ),
                const Spacer(),
                // Opera sobre los resultados visibles (respeta la búsqueda).
                TextButton(
                  onPressed: filtrados.isEmpty
                      ? null
                      : () => setState(() {
                          final todosMarcados = filtrados.every(
                            (e) => _sel.contains(e.id),
                          );
                          if (todosMarcados) {
                            _sel.removeAll(filtrados.map((e) => e.id));
                          } else {
                            _sel.addAll(filtrados.map((e) => e.id));
                          }
                        }),
                  child: Text(
                    filtrados.isNotEmpty &&
                            filtrados.every((e) => _sel.contains(e.id))
                        ? 'Deseleccionar todos'
                        : 'Seleccionar todos',
                    style: t.text.caption.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Text(
                        'Sin resultados',
                        style: t.text.body.copyWith(color: tone.fgSubtle),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtrados.length,
                      itemBuilder: (ctx, i) {
                        final item = filtrados[i];
                        return CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${widget.prefijo}${item.nombre}',
                            style: t.text.body,
                          ),
                          value: _sel.contains(item.id),
                          onChanged: (v) => setState(() {
                            v == true
                                ? _sel.add(item.id)
                                : _sel.remove(item.id);
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sel.isEmpty ? null : () => setState(() => _sel.clear()),
          child: const Text('Limpiar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _sel),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _AvisoRow extends StatelessWidget {
  final AvisoApp a;
  final VoidCallback onCancelar;

  const _AvisoRow({required this.a, required this.onCancelar});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final (badge, badgeTone) = switch (a.estado) {
      'enviado' => ('Enviado', SBadgeTone.positive),
      'pendiente' => ('Programado', SBadgeTone.pending),
      'cancelado' => ('Cancelado', SBadgeTone.neutral),
      _ => ('Error', SBadgeTone.negative),
    };
    String fmtFecha(String? iso) {
      final d = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
      return d != null ? DateFormat('dd/MM/yyyy HH:mm').format(d) : '-';
    }

    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone.fg,
                  ),
                ),
              ),
              SBadge(label: badge, tone: badgeTone),
            ],
          ),
          SizedBox(height: t.space.xxs),
          Text(
            a.mensaje,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.text.bodySmall.copyWith(color: tone.fgMuted),
          ),
          SizedBox(height: t.space.xs),
          Text(
            [
              'Canales: ${a.canales.join(", ")}',
              if (a.estado == 'pendiente')
                'Envío: ${fmtFecha(a.programadoPara)}'
              else
                'Creado: ${fmtFecha(a.fechaCreacion)}',
              if (a.totalDestinatarios != null)
                '${a.totalDestinatarios} destinatarios',
            ].join(' · '),
            style: t.text.caption.copyWith(color: tone.fgSubtle),
          ),
          if (a.estado == 'pendiente')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancelar,
                child: Text(
                  'Cancelar envío',
                  style: t.text.button.copyWith(color: tone.danger),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
