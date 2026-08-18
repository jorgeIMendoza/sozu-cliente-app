import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_cliente_app/features/admin/providers/client_filters_provider.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
// Import directo mientras el export de la primitiva no está en ui/ui.dart.
import 'package:sozu_cliente_app/features/admin/components/admin_header_bar.dart';
import 'package:sozu_cliente_app/features/admin/layouts/admin_layout.dart';
import 'package:sozu_cliente_app/shared/components/theme_mode_button.dart';
import 'package:sozu_cliente_app/features/admin/components/client_row.dart';
import 'package:sozu_cliente_app/features/admin/components/client_filters.dart';

/// Selector de cliente para administradores: elige uno y navega el portal
/// viendo sus datos. Sirve en web y en móvil.
///
/// Con Proyecto + Unidad se listan solo los dueños de esa unidad; sin filtro se
/// busca por nombre o correo. Los filtros viven en `clientFiltersProvider`.
class SelectClientScreen extends ConsumerStatefulWidget {
  const SelectClientScreen({super.key});

  @override
  ConsumerState<SelectClientScreen> createState() => _SelectClientScreenState();
}

class _SelectClientScreenState extends ConsumerState<SelectClientScreen> {
  static const _minQueryLength = 2;

  final _search = TextEditingController();
  final _unit = TextEditingController();
  Timer? _debounce;

  /// Los filtros viven en `clientFiltersProvider`, no aquí: así sobreviven a
  /// salir del selector y volver. Los `TextEditingController` SÍ son locales
  /// (son del widget de texto), y se siembran con lo que el store recuerda.
  ClientFiltersController get _filters => ref.read(clientFiltersProvider);

  @override
  void initState() {
    super.initState();
    final f = _filters;
    _search.text = f.query;
    _unit.text = f.unit;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _unit.dispose();
    super.dispose();
  }

  bool get _queryTooShort =>
      ref.watch(clientFiltersProvider).query.trim().length < _minQueryLength;

  bool get _isPropertyFilterActive {
    final f = ref.watch(clientFiltersProvider);
    return f.projectId != null && f.unit.isNotEmpty;
  }

