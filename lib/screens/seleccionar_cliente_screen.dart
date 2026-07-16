import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/impersonation_provider.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';

/// Selector de cliente para super administradores (solo web).
/// El admin elige un cliente y navega el portal viendo sus datos.
///
/// Paridad con el "Ver como" del portal admin: al filtrar por Proyecto +
/// Unidad (número de propiedad) se muestra arriba el grupo
/// "Copropietarios (N)" (o "Dueño de la propiedad" si es uno) con los
/// clientes dueños de esa unidad, y debajo "Todos los clientes".
class SeleccionarClienteScreen extends ConsumerStatefulWidget {
  const SeleccionarClienteScreen({super.key});

  @override
  ConsumerState<SeleccionarClienteScreen> createState() =>
      _SeleccionarClienteScreenState();
}

class _SeleccionarClienteScreenState
    extends ConsumerState<SeleccionarClienteScreen> {
  final _search = TextEditingController();
  final _unidad = TextEditingController();
  Timer? _debounce;
  String _query = '';

  /// Filtro "Ver como" por propiedad (paridad con el portal admin).
  int? _proyectoId;
  String _unidadQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _unidad.dispose();
    super.dispose();
  }

  static const _minQueryLength = 2;

  bool get _queryTooShort => _query.trim().length < _minQueryLength;

  bool get _filtroPropiedadActivo =>
      _proyectoId != null && _unidadQuery.isNotEmpty;

  void _onUnidadChanged(String v) {
    setState(() {}); // refresca el icono de limpiar de inmediato
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _unidadQuery = v.trim());
    });
  }

  List<AdminCliente> _filtrar(List<AdminCliente> clientes) {
    final q = _query.trim().toLowerCase();
    if (q.length < _minQueryLength) return const [];
    return clientes
        .where(
          (c) =>
              c.nombre.toLowerCase().contains(q) ||
              (c.email ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  /// Tarjeta de cliente (nombre + correo, marcado si es el impersonado).
  Widget _clienteTile(AdminCliente c, SozuTone tone) {
    final imp = ref.watch(impersonationProvider);
    final seleccionado = imp.idPersona == c.idPersona;
    return AppCard(
      borderColor: seleccionado ? tone.primaryDark : null,
      padding: EdgeInsets.zero,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          c.nombre,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: tone.textPrimary,
          ),
        ),
        subtitle: c.email == null
            ? null
            : Text(c.email!, style: TextStyle(color: tone.textSecondary)),
        trailing: seleccionado
            ? const StatusBadge(label: 'Viendo', tone: BadgeTone.positive)
            : Icon(Icons.chevron_right, color: tone.textMuted),
        onTap: () {
          ref.read(impersonationProvider).select(c.idPersona, c.nombre, c.email);
          context.go('/inicio');
        },
      ),
    );
  }

  /// Encabezado de grupo dentro de la lista ("Copropietarios (N)" /
  /// "Todos los clientes").
  Widget _headerGrupo(String texto, SozuTone tone, {IconData? icon}) =>
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: tone.textMuted),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                texto.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: tone.textMuted,
                ),
              ),
            ),
          ],
        ),
      );

  /// Sección "Copropietarios (N)" / "Dueño de la propiedad" cuando el filtro
  /// Proyecto + Unidad está activo.
  List<Widget> _seccionPropietarios(SozuTone tone) {
    final propietarios = ref.watch(
      adminPropietariosProvider((
        idProyecto: _proyectoId!,
        numero: _unidadQuery,
      )),
    );
    return propietarios.when(
      loading: () => [
        _headerGrupo('Copropietarios', tone, icon: Icons.group_outlined),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: 18),
              SizedBox(height: 8),
              Skeleton(width: 200, height: 14),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      error: (_, __) => [
        ErrorCard(
          title: 'No pudimos cargar los clientes de la unidad',
          onRetry: () => ref.invalidate(adminPropietariosProvider),
        ),
        const SizedBox(height: 16),
      ],
      data: (lista) {
        if (lista.isEmpty) {
          return [
            const EmptyCard(
              icon: Icons.home_outlined,
              text: 'No encontramos clientes vinculados a esa unidad.',
            ),
            const SizedBox(height: 16),
          ];
        }
        return [
          _headerGrupo(
            lista.length > 1
                ? 'Copropietarios (${lista.length})'
                : 'Dueño de la propiedad',
            tone,
            icon: Icons.group_outlined,
          ),
          for (final c in lista) ...[
            _clienteTile(c, tone),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
        ];
      },
    );
  }

  /// Fila de filtros "Ver como": Proyecto + Unidad (número de propiedad).
  Widget _filtrosPropiedad(SozuTone tone) {
    final proyectos =
        ref.watch(adminProyectosProvider).asData?.value ?? const <CatalogoItem>[];
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int?>(
            initialValue: _proyectoId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Proyecto',
              prefixIcon: Icon(Icons.apartment_outlined, size: 20),
              isDense: true,
            ),
            hint: const Text('Proyecto'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Todos los proyectos'),
              ),
              for (final p in proyectos)
                DropdownMenuItem<int?>(
                  value: p.id,
                  child: Text(p.nombre, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: proyectos.isEmpty
                ? null
                : (v) => setState(() => _proyectoId = v),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 130,
          child: TextField(
            controller: _unidad,
            onChanged: _onUnidadChanged,
            decoration: InputDecoration(
              labelText: 'Unidad',
              hintText: 'Ej. 411',
              prefixIcon: const Icon(Icons.home_outlined, size: 20),
              isDense: true,
              suffixIcon: _unidad.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _debounce?.cancel();
                        _unidad.clear();
                        setState(() => _unidadQuery = '');
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final auth = ref.watch(authProvider);
    final imp = ref.watch(impersonationProvider);
    final clientes = ref.watch(adminClientesProvider);

    return Scaffold(
      backgroundColor: tone.surface,
      appBar: AppBar(
        title: const Text('Selecciona un cliente'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/admin-avisos'),
            icon: Icon(
              Icons.campaign_outlined,
              size: 18,
              color: tone.primaryDark,
            ),
            label: Text(
              'Enviar avisos',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tone.primaryDark,
              ),
            ),
          ),
          if (imp.active)
            TextButton(
              onPressed: () => context.go('/inicio'),
              child: Text(
                'Volver al portal',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tone.primaryDark,
                ),
              ),
            ),
          TextButton(
            onPressed: () async {
              await ref.read(authProvider).signOut();
            },
            child: Text(
              'Cerrar sesión',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tone.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: WebFrame(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acceso administrador · ${auth.profile?.nombre ?? auth.profile?.email ?? ''}',
                    style: TextStyle(fontSize: 13, color: tone.textMuted),
                  ),
                  const SizedBox(height: 12),
                  _filtrosPropiedad(tone),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o correo…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: clientes.when(
                loading: () => ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(height: 18),
                          SizedBox(height: 8),
                          Skeleton(width: 200, height: 14),
                        ],
                      ),
                    ),
                  ],
                ),
                error: (_, __) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ErrorCard(
                      title: 'No pudimos cargar la lista de clientes',
                      onRetry: () => ref.invalidate(adminClientesProvider),
                    ),
                  ],
                ),
                data: (data) {
                  // Sin filtro de propiedad: comportamiento original.
                  if (!_filtroPropiedadActivo) {
                    if (_queryTooShort) return _hintBuscar(tone);
                    final lista = _filtrar(data.clientes);
                    if (lista.isEmpty) return _sinResultados(tone);
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) =>
                          _clienteTile(lista[i], tone),
                    );
                  }

                  // Con filtro Proyecto + Unidad: copropietarios arriba y
                  // "Todos los clientes" debajo (paridad con el portal).
                  final lista = _filtrar(data.clientes);
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ..._seccionPropietarios(tone),
                      _headerGrupo(
                        'Todos los clientes',
                        tone,
                        icon: Icons.people_alt_outlined,
                      ),
                      if (_queryTooShort)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Escribe al menos $_minQueryLength letras del '
                            'nombre o correo para buscar en todos los '
                            'clientes.',
                            style: TextStyle(
                              fontSize: 14,
                              color: tone.textSecondary,
                            ),
                          ),
                        )
                      else if (lista.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Sin resultados para "$_query".',
                            style: TextStyle(
                              fontSize: 14,
                              color: tone.textSecondary,
                            ),
                          ),
                        )
                      else
                        for (final c in lista) ...[
                          _clienteTile(c, tone),
                          const SizedBox(height: 8),
                        ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hintBuscar(SozuTone tone) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tone.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_search_outlined,
                size: 30,
                color: tone.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Busca un cliente',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tone.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Escribe al menos $_minQueryLength letras del nombre o correo, '
              'o filtra por proyecto y unidad.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: tone.textSecondary),
            ),
          ],
        ),
      );

  Widget _sinResultados(SozuTone tone) => Center(
        child: Text(
          'Sin resultados para "$_query".',
          style: TextStyle(fontSize: 14, color: tone.textSecondary),
        ),
      );
}
