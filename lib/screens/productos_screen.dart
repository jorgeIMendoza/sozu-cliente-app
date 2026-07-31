import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/providers/data_providers.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';
import 'package:sozu_cliente_app/screens/producto_detalle_screen.dart'
    show ProductoPortalHistorial;
import 'package:sozu_cliente_app/ui/ui.dart';

/// Productos adicionales del cliente agrupados por propiedad (paridad con
/// ClienteProductos del portal admin): buscador en vivo, tarjetas con avance
/// de pago y acceso al historial de cada producto (/productos/:cuentaId).
class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';

  /// Propiedad seleccionada en modo portal (detalle in-page). null = lista.
  String? _grupoSel;

  /// Producto (cuentaId) seleccionado en las tabs del detalle in-page. null =
  /// se usa el primero de la propiedad.
  int? _prodSel;

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  /// Clave estable de un grupo/propiedad (para la selección in-page).
  String _grupoKey(ProductosPropiedad g) =>
      g.cuentaPropiedadId?.toString() ?? '${g.proyecto}|${g.propiedad}';

  /// Grupos filtrados: si la búsqueda coincide con proyecto/propiedad se
  /// conserva el grupo completo; si no, solo los productos cuyo nombre
  /// coincide.
  List<(ProductosPropiedad, List<ProductoCliente>)> _filtrar(
    List<ProductosPropiedad> grupos,
  ) {
    final q = _busqueda.trim().toLowerCase();
    final out = <(ProductosPropiedad, List<ProductoCliente>)>[];
    for (final g in grupos) {
      if (q.isEmpty ||
          '${g.proyecto} ${g.propiedad}'.toLowerCase().contains(q)) {
        out.add((g, g.productos));
        continue;
      }
      final prods = g.productos
          .where((p) => p.nombre.toLowerCase().contains(q))
          .toList();
      if (prods.isNotEmpty) out.add((g, prods));
    }
    return out;
  }

  String _tituloGrupo(ProductosPropiedad g) {
    final unidad = g.propiedad.startsWith('U-')
        ? g.propiedad
        : 'U-${g.propiedad}';
    return '${g.proyecto} · $unidad';
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final portal = isPortalMode(context);
    final productos = ref.watch(clienteProductosProvider);

    return Scaffold(
      // Modo portal: el shell ya pinta el título; sin AppBar propio.
      backgroundColor: portal ? Colors.transparent : null,
      appBar: portal
          ? null
          : AppBar(
              title: const Text('Productos'),
              // Flecha siempre presente: si no hay stack (deep link / arranque
              // en frío) regresa a Inicio en lugar de desaparecer.
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/inicio'),
              ),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clienteProductosProvider);
          try {
            await ref.read(clienteProductosProvider.future);
          } catch (_) {}
        },
        child: productos.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              SSkeleton(width: 220, height: 14),
              SizedBox(height: 16),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SSkeleton(width: 180, height: 16),
                    SizedBox(height: 12),
                    SSkeleton(height: 10),
                    SizedBox(height: 12),
                    SSkeleton(width: 140, height: 12),
                  ],
                ),
              ),
              SizedBox(height: 16),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SSkeleton(width: 180, height: 16),
                    SizedBox(height: 12),
                    SSkeleton(height: 10),
                    SizedBox(height: 12),
                    SSkeleton(width: 140, height: 12),
                  ],
                ),
              ),
            ],
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SErrorState(
                title: 'No pudimos cargar tus productos',
                onRetry: () => ref.invalidate(clienteProductosProvider),
              ),
            ],
          ),
          data: (data) {
            final grupos = data.propiedades
                .where((g) => g.productos.isNotEmpty)
                .toList();
            final n = grupos.fold<int>(0, (s, g) => s + g.productos.length);
            final filtrados = _filtrar(grupos);
            if (portal) return _portalVista(n, filtrados, grupos);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  n > 0
                      ? 'Productos adicionales · $n ${n == 1 ? 'producto' : 'productos'}'
                      : 'Productos adicionales',
                  style: TextStyle(fontSize: 14, color: tone.fgMuted),
                ),
                const SizedBox(height: 16),
                if (n == 0)
                  const SEmptyState.card(
                    icon: Icons.inventory_2_outlined,
                    title: 'Aún no tienes productos adicionales',
                  )
                else ...[
                  TextField(
                    onChanged: (v) => setState(() => _busqueda = v),
                    textInputAction: TextInputAction.search,
                    style: TextStyle(fontSize: 14, color: tone.fg),
                    decoration: InputDecoration(
                      hintText: 'Buscar producto o propiedad…',
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: tone.fgSubtle,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  if (filtrados.isEmpty) ...[
                    const SizedBox(height: 16),
                    const SEmptyState.card(
                      icon: Icons.search_off_outlined,
                      title: 'Sin resultados',
                    ),
                  ] else
                    for (final (g, prods) in filtrados) ...[
                      SSectionLabel.heading(
                        icon: Icons.apartment_outlined,
                        text: _tituloGrupo(g),
                      ),
                      ResponsiveCardGrid(
                        children: [for (final p in prods) _ProductoCard(p: p)],
                      ),
                    ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODO PORTAL (web ≥1024): réplica de "Productos adicionales" del Portal del
  // Cliente (ClienteProductos.tsx) con grid de productos por propiedad. Solo
  // capa visual: mismo provider, buscador y navegación al historial.
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _portalVista(
    int n,
    List<(ProductosPropiedad, List<ProductoCliente>)> filtrados,
    List<ProductosPropiedad> grupos,
  ) {
    // Detalle in-page de una propiedad seleccionada (agregado por propiedad,
    // como ClienteProductos del portal).
    if (_grupoSel != null) {
      ProductosPropiedad? sel;
      for (final g in grupos) {
        if (_grupoKey(g) == _grupoSel) {
          sel = g;
          break;
        }
      }
      if (sel != null) return _portalDetalle(sel);
      // La selección ya no existe (datos recargados): vuelve a la lista.
      _grupoSel = null;
      _prodSel = null;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Productos adicionales',
            style: portalText(
              size: 26,
              weight: FontWeight.w700,
              letterSpacing: -0.65,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            n == 0
                ? 'No tienes productos adicionales.'
                : 'Selecciona una propiedad.',
            style: portalText(size: 13, color: PortalColors.mutedForeground),
          ),
          const SizedBox(height: 16),
          if (n == 0)
            SCard(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: PortalColors.muted,
                        borderRadius: BorderRadius.circular(kPortalRadiusLg),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 20,
                        color: PortalColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sin productos adicionales registrados.',
                      style: portalText(
                        size: 13,
                        color: PortalColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SSearchField(
              controller: _busquedaCtrl,
              hintText: 'Buscar producto o propiedad…',
              onChanged: (v) => setState(() => _busqueda = v),
            ),
            if (filtrados.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Sin resultados',
                    style: portalText(
                      size: 14,
                      color: PortalColors.mutedForeground,
                    ),
                  ),
                ),
              )
            else
              // Una fila por propiedad con el agregado de sus productos.
              for (final (g, _) in filtrados) ...[
                const SizedBox(height: 12),
                _portalPropiedadRow(g),
              ],
          ],
        ],
      ),
    );
  }

  /// Fila-resumen por propiedad (espejo de ClienteProductos): círculo con el
  /// número de productos, título y agregado "{pct}% pagado · $total".
  Widget _portalPropiedadRow(ProductosPropiedad g) {
    final total = g.productos.length;
    final totalPagado = g.productos.fold<double>(
      0,
      (s, p) => s + p.totalPagado,
    );
    final totalPrecio = g.productos.fold<double>(
      0,
      (s, p) => s + p.precioFinal,
    );
    final pct = totalPrecio > 0 ? (totalPagado / totalPrecio * 100).round() : 0;

    return SHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: () => setState(() {
          _grupoSel = _grupoKey(g);
          _prodSel = g.productos.isNotEmpty ? g.productos.first.cuentaId : null;
        }),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PortalColors.surface,
            borderRadius: BorderRadius.circular(kPortalRadiusCard),
            border: Border.all(
              color: hovered
                  ? PortalColors.primaryBorder30
                  : PortalColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PortalColors.primarySoft10,
                  borderRadius: BorderRadius.circular(kPortalRadiusMd),
                ),
                child: Text(
                  '$total',
                  style: portalText(
                    size: 14,
                    weight: FontWeight.w700,
                    color: PortalColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tituloGrupo(g),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: portalText(size: 14, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '$total ${total == 1 ? 'producto' : 'productos'}',
                          style: portalText(
                            size: 11,
                            color: PortalColors.mutedForeground,
                          ),
                        ),
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: const BoxDecoration(
                            color: PortalColors.border,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '$pct% pagado · ${formatMXN(totalPagado)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: portalText(
                              size: 11,
                              color: PortalColors.mutedForeground,
                              tabular: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: PortalColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Detalle in-page de una propiedad (réplica de PropiedadDetail del portal):
  /// cabecera con botón volver + tabs por producto (o cabecera simple si solo
  /// hay uno) + historial del producto seleccionado (filtros, movimientos y
  /// resumen), como ClienteProductos.tsx.
  Widget _portalDetalle(ProductosPropiedad g) {
    final total = g.productos.length;
    final sel = g.productos.firstWhere(
      (p) => p.cuentaId == _prodSel,
      orElse: () => g.productos.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SHoverBuilder(
                builder: (context, hovered) => GestureDetector(
                  onTap: () => setState(() {
                    _grupoSel = null;
                    _prodSel = null;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hovered
                          ? PortalColors.mutedHover
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      size: 18,
                      color: PortalColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Productos adicionales',
                  style: portalText(
                    size: 26,
                    weight: FontWeight.w700,
                    letterSpacing: -0.65,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              '${_tituloGrupo(g)} · $total ${total == 1 ? 'producto' : 'productos'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: portalText(size: 13, color: PortalColors.mutedForeground),
            ),
          ),
          const SizedBox(height: 16),
          if (total > 1)
            _portalTabs(g.productos, sel.cuentaId)
          else
            _portalProductoSingleHeader(sel),
          const SizedBox(height: 16),
          ProductoPortalHistorial(producto: sel, grupo: g),
        ],
      ),
    );
  }

  /// Selector horizontal de productos de la propiedad (ProductoTabs del
  /// portal): pill con icono + nombre; las inactivas muestran su chip de
  /// estatus.
  Widget _portalTabs(List<ProductoCliente> prods, int selectedId) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in prods) ...[
            _portalTab(p, active: p.cuentaId == selectedId),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _portalTab(ProductoCliente p, {required bool active}) {
    return SHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: () => setState(() => _prodSel = p.cuentaId),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? PortalColors.primary : PortalColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? PortalColors.primary
                  : hovered
                  ? PortalColors.primaryBorder30
                  : PortalColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: active ? Colors.white : PortalColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  p.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: portalText(
                    size: 12,
                    weight: FontWeight.w500,
                    color: active ? Colors.white : PortalColors.mutedForeground,
                  ),
                ),
              ),
              if (!active) ...[
                const SizedBox(width: 6),
                portalProductoStatusChip(p.estatus, small: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Cabecera de producto único (rama length == 1 de PropiedadDetail): icono,
  /// nombre + descripción y chip de estatus.
  Widget _portalProductoSingleHeader(ProductoCliente p) {
    final descripcion = (p.descripcion ?? '').trim();
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PortalColors.primarySoft10,
            borderRadius: BorderRadius.circular(kPortalRadiusLg),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: PortalColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: portalText(size: 13, weight: FontWeight.w600),
              ),
              if (descripcion.isNotEmpty)
                Text(
                  descripcion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: portalText(
                    size: 11,
                    color: PortalColors.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        portalProductoStatusChip(p.estatus, small: true),
      ],
    );
  }
}

/// Tarjeta de producto adicional: estatus, montos, avance y próximo pago.
class _ProductoCard extends StatelessWidget {
  final ProductoCliente p;

  const _ProductoCard({required this.p});

  SBadgeTone get _badgeTone {
    final s = p.estatus.toLowerCase();
    if (s.contains('pagado')) return SBadgeTone.positive;
    if (s.contains('curso')) return SBadgeTone.neutral;
    return SBadgeTone.pending;
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final descripcion = p.descripcion?.trim();
    return PressableScale(
      onTap: () => context.push('/productos/${p.cuentaId}'),
      child: SCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tone.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: SozuBrand.green600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tone.fg,
                        ),
                      ),
                      if (descripcion != null && descripcion.isNotEmpty)
                        Text(
                          descripcion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: tone.fgMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SBadge(label: p.estatus, tone: _badgeTone),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatMXN(p.totalPagado)} de ${formatMXN(p.precioFinal)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: tone.fgMuted),
                  ),
                ),
                if (p.saldoPendiente > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Faltan ${formatMXN(p.saldoPendiente)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tone.warningFg,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SProgressBar(
                    thickness: SProgressBarThickness.thick,
                    percent: p.avancePct,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${p.avancePct.round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tone.fgMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: p.proximaFecha == null
                      ? const SizedBox.shrink()
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: tone.warningSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.event_outlined,
                                  size: 12,
                                  color: SozuAmber.strong,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Próx. pago ${formatDate(p.proximaFecha)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: SozuAmber.strong,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ver historial',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SozuBrand.green600,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: SozuBrand.green600,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
