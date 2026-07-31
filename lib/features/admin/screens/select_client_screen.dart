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
import 'package:sozu_cliente_app/features/admin/components/admin_header_bar.dart';
import 'package:sozu_cliente_app/features/admin/layouts/admin_layout.dart';
import 'package:sozu_cliente_app/features/admin/components/client_row.dart';
import 'package:sozu_cliente_app/features/admin/components/client_filters.dart';
import 'package:sozu_cliente_app/widgets/theme_mode_button.dart';

/// Selector de cliente para super administradores (solo web).
/// El admin elige un cliente y navega el portal viendo sus datos.
///
/// Al filtrar por Proyecto + Unidad (número de propiedad) se muestran SOLO los
/// dueños de esa unidad: "Copropietarios (N)", o "Dueño de la propiedad" si es
/// uno. Sin filtro, se busca por nombre o correo.
///
/// ## Estructura
///
/// Esta pantalla **solo compone y orquesta**: lee providers, mantiene el estado
/// de los filtros y decide qué mostrar. Todo lo visual vive en componentes:
///
/// * [AdminHeaderBar] / [AdminHeaderAction] - encabezado y acciones
/// * [ClientFilters] - Proyecto + Unidad
/// * [SSearchField] - buscador
/// * [ClientRow] - fila de cliente
/// * [SSectionLabel] - encabezado de grupo
/// * [SEmptyState] - vacíos e instrucciones
///
/// Antes eran ~480 líneas con seis `Widget _algo(SozuColorRoles tone)` privados
/// pasándose el tema a mano, estilos de texto cocidos a mano y el layout
/// mezclado con la lógica de filtrado.
class SelectClientScreen extends ConsumerStatefulWidget {
  const SelectClientScreen({super.key});

  @override
  ConsumerState<SelectClientScreen> createState() => _SelectClientScreenState();
}

class _SelectClientScreenState extends ConsumerState<SelectClientScreen> {
  static const _minQueryLength = 2;

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
    final auth = ref.watch(authProvider);
    final imp = ref.watch(impersonationProvider);

    return AdminLayout(
      // 880 y no el default: con el encabezado y las acciones dentro del mismo
      // contenedor, menos ancho aprieta la fila de acciones.
      maxWidth: 880,
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
                isDanger: true,
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
    final clientes = ref.watch(adminClientesProvider);
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

    return clientes.when(
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
        onRetry: () => ref.invalidate(adminClientesProvider),
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
            message: 'No encontramos clientes para "$_query".',
          );
        }
        return _ClientList(clientes: items, onTap: _viewAs);
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
        const _ClientRowSkeleton(),
        SizedBox(height: t.space.md),
      ],
      error: (_, __) => [
        SErrorState(
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
            ClientRow(
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
    // `shrinkWrap` + sin physics: el scroll es el de la pagina (AdminLayout).
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clientes.length,
      separatorBuilder: (_, __) => SizedBox(height: t.space.xs),
      // Entrada escalonada: cada fila entra un poco después de la anterior, así
      // la lista se lee como algo que llega y no como un parpadeo del skeleton
      // al contenido. El retardo lo satura `delayForIndex`, que es lo que evita
      // que una búsqueda con 50 resultados tarde 2 s en terminar de aparecer.
      itemBuilder: (context, i) => SFadeInUp(
        delay: SStaggered.delayForIndex(i),
        child: Consumer(
          builder: (context, ref, _) => ClientRow(
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
