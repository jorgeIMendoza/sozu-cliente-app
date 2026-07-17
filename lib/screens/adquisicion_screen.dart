import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';
import '../widgets/portal_top_bar.dart';
import '../widgets/property_card.dart';

/// En adquisición: propiedades en proceso de compra (con buscador en vivo) +
/// productos adicionales (con nombre real) + mantenimiento, en secciones
/// separadas.
class AdquisicionScreen extends ConsumerStatefulWidget {
  const AdquisicionScreen({super.key});

  @override
  ConsumerState<AdquisicionScreen> createState() => _AdquisicionScreenState();
}

class _AdquisicionScreenState extends ConsumerState<AdquisicionScreen> {
  String _busqueda = '';

  List<PropiedadCard> _filtrar(List<PropiedadCard> items) {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where((p) => '${p.proyecto} ${p.nombre} ${p.ubicacion ?? ''}'
            .toLowerCase()
            .contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final props = ref.watch(clientePropiedadesProvider);

    return Scaffold(
      appBar: const PortalTopBar(title: 'En adquisición'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clientePropiedadesProvider);
          try {
            await ref.read(clientePropiedadesProvider.future);
          } catch (_) {}
        },
        child: props.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 160, height: 12),
                    SizedBox(height: 8),
                    Skeleton(width: 220, height: 24),
                  ],
                ),
              ),
              SizedBox(height: 16),
              AppCard(
                child: Column(
                  children: [
                    Skeleton(height: 160, radius: 12),
                    SizedBox(height: 12),
                    Skeleton(height: 16),
                  ],
                ),
              ),
            ],
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorCard(
                title: 'No pudimos cargar tus propiedades',
                onRetry: () => ref.invalidate(clientePropiedadesProvider),
              ),
            ],
          ),
          data: (data) {
            final n = data.enAdquisicion.length;
            final filtradas = _filtrar(data.enAdquisicion);
            return ContentFrame(
            child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Text(
                  n > 0
                      ? 'Propiedades en proceso de compra · $n ${n == 1 ? 'unidad activa' : 'unidades activas'}'
                      : 'Propiedades en proceso de compra',
                  style: TextStyle(fontSize: 14, color: tone.textSecondary)),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INVERSIÓN EN ADQUISICIÓN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: tone.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatMXN(data.totalAdquisicion),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: tone.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SectionTitle(icon: Icons.home_outlined, text: 'Propiedades'),
              if (data.enAdquisicion.isEmpty)
                const EmptyCard(
                  icon: Icons.shopping_bag_outlined,
                  text: 'No tienes propiedades en proceso de compra.',
                )
              else ...[
                TextField(
                  onChanged: (v) => setState(() => _busqueda = v),
                  textInputAction: TextInputAction.search,
                  style: TextStyle(fontSize: 14, color: tone.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar propiedad…',
                    prefixIcon:
                        Icon(Icons.search, size: 20, color: tone.textMuted),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                if (filtradas.isEmpty)
                  const EmptyCard(
                    icon: Icons.search_off_outlined,
                    text: 'Sin resultados',
                  )
                else
                  ResponsiveCardGrid(
                    children: [
                      for (final it in filtradas)
                        PropertyCardWidget(
                            item: it,
                            onTap: () => context.push('/propiedad/${it.id}')),
                    ],
                  ),
              ],

              if (data.productos.isNotEmpty) ...[
                SectionTitle(
                    icon: Icons.inventory_2_outlined,
                    text: 'Productos adicionales (${data.productos.length})'),
                for (final p in data.productos) ...[
                  _ProductoRow(
                      p: p,
                      onTap: () => context.push('/productos/${p.id}')),
                  const SizedBox(height: 10),
                ],
              ],

              if (data.mantenimiento.isNotEmpty) ...[
                const SectionTitle(
                    icon: Icons.build_outlined, text: 'Mantenimiento'),
                for (final m in data.mantenimiento) ...[
                  _MantenimientoRow(m: m),
                  const SizedBox(height: 10),
                ],
              ],
            ],
            ),
            );
          },
        ),
      ),
    );
  }
}

class _ProductoRow extends StatelessWidget {
  final ProductoCard p;
  final VoidCallback? onTap;

  const _ProductoRow({required this.p, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return PressableScale(
      onTap: onTap,
      child: AppCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(color: tone.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2_outlined,
                size: 18, color: SozuColors.emerald600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tone.textPrimary)),
                Text('${p.propiedad} · ${p.avancePago}% pagado',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: tone.textSecondary)),
              ],
            ),
          ),
          Text(formatMXN(p.monto),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tone.textPrimary)),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: tone.textMuted),
          ],
        ],
      ),
      ),
    );
  }
}

class _MantenimientoRow extends StatelessWidget {
  final MantenimientoCard m;

  const _MantenimientoRow({required this.m});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final alDia = m.saldoPendiente <= 0;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(color: tone.pendingSoft, shape: BoxShape.circle),
            child: const Icon(Icons.build_outlined,
                size: 18, color: SozuColors.amber600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mantenimiento · ${m.propiedad}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tone.textPrimary)),
                Text(
                  alDia ? 'Al día' : 'Próximo: ${formatDate(m.proximoPago)}',
                  style: TextStyle(fontSize: 12, color: tone.textSecondary),
                ),
              ],
            ),
          ),
          if (alDia)
            const StatusBadge(label: 'Al día', tone: BadgeTone.positive)
          else
            Text(formatMXN(m.saldoPendiente),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tone.pending)),
        ],
      ),
    );
  }
}
