import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/components/catalog_select_fields.dart';
import 'package:sozu_cliente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

const _types = ['informativa', 'accionable', 'urgente', 'exito'];
const _categories = [
  'pagos',
  'documentos',
  'mantenimiento',
  'construccion',
  'reventa',
  'entrega',
];

/// Alta de un aviso: contenido, canales, destino y programación.
///
/// El destino se acota en cascada (proyecto → modelo → nivel → propiedad); sin
/// filtros va a todos los clientes. Al enviar invalida
/// `adminAnnouncementsProvider`.
class AnnouncementForm extends ConsumerStatefulWidget {
  const AnnouncementForm({super.key});

  @override
  ConsumerState<AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends ConsumerState<AnnouncementForm> {
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

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
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

  /// Fuerza recarga de la lista. Solo para el pull-to-refresh y para despues
  /// de enviar: la lista vive en `RecentAnnouncements`, que observa el
  /// provider, asi que basta con invalidarlo.
  Future<void> _loadAnnouncements() async {
    ref.invalidate(adminAnnouncementsProvider);
    await ref.read(adminAnnouncementsProvider.future);
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) => _formulario(context.s);

  /// Sin scroll propio: lo pone `AdminLayout`, igual que el pull-to-refresh.
  Widget _formulario(SozuTheme t) {
    final tone = t.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Form(
          key: _formKey,
          child: SCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // `lg` en los campos de contenido; los selectores de abajo van
                // en filas de dos y ahi manda `md`.
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
                  // Caja fija de 6 líneas: `minLines == maxLines`, así que no
                  // crece al escribir -el formulario no se reacomoda debajo- y
                  // el texto de más desplaza por dentro.
                  minLines: 6,
                  maxLines: 6,
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
                  CatalogSelectField(
                    label: 'Tipo',
                    value: _type,
                    options: _types,
                    onChanged: (v) => setState(() => _type = v ?? _type),
                  ),
                  CatalogSelectField(
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
                  CatalogMultiSelectField(
                    label: 'Proyectos',
                    items: _projects,
                    selected: _selectedProjects,
                    placeholder: 'Todos los clientes',
                    onChanged: _onProjectsChanged,
                  ),
                  CatalogMultiSelectField(
                    label: 'Modelos',
                    items: _models,
                    selected: _selectedModels,
                    placeholder: _selectedProjects.isEmpty
                        ? 'Primero elige proyecto'
                        : _loadingModels
                        ? 'Cargando…'
                        : 'Todos los modelos',
                    enabled: _selectedProjects.isNotEmpty && !_loadingModels,
                    onChanged: _onModelsChanged,
                  ),
                ),
                SizedBox(height: t.space.xs),
                _twoColumns(
                  t,
                  CatalogMultiSelectField(
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
                    enabled: _selectedProjects.isNotEmpty && !_loadingLevels,
                    onChanged: _onLevelsChanged,
                  ),
                  CatalogMultiSelectField(
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
                  loadingLabel: _schedule ? 'Programando...' : 'Enviando...',
                  onPressed: _sending ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ],
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

  /// WARN: `SChoiceChip` y NO `FilterChip`: el `chipTheme` deja el chip
  /// seleccionado en verde sobre verde (1.01:1, ilegible en los dos temas).
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
