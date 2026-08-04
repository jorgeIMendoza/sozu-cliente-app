import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_cliente_app/features/client/home/components/animacion_llegada.dart';
import 'package:go_router/go_router.dart';
import 'package:sozu_cliente_app/features/admin/components/admin_header_bar.dart';
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
const IconData _kMultiSelectIcon = Icons.checklist;

/// Señal del selector de UNA opción: aquí el menú sí se despliega bajo el campo.
const IconData _kSingleSelectIcon = Icons.expand_more;

/// Cuántos nombres se enumeran en el resumen antes de cortar con "+N".
const int _kSummaryMaxNames = 3;

/// "informativa" -> "Informativa". Los catálogos vienen en minúsculas.
String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _types = ['informativa', 'accionable', 'urgente', 'exito'];
const _categories = [
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

/// Ancho maximo del contenido. El mismo que `select_client_screen`: las dos son
/// pantallas de admin y no deben medir distinto.
const double _kMaxWidth = 880;

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();

  String _type = 'informativa';
  String _category = 'pagos';
  final Set<String> _channels = {'push'};

  List<CatalogoItem> _projects = [];
  List<CatalogoItem> _models = [];
  List<CatalogoItem> _levels = [];
  List<CatalogoItem> _properties = [];
  final Set<int> _selectedProjects = {};
  final Set<int> _selectedModels = {};
  final Set<int> _selectedLevels = {};
  final Set<int> _selectedProperties = {};
  bool _loadingModels = false;
  bool _loadingLevels = false;
  bool _loadingProperties = false;

  bool _schedule = false;
  DateTime? _scheduledAt;

  bool _sending = false;
  bool _loadingAnnouncements = true;
  List<AvisoApp> _announcements = [];

  // Configuración general: animación de llegada en la campana.
  String _bellAnimation = 'gol';
  bool _savingBellAnimation = false;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
    _loadAnnouncements();
    _loadBellAnimation();
  }

  Future<void> _loadBellAnimation() async {
    try {
      final anim = await ref.read(adminPortProvider).bellAnimation();
      if (mounted) setState(() => _bellAnimation = anim);
    } catch (_) {
      /* queda el default */
    }
  }

  Future<void> _saveBellAnimation(String? value) async {
    if (value == null || value == _bellAnimation) return;
    final previous = _bellAnimation;
    setState(() {
      _bellAnimation = value;
      _savingBellAnimation = true;
    });
    try {
      await ref.read(adminPortProvider).setBellAnimation(value);
      _snack('Animación actualizada para todos los clientes.');
    } catch (_) {
      if (mounted) setState(() => _bellAnimation = previous);
      _snack('No se pudo guardar la animación.');
    } finally {
      if (mounted) setState(() => _savingBellAnimation = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogs() async {
    try {
      final projects = await ref.read(adminPortProvider).projectCatalog();
      if (!mounted) return;
      setState(() => _projects = projects);
    } catch (_) {
      /* selector queda vacío; el envío a todos sigue posible */
    }
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _loadingAnnouncements = true);
    try {
      final announcements = await ref.read(adminPortProvider).announcements();
      if (!mounted) return;
      setState(() {
        _announcements = announcements;
        _loadingAnnouncements = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAnnouncements = false);
    }
  }

  /// Cascada: al cambiar proyectos se recargan modelos, niveles y propiedades
  /// y se limpian las selecciones dependientes.
  Future<void> _onProjectsChanged(Set<int> selection) async {
    setState(() {
      _selectedProjects
        ..clear()
        ..addAll(selection);
      _selectedModels.clear();
      _selectedLevels.clear();
      _selectedProperties.clear();
      _models = [];
      _levels = [];
      _properties = [];
    });
    if (selection.isEmpty) return;
    setState(() {
      _loadingModels = true;
      _loadingLevels = true;
      _loadingProperties = true;
    });
    try {
      final port = ref.read(adminPortProvider);
      final res = await Future.wait([
        port.modelCatalog(selection.toList()),
        // Tolerante: si el backend aún no expone "niveles" no debe tumbar
        // la carga de modelos/propiedades.
        port
            .levelCatalog(selection.toList())
            .catchError((_) => <CatalogoItem>[]),
        port.propertyCatalog(selection.toList()),
      ]);
      if (!mounted) return;
      setState(() {
        _models = res[0];
        _levels = res[1];
        _properties = res[2];
      });
    } catch (_) {
      /* filtros finos no disponibles */
    } finally {
      if (mounted) {
        setState(() {
          _loadingModels = false;
          _loadingLevels = false;
          _loadingProperties = false;
        });
      }
    }
  }

  /// Cascada: con modelos seleccionados se recalculan niveles y propiedades.
  Future<void> _onModelsChanged(Set<int> selection) async {
    setState(() {
      _selectedModels
        ..clear()
        ..addAll(selection);
      _selectedLevels.clear();
      _selectedProperties.clear();
      _levels = [];
      _properties = [];
      _loadingLevels = true;
      _loadingProperties = true;
    });
    try {
      final port = ref.read(adminPortProvider);
      final res = await Future.wait([
        port
            .levelCatalog(
              _selectedProjects.toList(),
              modelIds: selection.toList(),
            )
            .catchError((_) => <CatalogoItem>[]),
        port.propertyCatalog(
          _selectedProjects.toList(),
          modelIds: selection.toList(),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _levels = res[0];
        _properties = res[1];
      });
    } catch (_) {
      /* filtro fino no disponible */
    } finally {
      if (mounted) {
        setState(() {
          _loadingLevels = false;
          _loadingProperties = false;
        });
      }
    }
  }

  /// Cascada: con niveles seleccionados solo se listan sus propiedades.
  Future<void> _onLevelsChanged(Set<int> selection) async {
    setState(() {
      _selectedLevels
        ..clear()
        ..addAll(selection);
      _selectedProperties.clear();
      _properties = [];
      _loadingProperties = true;
    });
    try {
      final props = await ref
          .read(adminPortProvider)
          .propertyCatalog(
            _selectedProjects.toList(),
            modelIds: _selectedModels.toList(),
            levelIds: selection.toList(),
          );
      if (mounted) setState(() => _properties = props);
    } catch (_) {
      /* filtro fino no disponible */
    } finally {
      if (mounted) setState(() => _loadingProperties = false);
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String get _targetSummary {
    if (_selectedProjects.isEmpty) return 'Todos los clientes';
    String names(
      List<CatalogoItem> items,
      Set<int> selection, [
      String prefix = '',
    ]) => items
        .where((e) => selection.contains(e.id))
        .map((e) => '$prefix${e.nombre}')
        .join(', ');
    return [
      names(_projects, _selectedProjects),
      if (_selectedModels.isNotEmpty)
        'Modelos: ${names(_models, _selectedModels)}',
      if (_selectedLevels.isNotEmpty)
        'Niveles: ${names(_levels, _selectedLevels)}',
      if (_selectedProperties.isNotEmpty)
        'Unidades: ${names(_properties, _selectedProperties, 'U-')}',
    ].join(' · ');
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_channels.isEmpty) {
      _snack('Selecciona al menos un canal.');
      return;
    }
    if (_schedule && _scheduledAt == null) {
      _snack('Elige fecha y hora para programar.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_schedule ? 'Programar aviso' : 'Enviar aviso ahora'),
        content: Text(
          'Destino: $_targetSummary\n'
          'Canales: ${_channels.join(', ')}'
          '${_schedule ? '\nEnvío: ${DateFormat('dd/MM/yyyy HH:mm').format(_scheduledAt!)}' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_schedule ? 'Programar' : 'Enviar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(adminPortProvider)
          .createAnnouncement(
            title: _title.text.trim(),
            message: _message.text.trim(),
            type: _type,
            category: _category,
            channels: _channels.toList(),
            projectIds: _selectedProjects.toList(),
            modelIds: _selectedModels.toList(),
            levelIds: _selectedLevels.toList(),
            propertyIds: _selectedProperties.toList(),
            scheduledFor: _schedule ? _scheduledAt : null,
          );
      if (!mounted) return;
      _snack(_schedule ? 'Aviso programado.' : 'Aviso enviado.');
      _title.clear();
      _message.clear();
      setState(() {
        _schedule = false;
        _scheduledAt = null;
      });
      await _loadAnnouncements();
    } catch (_) {
      _snack('No se pudo enviar el aviso. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancel(AvisoApp a) async {
    try {
      final ok = await ref.read(adminPortProvider).cancelAnnouncement(a.id);
      _snack(ok ? 'Aviso cancelado.' : 'Ya no se puede cancelar.');
      await _loadAnnouncements();
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
    // Mismo layout y mismo ancho que el selector de cliente. Antes montaba su
    // propio Scaffold con AppBar, y el AppBar ocupa el ancho COMPLETO de la
    // ventana mientras el contenido va centrado: el titulo quedaba pegado al
    // borde izquierdo, sin relacion con la columna. Es el motivo por el que
    // existe `AdminHeaderBar`.
    return DefaultTabController(
      length: 2,
      child: AdminLayout.fixed(
        maxWidth: _kMaxWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminHeaderBar(
              title: 'Enviar avisos',
              actions: [
                AdminHeaderAction(
                  label: 'Volver',
                  icon: Icons.arrow_back,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
            SizedBox(height: t.space.sm),
            const TabBar(
              tabs: [
                Tab(text: 'Nuevo aviso'),
                Tab(text: 'Configuración'),
              ],
            ),
            SizedBox(height: t.space.md),
            // `Expanded` + scroll por tab: un `TabBarView` no tiene alto
            // intrinseco, asi que no cabe en un scroll de pagina. Aqui el
            // encabezado y los tabs quedan fijos y desplaza el contenido, que es
            // el patron correcto para una pantalla con pestanas.
            Expanded(
              child: TabBarView(
                children: [_newAnnouncementTab(t), _settingsTab(t)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newAnnouncementTab(SozuTheme t) {
    final tone = t.color;
    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      child: SingleChildScrollView(
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
                      controller: _title,
                      label: 'Título',
                      hint: 'Corte de agua programado',
                      maxLength: 120,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Escribe el título'
                          : null,
                    ),
                    SizedBox(height: t.space.sm),
                    STextField(
                      controller: _message,
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
                    _twoColumns(
                      t,
                      _SelectField(
                        label: 'Tipo',
                        value: _type,
                        options: _types,
                        onChanged: (v) => setState(() => _type = v ?? _type),
                      ),
                      _SelectField(
                        label: 'Categoría',
                        value: _category,
                        options: _categories,
                        onChanged: (v) =>
                            setState(() => _category = v ?? _category),
                      ),
                    ),
                    SizedBox(height: t.space.md),

                    const SSectionLabel(text: 'Canales'),
                    Wrap(
                      spacing: t.space.xs,
                      runSpacing: t.space.xxs,
                      children: [
                        _channelChip(
                          'push',
                          'Push (app)',
                          Icons.notifications_active_outlined,
                        ),
                        _channelChip('email', 'Correo', Icons.mail_outline),
                        _channelChip('wa', 'WhatsApp', Icons.chat_outlined),
                      ],
                    ),
                    SizedBox(height: t.space.md),

                    const SSectionLabel(text: 'Destinatarios'),
                    _twoColumns(
                      t,
                      _MultiSelectField(
                        label: 'Proyectos',
                        items: _projects,
                        selected: _selectedProjects,
                        placeholder: 'Todos los clientes',
                        onChanged: _onProjectsChanged,
                      ),
                      _MultiSelectField(
                        label: 'Modelos',
                        items: _models,
                        selected: _selectedModels,
                        placeholder: _selectedProjects.isEmpty
                            ? 'Primero elige proyecto'
                            : _loadingModels
                            ? 'Cargando…'
                            : 'Todos los modelos',
                        enabled:
                            _selectedProjects.isNotEmpty && !_loadingModels,
                        onChanged: _onModelsChanged,
                      ),
                    ),
                    SizedBox(height: t.space.xs),
                    _twoColumns(
                      t,
                      _MultiSelectField(
                        label: 'Niveles',
                        items: _levels,
                        selected: _selectedLevels,
                        placeholder: _selectedProjects.isEmpty
                            ? 'Primero elige proyecto'
                            : _loadingLevels
                            ? 'Cargando…'
                            : _levels.isEmpty
                            ? 'Niveles no disponibles'
                            : 'Todos los niveles',
                        enabled:
                            _selectedProjects.isNotEmpty && !_loadingLevels,
                        onChanged: _onLevelsChanged,
                      ),
                      _MultiSelectField(
                        label: 'Propiedades',
                        items: _properties,
                        prefix: 'U-',
                        selected: _selectedProperties,
                        placeholder: _selectedProjects.isEmpty
                            ? 'Primero elige proyecto'
                            : _loadingProperties
                            ? 'Cargando…'
                            : 'Todas las propiedades',
                        enabled:
                            _selectedProjects.isNotEmpty && !_loadingProperties,
                        onChanged: (selection) => setState(
                          () => _selectedProperties
                            ..clear()
                            ..addAll(selection),
                        ),
                      ),
                    ),
                    SizedBox(height: t.space.xs),
                    Text(
                      'Destino: $_targetSummary',
                      style: t.text.caption.copyWith(color: tone.fgMuted),
                    ),
                    SizedBox(height: t.space.md),

                    const SSectionLabel(text: 'Programación'),
                    Row(
                      children: [
                        Switch(
                          value: _schedule,
                          onChanged: (v) => setState(() => _schedule = v),
                        ),
                        SizedBox(width: t.space.xxs),
                        Expanded(
                          child: Text(
                            _schedule
                                ? (_scheduledAt == null
                                      ? 'Elige fecha y hora'
                                      : DateFormat(
                                          'dd/MM/yyyy HH:mm',
                                        ).format(_scheduledAt!))
                                : 'Enviar de inmediato',
                            style: t.text.body.copyWith(color: tone.fg),
                          ),
                        ),
                        if (_schedule)
                          TextButton.icon(
                            onPressed: _pickDateTime,
                            icon: const Icon(Icons.event_outlined, size: 18),
                            label: const Text('Fecha y hora'),
                          ),
                      ],
                    ),
                    SizedBox(height: t.space.sm),
                    // Sin icono: la accion principal la dice el texto, y el
                    // `loading` del propio SButton sustituye al spinner a mano.
                    SButton(
                      label: _schedule ? 'Programar aviso' : 'Enviar ahora',
                      size: SButtonSize.lg,
                      loading: _sending,
                      loadingLabel: _schedule
                          ? 'Programando...'
                          : 'Enviando...',
                      onPressed: _sending ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),

            const SSectionLabel.heading(
              icon: Icons.history_outlined,
              text: 'Avisos recientes',
            ),
            if (_loadingAnnouncements)
              const SSkeleton(height: 80, radius: 16)
            else if (_announcements.isEmpty)
              const SEmptyState.card(
                icon: Icons.campaign_outlined,
                title: 'Aún no hay avisos',
              )
            else
              for (final a in _announcements) ...[
                _AnnouncementRow(a: a, onCancel: () => _cancel(a)),
                SizedBox(height: t.space.sm),
              ],
          ],
        ),
      ),
    );
  }

  Widget _settingsTab(SozuTheme t) {
    final tone = t.color;
    return SingleChildScrollView(
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
                if (_savingBellAnimation)
                  const SizedBox(
                    width: _kSpinnerSize,
                    height: _kSpinnerSize,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  DropdownButton<String>(
                    value: _bellAnimation,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final a in AnimacionCampana.values)
                        DropdownMenuItem(
                          value: a.clave,
                          child: Text(a.etiqueta, style: t.text.label),
                        ),
                    ],
                    onChanged: _saveBellAnimation,
                  ),
              ],
            ),
          ),
          SizedBox(height: t.space.sm),
          // Vista previa en vivo de la animación seleccionada.
          _AnimationPreview(variant: AnimacionCampana.desde(_bellAnimation)),
        ],
      ),
    );
  }

  /// Dos campos por fila; en teléfono se apilan. Mismo mecanismo que
  /// `ClientFilters`: lo decide `context.bp`, nunca `kIsWeb`.
  Widget _twoColumns(SozuTheme t, Widget left, Widget right) {
    if (context.bp.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          SizedBox(height: t.space.xs),
          right,
        ],
      );
    }
    // `start` y no `stretch`: con un campo en error el otro no debe crecer.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: t.space.xs),
        Expanded(child: right),
      ],
    );
  }

  /// `SChoiceChip` y no un `FilterChip` de Material: el `chipTheme` dejaba el
  /// chip seleccionado en verde sobre verde (1.01:1 de contraste, ilegible en
  /// claro y en oscuro). La primitiva resuelve el par de roles y trae foco de
  /// teclado.
  Widget _channelChip(String channel, String label, IconData icon) {
    return SChoiceChip(
      label: label,
      icon: icon,
      selected: _channels.contains(channel),
      onSelected: (isSelected) => setState(() {
        isSelected ? _channels.add(channel) : _channels.remove(channel);
      }),
    );
  }
}

/// Vista previa en vivo de la animación de llegada: reproduce el mismo motor
/// que usa la campana real dentro de un lienzo, con la campana en la esquina
/// superior derecha como destino. Se reproduce al cambiar de variante y con
/// el botón de replay.
class _AnimationPreview extends StatefulWidget {
  final AnimacionCampana variant;

  const _AnimationPreview({required this.variant});

  @override
  State<_AnimationPreview> createState() => _AnimationPreviewState();
}

class _AnimationPreviewState extends State<_AnimationPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: kDuracionAnimacion,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void didUpdateWidget(covariant _AnimationPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant != widget.variant) _play();
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  void _play() {
    _flight
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
                  'Vista previa · ${widget.variant.etiqueta}',
                  style: t.text.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.fgMuted,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Reproducir de nuevo',
                onPressed: _play,
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
                  final target = Offset(w - 36, 30); // centro de la campana
                  final center = Offset(w / 2, 175);
                  return AnimatedBuilder(
                    animation: _flight,
                    builder: (_, __) => Stack(
                      children: [
                        // Campana destino (portería durante el gol).
                        Positioned(
                          right: 20,
                          top: 16,
                          child: CampanaDestino(
                            variante: widget.variant,
                            animando: _flight.isAnimating,
                            v: _flight.value,
                            color: tone.fgMuted,
                          ),
                        ),
                        if (_flight.isAnimating)
                          frameAnimacionLlegada(
                            variante: widget.variant,
                            v: _flight.value,
                            centro: center,
                            destino: target,
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
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _SelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_SelectField> createState() => _SelectFieldState();
}

class _SelectFieldState extends State<_SelectField> {
  /// [STextField] es un campo de texto real, así que el valor visible vive en un
  /// controller.
  late final TextEditingController _controller = TextEditingController(
    text: _capitalize(widget.value),
  );

  /// TRAMPA: el texto se sincroniza DESPUÉS del frame. Escribir en el controller
  /// dentro de `didUpdateWidget` notifica a sus listeners en plena fase de build
  /// y el `Form` de arriba muere con "setState() called during build".
  @override
  void didUpdateWidget(covariant _SelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text == _capitalize(widget.value)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final visible = _capitalize(widget.value);
      if (_controller.text != visible) _controller.text = visible;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    // Dos trampas del PopupMenuButton de Material: sin `clipBehavior` y sin
    // `menuPadding` los items se pintan cuadrados sobre las esquinas del
    // `shape`.
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
          for (final o in widget.options)
            PopupMenuItem<String>(
              value: o,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _capitalize(o),
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
            controller: _controller,
            label: widget.label,
            readOnly: true,
            size: STextFieldSize.md,
            suffix: Icon(
              _kSingleSelectIcon,
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
  final String prefix;
  final bool enabled;
  final ValueChanged<Set<int>> onChanged;

  const _MultiSelectField({
    required this.label,
    required this.items,
    required this.selected,
    required this.placeholder,
    required this.onChanged,
    this.prefix = '',
    this.enabled = true,
  });

  @override
  State<_MultiSelectField> createState() => _MultiSelectFieldState();
}

class _MultiSelectFieldState extends State<_MultiSelectField> {
  late final TextEditingController _summaryController = TextEditingController(
    text: _summary,
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
    if (_summaryController.text == _summary) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _summaryController.text != _summary) {
        _summaryController.text = _summary;
      }
    });
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  /// Vacío sin selección: ahí lo que se ve es el `hint` del campo.
  String get _summary {
    if (widget.selected.isEmpty) return '';
    final names = widget.items
        .where((e) => widget.selected.contains(e.id))
        .map((e) => '${widget.prefix}${e.nombre}')
        .toList();
    if (names.length <= _kSummaryMaxNames) return names.join(', ');
    final shown = names.take(_kSummaryMaxNames).join(', ');
    return '$shown +${names.length - _kSummaryMaxNames}';
  }

  Future<void> _openDialog() async {
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _MultiSelectDialog(
        label: widget.label,
        items: widget.items,
        prefix: widget.prefix,
        initial: widget.selected,
      ),
    );
    if (result != null) widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final canOpen = widget.enabled && widget.items.isNotEmpty;
    return InkWell(
      onTap: canOpen ? _openDialog : null,
      borderRadius: t.radius.mdBorder,
      // Ver la nota de `_SelectField`: el campo no puede quedarse el toque.
      child: IgnorePointer(
        child: STextField(
          controller: _summaryController,
          label: widget.label,
          hint: widget.placeholder,
          enabled: widget.enabled,
          readOnly: true,
          size: STextFieldSize.md,
          suffix: Icon(
            _kMultiSelectIcon,
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
  final String prefix;
  final Set<int> initial;

  const _MultiSelectDialog({
    required this.label,
    required this.items,
    required this.prefix,
    required this.initial,
  });

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late final Set<int> _selection = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final filtered = _query.trim().isEmpty
        ? widget.items
        : widget.items
              .where(
                (e) => e.nombre.toLowerCase().contains(
                  _query.trim().toLowerCase(),
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
              onChanged: (v) => setState(() => _query = v),
            ),
            SizedBox(height: t.space.xxs),
            Row(
              children: [
                Text(
                  '${_selection.length} seleccionados',
                  style: t.text.caption.copyWith(color: tone.fgSubtle),
                ),
                const Spacer(),
                // Opera sobre los resultados visibles (respeta la búsqueda).
                TextButton(
                  onPressed: filtered.isEmpty
                      ? null
                      : () => setState(() {
                          final allChecked = filtered.every(
                            (e) => _selection.contains(e.id),
                          );
                          if (allChecked) {
                            _selection.removeAll(filtered.map((e) => e.id));
                          } else {
                            _selection.addAll(filtered.map((e) => e.id));
                          }
                        }),
                  child: Text(
                    filtered.isNotEmpty &&
                            filtered.every((e) => _selection.contains(e.id))
                        ? 'Deseleccionar todos'
                        : 'Seleccionar todos',
                    style: t.text.caption.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Sin resultados',
                        style: t.text.body.copyWith(color: tone.fgSubtle),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final item = filtered[i];
                        return CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${widget.prefix}${item.nombre}',
                            style: t.text.body,
                          ),
                          value: _selection.contains(item.id),
                          onChanged: (v) => setState(() {
                            v == true
                                ? _selection.add(item.id)
                                : _selection.remove(item.id);
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      // Una fila, no `actions`: el `OverflowBar` de `AlertDialog` los apila en
      // vertical cuando no caben, y apilados quedaban pegados y sin jerarquia.
      // Los tres al mismo tamano (`sm`); lo que los distingue es la variante.
      actionsPadding: EdgeInsets.fromLTRB(
        t.space.md,
        t.space.xs,
        t.space.md,
        t.space.md,
      ),
      actions: [
        Row(
          children: [
            SButton.ghost(
              label: 'Limpiar',
              size: SButtonSize.sm,
              onPressed: _selection.isEmpty
                  ? null
                  : () => setState(() => _selection.clear()),
            ),
            const Spacer(),
            SButton.secondary(
              label: 'Cancelar',
              size: SButtonSize.sm,
              fullWidth: false,
              onPressed: () => Navigator.pop(context),
            ),
            SizedBox(width: t.space.xs),
            SButton(
              label: 'Aplicar',
              size: SButtonSize.sm,
              fullWidth: false,
              onPressed: () => Navigator.pop(context, _selection),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  final AvisoApp a;
  final VoidCallback onCancel;

  const _AnnouncementRow({required this.a, required this.onCancel});

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
    String formatDate(String? iso) {
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
                'Envío: ${formatDate(a.programadoPara)}'
              else
                'Creado: ${formatDate(a.fechaCreacion)}',
              if (a.totalDestinatarios != null)
                '${a.totalDestinatarios} destinatarios',
            ].join(' · '),
            style: t.text.caption.copyWith(color: tone.fgSubtle),
          ),
          if (a.estado == 'pendiente')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
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