  void _onUnitChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _filters.setUnit(v.trim());
    });
  }

  void _clearUnit() {
    _debounce?.cancel();
    _unit.clear();
    _filters.setUnit('');
  }

  /// Botón global: deja los tres filtros en blanco de un toque. Antes había que
  /// vaciar el buscador, quitar el proyecto y borrar la unidad por separado.
  void _clearAll() {
    _debounce?.cancel();
    _search.clear();
    _unit.clear();
    _filters.clear();
  }

  List<AdminCliente> _filterBy(List<AdminCliente> clients) {
    final q = ref.read(clientFiltersProvider).query.trim().toLowerCase();
    if (q.length < _minQueryLength) return const [];
    return clients
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
    final auth = ref.watch(authProvider);
    final filtros = ref.watch(clientFiltersProvider);

    return AdminLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminHeaderBar(
            title: 'Selecciona un cliente',
            subtitle:
                'Acceso administrador · '
                '${auth.profile?.displayName ?? auth.profile?.email ?? ''}',
            actions: [
              const ThemeModeButton(),
              SizedBox(width: t.space.xxs),
              AdminHeaderAction(
                label: 'Enviar avisos',
                icon: Icons.campaign_outlined,
                onPressed: () => context.push('/admin-avisos'),
              ),
              AdminHeaderAction(
                label: 'Cerrar sesión',
                isDanger: true,
                onPressed: () {
                  // Los filtros son contexto de trabajo de ESTA sesión: si no
                  // se limpian, el siguiente admin que entre en la misma
                  // máquina hereda el proyecto y la unidad del anterior.
                  _clearAll();
                  ref.read(authProvider).signOut();
                },
              ),
            ],
          ),
          SizedBox(height: t.space.md),
          _FiltersPanel(
            projects:
                ref.watch(adminProjectsProvider).asData?.value ??
                const <CatalogoItem>[],
            projectId: filtros.projectId,
            onProjectChanged: filtros.setProjectId,
            unitController: _unit,
            onUnitChanged: _onUnitChanged,
            onUnitCleared: _clearUnit,
            searchController: _search,
            onQueryChanged: filtros.setQuery,
            // Solo cuando hay algo puesto: un "Limpiar" permanente sobre un
            // formulario vacio es ruido, y ensena a ignorarlo.
            onClearAll: filtros.isDirty ? _clearAll : null,
          ),
          SizedBox(height: t.space.md),
          _results(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Resultados
  // -------------------------------------------------------------------------

  /// El contenido NO trae scroll propio: el de la página lo da [AdminLayout].
  /// Por eso las listas van como `Column` y no como `ListView`.
  Widget _results() {
    final clients = ref.watch(adminClientsProvider);
    final t = context.s;

    // Con el filtro Proyecto + Unidad activo solo se muestran los dueños de esa
    // unidad. Antes debajo iba un segundo bloque "Todos los clientes", que en la
    // practica repetia el buscador de arriba: si ya acotaste a una unidad, la
    // lista completa no aporta y solo alarga la pantalla.
    if (_isPropertyFilterActive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _ownersSection(),
      );
    }

    return clients.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 4; i++) ...[
            const _ClientRowSkeleton(),
            SizedBox(height: t.space.xs),
          ],
        ],
      ),
      error: (_, __) => SErrorState(
        title: 'No pudimos cargar la lista de clientes',
        onRetry: () => ref.invalidate(adminClientsProvider),
      ),
      data: (data) {
        final items = _filterBy(data.clientes);
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
            message:
                'No encontramos clientes para '
                '"${ref.read(clientFiltersProvider).query}".',
          );
        }
        return _ClientList(clients: items, onTap: _viewAs);
      },
    );
  }

  /// Sección "Copropietarios (N)" / "Dueño de la propiedad", solo cuando el
  /// filtro Proyecto + Unidad está activo.
  List<Widget> _ownersSection() {
    final t = context.s;
    final f = ref.watch(clientFiltersProvider);
    final owners = ref.watch(
      adminOwnersProvider((projectId: f.projectId!, propertyNumber: f.unit)),
    );

    return owners.when(
      loading: () => [
        const SSectionLabel(text: 'Copropietarios', icon: Icons.group_outlined),
        const _ClientRowSkeleton(),
        SizedBox(height: t.space.md),
      ],
      error: (_, __) => [
        SErrorState(
          title: 'No pudimos cargar los clientes de la unidad',
          onRetry: () => ref.invalidate(adminOwnersProvider),
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
          for (final client in items) ...[
            ClientRow(
              client: client,
              isSelected:
                  ref.watch(impersonationProvider).clientId == client.idPersona,
              onTap: () => _viewAs(client),
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

  /// null = no hay nada que limpiar, y el boton no se pinta.
  final VoidCallback? onClearAll;

  const _FiltersPanel({
    required this.projects,
    required this.projectId,
    required this.onProjectChanged,
    required this.unitController,
    required this.onUnitChanged,
    required this.onUnitCleared,
    required this.searchController,
    required this.onQueryChanged,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    // `SCard` y no un Container a mano: repetia su decoracion (surface, radio lg,
    // borde) y con `space.sm` el contenido quedaba pegado al borde. El padding
    // por defecto de la primitiva es `space.md`.
    return SCard(
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
            label: 'Cliente',
            hintText: 'Alex Hernández o alex@example.com',
            // Solo donde hay teclado físico: en teléfono, abrirlo al entrar tapa
            // media pantalla antes de que el usuario pida escribir.
            autofocus: context.bp.isDesktop,
            onChanged: onQueryChanged,
          ),
          if (onClearAll != null) ...[
            SizedBox(height: t.space.xs),
            Align(
              alignment: Alignment.centerRight,
              child: SButton.link(
                label: 'Limpiar filtros',
                icon: Icons.filter_alt_off_outlined,
                onPressed: onClearAll,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClientList extends StatelessWidget {
  final List<AdminCliente> clients;
  final void Function(AdminCliente) onTap;

  const _ClientList({required this.clients, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    // `shrinkWrap` + sin physics: el scroll es el de la pagina (AdminLayout).
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clients.length,
      separatorBuilder: (_, __) => SizedBox(height: t.space.xs),
      // Entrada escalonada: cada fila entra un poco después de la anterior, así
      // la lista se lee como algo que llega y no como un parpadeo del skeleton
      // al contenido. El retardo lo satura `delayForIndex`, que es lo que evita
      // que una búsqueda con 50 resultados tarde 2 s en terminar de aparecer.
      itemBuilder: (context, i) => SFadeInUp(
        delay: SStaggered.delayForIndex(i),
        child: Consumer(
          builder: (context, ref, _) => ClientRow(
            client: clients[i],
            isSelected:
                ref.watch(impersonationProvider).clientId ==
                clients[i].idPersona,
            onTap: () => onTap(clients[i]),
          ),
        ),
      ),
    );
  }
}

/// Nota de una línea dentro de la lista (no amerita un estado vacío completo).
class _InlineNote extends StatelessWidget {
  final String text;

  const _InlineNote(this.text);

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space.xs),
      child: Text(
        text,
        style: t.text.bodySmall.copyWith(color: t.color.fgMuted),
      ),
    );
  }
}

/// Ancho del renglón del correo en el skeleton. El correo es más corto que el
/// nombre: dos renglones del mismo ancho se leen como un solo bloque gris.
const double _emailSkeletonWidth = 180;

/// Réplica en gris de [ClientRow]. Las medidas salen de los mismos tokens que
/// la fila real ([kClientRowAvatarSize], `text.label`, `text.caption`) para que
/// la lista no brinque al llegar los datos.
class _ClientRowSkeleton extends StatelessWidget {
  const _ClientRowSkeleton();

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
          const SSkeleton(
            width: kClientRowAvatarSize,
            height: kClientRowAvatarSize,
          ),
          SizedBox(width: t.space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SSkeleton(height: t.text.label.fontSize!),
                SizedBox(height: t.space.xxs),
                SSkeleton(
                  width: _emailSkeletonWidth,
                  height: t.text.caption.fontSize!,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
