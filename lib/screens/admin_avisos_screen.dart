import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';

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
class AdminAvisosScreen extends ConsumerStatefulWidget {
  const AdminAvisosScreen({super.key});

  @override
  ConsumerState<AdminAvisosScreen> createState() => _AdminAvisosScreenState();
}

class _AdminAvisosScreenState extends ConsumerState<AdminAvisosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _mensaje = TextEditingController();

  String _tipo = 'informativa';
  String _categoria = 'pagos';
  final Set<String> _canales = {'push'};

  List<CatalogoItem> _proyectos = [];
  List<CatalogoItem> _modelos = [];
  List<CatalogoItem> _propiedades = [];
  final Set<int> _proyectosSel = {};
  final Set<int> _modelosSel = {};
  final Set<int> _propiedadesSel = {};
  bool _cargandoModelos = false;
  bool _cargandoPropiedades = false;

  bool _programar = false;
  DateTime? _fechaHora;

  bool _enviando = false;
  bool _cargandoAvisos = true;
  List<AvisoApp> _avisos = [];

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
    _cargarAvisos();
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
    } catch (_) {/* selector queda vacío; el envío a todos sigue posible */}
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

  /// Cascada: al cambiar proyectos se recargan modelos y propiedades y se
  /// limpian las selecciones dependientes.
  Future<void> _onProyectosChanged(Set<int> sel) async {
    setState(() {
      _proyectosSel
        ..clear()
        ..addAll(sel);
      _modelosSel.clear();
      _propiedadesSel.clear();
      _modelos = [];
      _propiedades = [];
    });
    if (sel.isEmpty) return;
    setState(() {
      _cargandoModelos = true;
      _cargandoPropiedades = true;
    });
    try {
      final res = await Future.wait([
        fetchAvisosModelos(sel.toList()),
        fetchAvisosPropiedades(sel.toList()),
      ]);
      if (!mounted) return;
      setState(() {
        _modelos = res[0];
        _propiedades = res[1];
      });
    } catch (_) {/* filtros finos no disponibles */} finally {
      if (mounted) {
        setState(() {
          _cargandoModelos = false;
          _cargandoPropiedades = false;
        });
      }
    }
  }

  /// Cascada: con modelos seleccionados solo se listan sus propiedades.
  Future<void> _onModelosChanged(Set<int> sel) async {
    setState(() {
      _modelosSel
        ..clear()
        ..addAll(sel);
      _propiedadesSel.clear();
      _propiedades = [];
      _cargandoPropiedades = true;
    });
    try {
      final props = await fetchAvisosPropiedades(
        _proyectosSel.toList(),
        idsModelos: sel.toList(),
      );
      if (mounted) setState(() => _propiedades = props);
    } catch (_) {/* filtro fino no disponible */} finally {
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
    String nombres(List<CatalogoItem> items, Set<int> sel, [String pref = '']) =>
        items
            .where((e) => sel.contains(e.id))
            .map((e) => '$pref${e.nombre}')
            .join(', ');
    return [
      nombres(_proyectos, _proyectosSel),
      if (_modelosSel.isNotEmpty) 'Modelos: ${nombres(_modelos, _modelosSel)}',
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
    final tone = SozuTone.of(context);
    return Scaffold(
      backgroundColor: tone.surface,
      appBar: AppBar(title: const Text('Enviar avisos')),
      body: WebFrame(
        maxWidth: 760,
        child: RefreshIndicator(
          onRefresh: _cargarAvisos,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Form(
                key: _formKey,
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nuevo aviso',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tone.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titulo,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Título',
                          hintText: 'Ej. Corte de agua programado',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Escribe el título'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _mensaje,
                        minLines: 3,
                        maxLines: 8,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Mensaje',
                          alignLabelWithHint: true,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Escribe el mensaje'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      _label(tone, 'CANALES'),
                      Wrap(
                        spacing: 8,
                        children: [
                          _canalChip('push', 'Push (app)', Icons.notifications_active_outlined),
                          _canalChip('email', 'Correo', Icons.mail_outline),
                          _canalChip('wa', 'WhatsApp', Icons.chat_outlined),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _dropdown(
                              'Tipo',
                              _tipo,
                              _tipos,
                              (v) => setState(() => _tipo = v ?? _tipo),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dropdown(
                              'Categoría',
                              _categoria,
                              _categorias,
                              (v) =>
                                  setState(() => _categoria = v ?? _categoria),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _label(tone, 'DESTINATARIOS'),
                      _MultiSelectField(
                        label: 'Proyectos',
                        items: _proyectos,
                        selected: _proyectosSel,
                        placeholder: 'Todos los clientes',
                        onChanged: _onProyectosChanged,
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 6),
                      Text(
                        'Destino: $_resumenDestino',
                        style: TextStyle(
                          fontSize: 12,
                          color: tone.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _label(tone, 'PROGRAMACIÓN'),
                      Row(
                        children: [
                          Switch(
                            value: _programar,
                            onChanged: (v) => setState(() => _programar = v),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _programar
                                  ? (_fechaHora == null
                                        ? 'Elige fecha y hora'
                                        : DateFormat(
                                            'dd/MM/yyyy HH:mm',
                                          ).format(_fechaHora!))
                                  : 'Enviar de inmediato',
                              style: TextStyle(
                                fontSize: 14,
                                color: tone.textPrimary,
                              ),
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
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _enviando ? null : _enviar,
                        icon: _enviando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
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

              const SectionTitle(
                icon: Icons.history_outlined,
                text: 'Avisos recientes',
              ),
              if (_cargandoAvisos)
                const Skeleton(height: 80, radius: 16)
              else if (_avisos.isEmpty)
                const EmptyCard(
                  icon: Icons.campaign_outlined,
                  text: 'Aún no hay avisos',
                )
              else
                for (final a in _avisos) ...[
                  _AvisoRow(a: a, onCancelar: () => _cancelar(a)),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(SozuTone tone, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1,
        fontWeight: FontWeight.w600,
        color: tone.textMuted,
      ),
    ),
  );

  Widget _canalChip(String canal, String label, IconData icon) {
    final activo = _canales.contains(canal);
    return FilterChip(
      selected: activo,
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onSelected: (v) => setState(() {
        v ? _canales.add(canal) : _canales.remove(canal);
      }),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> opciones,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final o in opciones)
          DropdownMenuItem(
            value: o,
            child: Text(o[0].toUpperCase() + o.substring(1)),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Selector múltiple con buscador en tiempo real: campo que resume la
/// selección y abre un diálogo con búsqueda + checkboxes.
class _MultiSelectField extends StatelessWidget {
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

  String get _resumen {
    if (selected.isEmpty) return placeholder;
    final nombres = items
        .where((e) => selected.contains(e.id))
        .map((e) => '$prefijo${e.nombre}')
        .toList();
    if (nombres.length <= 3) return nombres.join(', ');
    return '${nombres.take(3).join(', ')} +${nombres.length - 3}';
  }

  Future<void> _abrir(BuildContext context) async {
    final resultado = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _MultiSelectDialog(
        label: label,
        items: items,
        prefijo: prefijo,
        inicial: selected,
      ),
    );
    if (resultado != null) onChanged(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return InkWell(
      onTap: enabled && items.isNotEmpty ? () => _abrir(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          _resumen,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: selected.isEmpty || !enabled
                ? tone.textMuted
                : tone.textPrimary,
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
    final tone = SozuTone.of(context);
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
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 380,
        height: 420,
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
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${_sel.length} seleccionados',
                  style: TextStyle(fontSize: 12, color: tone.textMuted),
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
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: tone.textMuted),
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
                            style: const TextStyle(fontSize: 14),
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
          onPressed: _sel.isEmpty
              ? null
              : () => setState(() => _sel.clear()),
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
    final tone = SozuTone.of(context);
    final (badge, badgeTone) = switch (a.estado) {
      'enviado' => ('Enviado', BadgeTone.positive),
      'pendiente' => ('Programado', BadgeTone.pending),
      'cancelado' => ('Cancelado', BadgeTone.neutral),
      _ => ('Error', BadgeTone.negative),
    };
    String fmtFecha(String? iso) {
      final d = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
      return d != null ? DateFormat('dd/MM/yyyy HH:mm').format(d) : '—';
    }

    return AppCard(
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tone.textPrimary,
                  ),
                ),
              ),
              StatusBadge(label: badge, tone: badgeTone),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            a.mensaje,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: tone.textSecondary),
          ),
          const SizedBox(height: 6),
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
            style: TextStyle(fontSize: 12, color: tone.textMuted),
          ),
          if (a.estado == 'pendiente')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancelar,
                child: Text(
                  'Cancelar envío',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tone.negative,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
