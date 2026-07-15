import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';

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
    final productos = ref.watch(clienteProductosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
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
    return GestureDetector(
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
