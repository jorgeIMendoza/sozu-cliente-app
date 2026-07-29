import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/providers/auth_provider.dart';
import 'package:sozu_cliente_app/providers/data_providers.dart';
import 'package:sozu_cliente_app/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
// Import directo mientras el export de la primitiva no está en ui/ui.dart.
import 'package:sozu_cliente_app/widgets/admin/admin_header_bar.dart';
import 'package:sozu_cliente_app/widgets/admin/client_tile.dart';
import 'package:sozu_cliente_app/widgets/admin/client_filters.dart';
import 'package:sozu_cliente_app/widgets/common.dart';
import 'package:sozu_cliente_app/widgets/theme_mode_button.dart';

/// Selector de cliente para super administradores (solo web).
/// El admin elige un cliente y navega el portal viendo sus datos.
///
/// Paridad con el "Ver como" del portal admin: al filtrar por Proyecto + Unidad
/// (número de propiedad) se muestra arriba el grupo "Copropietarios (N)" (o
/// "Dueño de la propiedad" si es uno) con los clientes dueños de esa unidad, y
/// debajo "Todos los clientes".
///
/// ## Estructura
///
/// Esta pantalla **solo compone y orquesta**: lee providers, mantiene el estado
/// de los filtros y decide qué mostrar. Todo lo visual vive en componentes:
///
/// * [AdminHeaderBar] / [AdminHeaderAction] - encabezado y acciones
/// * [ClientFilters] - Proyecto + Unidad
/// * [SSearchField] - buscador
/// * [ClientTile] - fila de cliente
/// * [SSectionLabel] - encabezado de grupo
/// * [SEmptyState] - vacíos e instrucciones
///
/// Antes eran ~480 líneas con seis `Widget _algo(SozuColorRoles tone)` privados
/// pasándose el tema a mano, `TextStyle(fontSize: …)` sueltos y el layout
/// mezclado con la lógica de filtrado.
class SeleccionarClienteScreen extends ConsumerStatefulWidget {
  const SeleccionarClienteScreen({super.key});

  @override
  ConsumerState<SeleccionarClienteScreen> createState() =>
      _SeleccionarClienteScreenState();
}

