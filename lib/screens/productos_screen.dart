import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';
import '../widgets/portal_widgets.dart';

/// Productos adicionales del cliente agrupados por propiedad (paridad con
/// ClienteProductos del portal admin): buscador en vivo, tarjetas con avance
/// de pago y acceso al historial de cada producto (/productos/:cuentaId).
class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  String _busqueda = '';

  /// Propiedad seleccionada en modo portal (detalle in-page). null = lista.
  String? _grupoSel;

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
    final unidad =
        g.propiedad.startsWith('U-') ? g.propiedad : 'U-${g.propiedad}';
    return '${g.proyecto} · $unidad';
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final portal = isPortalMode(context);
    final productos = ref.watch(clienteProductosProvider);

    return Scaffold(
      // Modo portal: el shell ya pinta el título; sin AppBar propio.
      backgroundColor: portal ? Colors.transparent : null,
      appBar: portal ? null : AppBar(title: const Text('Productos')),
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
              Skeleton(width: 220, height: 14),
              SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 180, height: 16),
                    SizedBox(height: 12),
                    Skeleton(height: 10),
                    SizedBox(height: 12),
                    Skeleton(width: 140, height: 12),
                  ],
                ),
              ),
              SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 180, height: 16),
                    SizedBox(height: 12),
                    Skeleton(height: 10),
                    SizedBox(height: 12),
                    Skeleton(width: 140, height: 12),
                  ],
                ),
              ),
            ],
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorCard(
                title: 'No pudimos cargar tus productos',
                onRetry: () => ref.invalidate(clienteProductosProvider),
              ),
            ],
          ),
          data: (data) {
            final grupos = data.propiedades
                .where((g) => g.productos.isNotEmpty)
                .toList();
            final n =
                grupos.fold<int>(0, (s, g) => s + g.productos.length);
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
                  style: TextStyle(fontSize: 14, color: tone.textSecondary),
                ),
                const SizedBox(height: 16),
                if (n == 0)
                  const EmptyCard(
                    icon: Icons.inventory_2_outlined,
                    text: 'Aún no tienes productos adicionales',
                  )
                else ...[
                  TextField(
                    onChanged: (v) => setState(() => _busqueda = v),
                    textInputAction: TextInputAction.search,
                    style: TextStyle(fontSize: 14, color: tone.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Buscar producto o propiedad…',
                      prefixIcon:
                          Icon(Icons.search, size: 20, color: tone.textMuted),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  if (filtrados.isEmpty) ...[
                    const SizedBox(height: 16),
                    const EmptyCard(
                      icon: Icons.search_off_outlined,
                      text: 'Sin resultados',
                    ),
                  ] else
                    for (final (g, prods) in filtrados) ...[
                      SectionTitle(
                        icon: Icons.apartment_outlined,
                        text: _tituloGrupo(g),
                      ),
                      ResponsiveCardGrid(
                        children: [
                          for (final p in prods) _ProductoCard(p: p),
                        ],
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
            PortalCard(
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
            PortalSearchField(
              hint: 'Buscar producto o propiedad…',
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
    final totalPagado =
        g.productos.fold<double>(0, (s, p) => s + p.totalPagado);
    final totalPrecio =
        g.productos.fold<double>(0, (s, p) => s + p.precioFinal);
    final pct =
        totalPrecio > 0 ? (totalPagado / totalPrecio * 100).round() : 0;

    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: () => setState(() => _grupoSel = _grupoKey(g)),
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

  /// Detalle in-page de una propiedad: cabecera con botón volver + grid de
  /// tarjetas de producto (cada una abre el historial con la navegación
  /// existente /productos/:cuentaId).
  Widget _portalDetalle(ProductosPropiedad g) {
    final total = g.productos.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PortalHoverBuilder(
                builder: (context, hovered) => GestureDetector(
                  onTap: () => setState(() => _grupoSel = null),
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
          _portalGrid(g.productos),
        ],
      ),
    );
  }

  /// Grid responsive de productos (3 col ancho, 2 medio, 1 angosto).
  Widget _portalGrid(List<ProductoCliente> prods) {
    return LayoutBuilder(
      builder: (context, cons) {
        final cols = cons.maxWidth >= 1000
            ? 3
            : cons.maxWidth >= 640
            ? 2
            : 1;
        const gap = 16.0;
        final itemW = (cons.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final p in prods)
              SizedBox(width: itemW, child: _portalProductoCard(p)),
          ],
        );
      },
    );
  }

  /// Chip de estatus del producto (STATUS_CFG del portal): Pendiente ámbar,
  /// En curso / Pagado en verde.
  PortalStatusChip _portalChipEstatus(ProductoCliente p, {bool small = true}) {
    final e = p.estatus.toLowerCase();
    final (bg, fg) = e.contains('pagado')
        ? (PortalColors.primarySoft15, PortalColors.primary)
        : e.contains('curso')
        ? (PortalColors.primarySoft10, PortalColors.primary)
        : (PortalColors.warningSoft15, PortalColors.warning);
    return PortalStatusChip(
      small: small,
      label: p.estatus,
      background: bg,
      foreground: fg,
    );
  }

  /// Tarjeta de producto estilo portal: icono, nombre, chip de estatus,
  /// avance con barra y acceso al historial (misma navegación que móvil).
  Widget _portalProductoCard(ProductoCliente p) {
    final descripcion = (p.descripcion ?? '').trim();
    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: () => context.push('/productos/${p.cuentaId}'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PortalColors.primarySoft10,
                      borderRadius: BorderRadius.circular(kPortalRadiusMd),
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
                  _portalChipEstatus(p),
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
                      style: portalText(
                        size: 11,
                        color: PortalColors.mutedForeground,
                        tabular: true,
                      ),
                    ),
                  ),
                  if (p.saldoPendiente > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Faltan ${formatMXN(p.saldoPendiente)}',
                      style: portalText(
                        size: 11,
                        weight: FontWeight.w500,
                        color: PortalColors.warning,
                        tabular: true,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PortalProgressBar(percent: p.avancePct, height: 8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${p.avancePct.round()}%',
                    style: portalText(
                      size: 11,
                      weight: FontWeight.w600,
                      tabular: true,
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
                            child: PortalStatusChip(
                              small: true,
                              label:
                                  'Próx. pago ${portalShortDate(p.proximaFecha)}',
                              icon: Icons.event_outlined,
                              background: PortalColors.warningSoft10,
                              foreground: PortalColors.warning,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ver historial',
                    style: portalText(
                      size: 12,
                      weight: FontWeight.w600,
                      color: PortalColors.primary,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: PortalColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de producto adicional: estatus, montos, avance y próximo pago.
class _ProductoCard extends StatelessWidget {
  final ProductoCliente p;

  const _ProductoCard({required this.p});

  BadgeTone get _badgeTone {
    final s = p.estatus.toLowerCase();
    if (s.contains('pagado')) return BadgeTone.positive;
    if (s.contains('curso')) return BadgeTone.neutral;
    return BadgeTone.pending;
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final descripcion = p.descripcion?.trim();
    return PressableScale(
      onTap: () => context.push('/productos/${p.cuentaId}'),
      child: AppCard(
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
                      color: tone.primarySoft, shape: BoxShape.circle),
                  child: const Icon(Icons.inventory_2_outlined,
                      size: 18, color: SozuColors.emerald600),
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
                            color: tone.textPrimary),
                      ),
                      if (descripcion != null && descripcion.isNotEmpty)
                        Text(
                          descripcion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: tone.textSecondary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(label: p.estatus, tone: _badgeTone),
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
                    style:
                        TextStyle(fontSize: 12, color: tone.textSecondary),
                  ),
                ),
                if (p.saldoPendiente > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Faltan ${formatMXN(p.saldoPendiente)}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tone.pending),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: SozuProgressBar(percent: p.avancePct)),
                const SizedBox(width: 8),
                Text(
                  '${p.avancePct.round()}%',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tone.textSecondary),
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
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: tone.pendingSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event_outlined,
                                    size: 12, color: SozuColors.amber600),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Próx. pago ${formatDate(p.proximaFecha)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: SozuColors.amber600),
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
                      color: SozuColors.emerald600),
                ),
                const Icon(Icons.chevron_right,
                    size: 16, color: SozuColors.emerald600),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
