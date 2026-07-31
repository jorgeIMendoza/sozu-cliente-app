import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/providers/data_providers.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/widgets/portal_property_card.dart';
import 'package:sozu_cliente_app/widgets/portal_top_bar.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';
import 'package:sozu_cliente_app/widgets/property_card.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

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
        .where(
          (p) => '${p.proyecto} ${p.nombre} ${p.ubicacion ?? ''}'
              .toLowerCase()
              .contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final props = ref.watch(clientePropiedadesProvider);

    // Modo portal (web ≥1024): réplica de ClienteEnAdquisicion del Portal
    // del Cliente, sin AppBar propio (la topbar la pinta el shell). La vista
    // móvil de abajo queda intacta.
    if (isPortalMode(context)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: props.when(
          loading: () => const SingleChildScrollView(
            padding: EdgeInsets.only(top: 24, bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PortalPageHeader(
                  title: 'En adquisición',
                  subtitle: 'Propiedades en proceso de compra',
                ),
                SizedBox(height: 20),
                PortalCardGrid(
                  children: [PortalCardSkeleton(), PortalCardSkeleton()],
                ),
              ],
            ),
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            children: [
              SErrorState(
                title: 'No pudimos cargar tus propiedades',
                onRetry: () => ref.invalidate(clientePropiedadesProvider),
              ),
            ],
          ),
          data: (data) => _portalContenido(data),
        ),
      );
    }

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
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SSkeleton(width: 160, height: 12),
                    SizedBox(height: 8),
                    SSkeleton(width: 220, height: 24),
                  ],
                ),
              ),
              SizedBox(height: 16),
              SCard(
                child: Column(
                  children: [
                    SSkeleton(height: 160, radius: 12),
                    SizedBox(height: 12),
                    SSkeleton(height: 16),
                  ],
                ),
              ),
            ],
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SErrorState(
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
                    style: TextStyle(fontSize: 14, color: tone.fgMuted),
                  ),
                  const SizedBox(height: 16),
                  SCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INVERSIÓN EN ADQUISICIÓN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                            color: tone.fgSubtle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatMXN(data.totalAdquisicion),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: tone.fg,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SSectionLabel.heading(
                    icon: Icons.home_outlined,
                    text: 'Propiedades',
                  ),
                  if (data.enAdquisicion.isEmpty)
                    const SEmptyState.card(
                      icon: Icons.shopping_bag_outlined,
                      title: 'No tienes propiedades en proceso de compra.',
                    )
                  else ...[
                    TextField(
                      onChanged: (v) => setState(() => _busqueda = v),
                      textInputAction: TextInputAction.search,
                      style: TextStyle(fontSize: 14, color: tone.fg),
                      decoration: InputDecoration(
                        hintText: 'Buscar propiedad…',
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
                    const SizedBox(height: 16),
                    if (filtradas.isEmpty)
                      const SEmptyState.card(
                        icon: Icons.search_off_outlined,
                        title: 'Sin resultados',
                      )
                    else
                      ResponsiveCardGrid(
                        children: [
                          for (final it in filtradas)
                            PropertyCardWidget(
                              item: it,
                              onTap: () => context.push('/propiedad/${it.id}'),
                            ),
                        ],
                      ),
                  ],

                  if (data.productos.isNotEmpty) ...[
                    SSectionLabel.heading(
                      icon: Icons.inventory_2_outlined,
                      text: 'Productos adicionales (${data.productos.length})',
                    ),
                    for (final p in data.productos) ...[
                      _ProductoRow(
                        p: p,
                        onTap: () => context.push('/productos/${p.id}'),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],

                  if (data.mantenimiento.isNotEmpty) ...[
                    const SSectionLabel.heading(
                      icon: Icons.build_outlined,
                      text: 'Mantenimiento',
                    ),
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

  // ── Vista "modo portal" (réplica de ClienteEnAdquisicion.tsx) ─────────────
  Widget _portalContenido(ClientePropiedades data) {
    final n = data.enAdquisicion.length;
    final filtradas = _filtrar(data.enAdquisicion);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PortalPageHeader(
            title: 'En adquisición',
            subtitle: n > 0
                ? 'Propiedades en proceso de compra · $n '
                      '${n == 1 ? 'unidad activa' : 'unidades activas'}'
                : 'Propiedades en proceso de compra',
          ),
          const SizedBox(height: 20),
          if (data.enAdquisicion.isEmpty)
            const PortalEmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'No hay compras en curso',
              message:
                  'Cuando inicies una nueva adquisición, aparecerá aquí '
                  'con su progreso, pagos pendientes y documentación.',
            )
          else ...[
            PortalSearchField(
              hint: 'Buscar propiedad…',
              onChanged: (v) => setState(() => _busqueda = v),
            ),
            const SizedBox(height: 16),
            if (filtradas.isEmpty)
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
              PortalCardGrid(
                children: [
                  for (final it in filtradas)
                    PortalAcquisitionCard(
                      item: it,
                      onTap: () => context.push('/propiedad/${it.id}'),
                    ),
                ],
              ),
          ],
          // Secciones extra del app (no existen en la página del portal, se
          // conservan con estilos del portal para no perder funcionalidad).
          if (data.productos.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Productos adicionales (${data.productos.length})',
              style: portalText(size: 15, weight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            PortalCard(
              clip: true,
              child: Column(
                children: [
                  for (var i = 0; i < data.productos.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: PortalColors.border),
                    _PortalProductoRow(
                      p: data.productos[i],
                      onTap: () =>
                          context.push('/productos/${data.productos[i].id}'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (data.mantenimiento.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Mantenimiento',
              style: portalText(size: 15, weight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            PortalCard(
              clip: true,
              child: Column(
                children: [
                  for (var i = 0; i < data.mantenimiento.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: PortalColors.border),
                    _PortalMantenimientoRow(m: data.mantenimiento[i]),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila de producto adicional en modo portal.
class _PortalProductoRow extends StatelessWidget {
  final ProductoCard p;
  final VoidCallback onTap;

  const _PortalProductoRow({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: hovered ? PortalColors.mutedHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: PortalColors.primarySoft10,
                  shape: BoxShape.circle,
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
                    const SizedBox(height: 2),
                    Text(
                      '${p.propiedad} · ${p.avancePago.round()}% pagado',
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
              Text(
                formatMXN(p.monto),
                style: portalText(
                  size: 14,
                  weight: FontWeight.w700,
                  tabular: true,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: PortalColors.mutedForeground.withValues(alpha: .4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de mantenimiento en modo portal.
class _PortalMantenimientoRow extends StatelessWidget {
  final MantenimientoCard m;

  const _PortalMantenimientoRow({required this.m});

  @override
  Widget build(BuildContext context) {
    final alDia = m.saldoPendiente <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: PortalColors.warningSoft10,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.build_outlined,
              size: 16,
              color: PortalColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mantenimiento · ${m.propiedad}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: portalText(size: 13, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  alDia ? 'Al día' : 'Próximo: ${formatDate(m.proximoPago)}',
                  style: portalText(
                    size: 11,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (alDia)
            const PortalStatusChip(
              small: true,
              label: 'Al día',
              icon: Icons.check_circle_outline,
              background: PortalColors.primarySoft15,
              foreground: PortalColors.primary,
            )
          else
            Text(
              formatMXN(m.saldoPendiente),
              style: portalText(
                size: 14,
                weight: FontWeight.w700,
                color: PortalColors.warning,
                tabular: true,
              ),
            ),
        ],
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
    final tone = context.s.color;
    return PressableScale(
      onTap: onTap,
      child: SCard(
        child: Row(
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
                  Text(
                    '${p.propiedad} · ${p.avancePago}% pagado',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: tone.fgMuted),
                  ),
                ],
              ),
            ),
            Text(
              formatMXN(p.monto),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tone.fg,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: tone.fgSubtle),
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
    final tone = context.s.color;
    final alDia = m.saldoPendiente <= 0;
    return SCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.warningSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.build_outlined,
              size: 18,
              color: SozuAmber.strong,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mantenimiento · ${m.propiedad}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tone.fg,
                  ),
                ),
                Text(
                  alDia ? 'Al día' : 'Próximo: ${formatDate(m.proximoPago)}',
                  style: TextStyle(fontSize: 12, color: tone.fgMuted),
                ),
              ],
            ),
          ),
          if (alDia)
            const SBadge(label: 'Al día', tone: SBadgeTone.positive)
          else
            Text(
              formatMXN(m.saldoPendiente),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tone.warningFg,
              ),
            ),
        ],
      ),
    );
  }
}