class _SeleccionarClienteScreenState
    extends ConsumerState<SeleccionarClienteScreen> {
  static const _minQueryLength = 2;

  /// Ancho máximo del content. 880 en vez de 720: con el encabezado y las
  /// acciones dentro del mismo contenedor, 720 apretaba la fila de acciones.
  static const _maxWidth = 880.0;

  final _search = TextEditingController();
  final _unidad = TextEditingController();
  Timer? _debounce;

  String _query = '';
  int? _proyectoId;
  String _unitQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _unidad.dispose();
    super.dispose();
  }

  bool get _queryTooShort => _query.trim().length < _minQueryLength;

  bool get _isPropertyFilterActive =>
      _proyectoId != null && _unitQuery.isNotEmpty;

  void _onUnidadChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _unitQuery = v.trim());
    });
  }

  void _clearUnit() {
    _debounce?.cancel();
    _unidad.clear();
    setState(() => _unitQuery = '');
  }

  List<AdminCliente> _filterBy(List<AdminCliente> clientes) {
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

  void _viewAs(AdminCliente c) {
    ref.read(impersonationProvider).select(c.idPersona, c.nombre, c.email);
    context.go('/inicio');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final auth = ref.watch(authProvider);
    final imp = ref.watch(impersonationProvider);
    final gutter = context.responsive(mobile: t.space.md, desktop: t.space.lg);

    return Scaffold(
      // `background`, no `surface`: el fondo de página es un nivel por DEBAJO de
      // las tarjetas. Usar surface aquí aplanaba todo en un solo tono.
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Padding(
              padding: EdgeInsets.all(gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminHeaderBar(
                    title: 'Selecciona un cliente',
                    subtitle:
                        'Acceso administrador · '
                        '${auth.profile?.nombre ?? auth.profile?.email ?? ''}',
                    actions: [
                      const ThemeModeButton(),
                      SizedBox(width: t.space.xxs),
                      AdminHeaderAction(
                        label: 'Enviar avisos',
                        icon: Icons.campaign_outlined,
                        onPressed: () => context.push('/admin-avisos'),
                      ),
                      if (imp.active)
                        AdminHeaderAction(
                          label: 'Volver al portal',
                          onPressed: () => context.go('/inicio'),
                        ),
                      AdminHeaderAction(
                        label: 'Cerrar sesión',
                        isPrimary: false,
                        onPressed: () => ref.read(authProvider).signOut(),
                      ),
                    ],
                  ),
                  SizedBox(height: t.space.md),
                  _FiltersPanel(
                    projects:
                        ref.watch(adminProyectosProvider).asData?.value ??
                        const <CatalogoItem>[],
                    projectId: _proyectoId,
                    onProjectChanged: (v) => setState(() => _proyectoId = v),
                    unitController: _unidad,
                    onUnitChanged: _onUnidadChanged,
                    onUnitCleared: _clearUnit,
                    searchController: _search,
                    onQueryChanged: (v) => setState(() => _query = v),
                  ),
                  SizedBox(height: t.space.md),
                  Expanded(child: _results()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Resultados
  // -------------------------------------------------------------------------

  Widget _results() {
    final clientes = ref.watch(adminClientesProvider);
    final t = context.s;

    return clientes.when(
      loading: () => ListView(
        padding: EdgeInsets.zero,
        children: [
          for (var i = 0; i < 4; i++) ...[
            const _ClientTileSkeleton(),
            SizedBox(height: t.space.xs),
          ],
        ],
      ),
      error: (_, __) => ErrorCard(
        title: 'No pudimos cargar la lista de clientes',
        onRetry: () => ref.invalidate(adminClientesProvider),
      ),
      data: (data) {
        final items = _filterBy(data.clientes);

        // Sin filtro de propiedad: solo búsqueda por texto.
        if (!_isPropertyFilterActive) {
          if (_queryTooShort) {
            return const SEmptyState(
              icon: Icons.person_search_outlined,
              title: 'Busca un cliente',
              message:
                  'Escribe al menos $_minQueryLength letras del nombre o '
                  'correo, o filtra por proyecto y unidad.',
            );
          }
          if (items.isEmpty) {
            return SEmptyState(
              icon: Icons.search_off_outlined,
              title: 'Sin resultados',
              message: 'No encontramos clientes para "$_query".',
            );
          }
          return _ClientList(clientes: items, onTap: _viewAs);
        }

        // Con filtro Proyecto + Unidad: copropietarios arriba y "Todos los
        // clientes" debajo (paridad con el portal admin).
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            ..._ownersSection(),
            const SSectionLabel(
              text: 'Todos los clientes',
              icon: Icons.people_alt_outlined,
            ),
            if (_queryTooShort)
              _InlineNote(
                'Escribe al menos $_minQueryLength letras del nombre o correo '
                'para buscar en todos los clientes.',
              )
            else if (items.isEmpty)
              _InlineNote('Sin resultados para "$_query".')
            else
              for (final cliente in items) ...[
                ClientTile(
                  cliente: cliente,
                  isSelected:
                      ref.watch(impersonationProvider).idPersona ==
                      cliente.idPersona,
                  onTap: () => _viewAs(cliente),
                ),
                SizedBox(height: t.space.xs),
              ],
          ],
        );
      },
    );
  }

  /// Sección "Copropietarios (N)" / "Dueño de la propiedad", solo cuando el
  /// filtro Proyecto + Unidad está activo.
  List<Widget> _ownersSection() {
    final t = context.s;
    final propietarios = ref.watch(
      adminPropietariosProvider((idProyecto: _proyectoId!, numero: _unitQuery)),
    );

    return propietarios.when(
      loading: () => [
        const SSectionLabel(text: 'Copropietarios', icon: Icons.group_outlined),
        const _ClientTileSkeleton(),
        SizedBox(height: t.space.md),
      ],
      error: (_, __) => [
        ErrorCard(
          title: 'No pudimos cargar los clientes de la unidad',
          onRetry: () => ref.invalidate(adminPropietariosProvider),
        ),
        SizedBox(height: t.space.md),
      ],
      data: (items) {
        if (items.isEmpty) {
          return [
            const SSectionLabel(
              text: 'Copropietarios',
              icon: Icons.group_outlined,
            ),
            const _InlineNote(
              'No encontramos clientes vinculados a esa unidad.',
            ),
            SizedBox(height: t.space.md),
          ];
        }
        return [
          SSectionLabel(
            text: items.length > 1
                ? 'Copropietarios (${items.length})'
                : 'Dueño de la propiedad',
            icon: Icons.group_outlined,
          ),
          for (final cliente in items) ...[
            ClientTile(
              cliente: cliente,
              isSelected:
                  ref.watch(impersonationProvider).idPersona ==
                  cliente.idPersona,
              onTap: () => _viewAs(cliente),
            ),
            SizedBox(height: t.space.xs),
          ],
          SizedBox(height: t.space.xs),
        ];
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Partes locales
// ---------------------------------------------------------------------------

/// Tarjeta que agrupa filtros + buscador.
///
/// Es una superficie propia sobre el fondo de página: agrupar los tres controles
/// en una card los lee como un solo bloque de "acotar la búsqueda", en vez de
/// tres campos sueltos flotando.
class _FiltersPanel extends StatelessWidget {
  final List<CatalogoItem> projects;
  final int? projectId;
  final ValueChanged<int?> onProjectChanged;
  final TextEditingController unitController;
  final ValueChanged<String> onUnitChanged;
  final VoidCallback onUnitCleared;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;

  const _FiltersPanel({
    required this.projects,
    required this.projectId,
    required this.onProjectChanged,
    required this.unitController,
    required this.onUnitChanged,
    required this.onUnitCleared,
    required this.searchController,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      padding: EdgeInsets.all(t.space.sm),
      decoration: BoxDecoration(
        color: t.color.surface,
        borderRadius: t.radius.lgBorder,
        border: Border.all(color: t.color.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClientFilters(
            projects: projects,
            projectId: projectId,
            onProjectChanged: onProjectChanged,
            unitController: unitController,
            onUnitChanged: onUnitChanged,
            onUnitCleared: onUnitCleared,
          ),
          SizedBox(height: t.space.xs),
          SSearchField(
            controller: searchController,
            hintText: 'Buscar por nombre o correo…',
            autofocus: true,
            onChanged: onQueryChanged,
          ),
        ],
      ),
    );
  }
}

class _ClientList extends StatelessWidget {
  final List<AdminCliente> clientes;
  final void Function(AdminCliente) onTap;

  const _ClientList({required this.clientes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: clientes.length,
      separatorBuilder: (_, __) => SizedBox(height: t.space.xs),
      // Entrada escalonada: cada fila entra un poco después de la anterior, así
      // la lista se lee como algo que llega y no como un parpadeo del skeleton
      // al contenido. El retardo lo satura `delayForIndex`, que es lo que evita
      // que una búsqueda con 50 resultados tarde 2 s en terminar de aparecer.
      itemBuilder: (context, i) => SFadeInUp(
        delay: SStaggered.delayForIndex(i),
        child: Consumer(
          builder: (context, ref, _) => ClientTile(
            cliente: clientes[i],
            isSelected:
                ref.watch(impersonationProvider).idPersona ==
                clientes[i].idPersona,
            onTap: () => onTap(clientes[i]),
          ),
        ),
      ),
    );
  }
}

/// Nota de una línea dentro de la lista (no amerita un estado vacío completo).
class _InlineNote extends StatelessWidget {
  final String texto;

  const _InlineNote(this.texto);

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space.xs),
      child: Text(
        texto,
        style: t.text.bodySmall.copyWith(color: t.color.fgMuted),
      ),
    );
  }
}

class _ClientTileSkeleton extends StatelessWidget {
  const _ClientTileSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      padding: EdgeInsets.all(t.space.sm),
      decoration: BoxDecoration(
        color: t.color.surface,
        borderRadius: t.radius.mdBorder,
        border: Border.all(color: t.color.border),
      ),
      child: Row(
        children: [
          const Skeleton(width: 36, height: 36),
          SizedBox(width: t.space.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 14),
                SizedBox(height: 6),
                Skeleton(width: 180, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
