import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/properties/providers/properties_providers.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/features/client/properties/components/patrimonio_card.dart';
import 'package:sozu_cliente_app/features/client/properties/components/portal_property_card.dart';
import 'package:sozu_cliente_app/features/client/layouts/portal_top_bar.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Mi patrimonio: propiedades entregadas + KPIs (unidades, valor actual y
/// plusvalía acumulada) + buscador en vivo.
class PatrimonioScreen extends ConsumerStatefulWidget {
  const PatrimonioScreen({super.key});

  @override
  ConsumerState<PatrimonioScreen> createState() => _PatrimonioScreenState();
}

class _PatrimonioScreenState extends ConsumerState<PatrimonioScreen> {
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

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

  /// Cuenta de mantenimiento de la propiedad: cruce por id y, si no, por
  /// nombre (el backend arma `propiedad` con el nombre de la unidad).
  MantenimientoCard? _mantenimientoDe(
    ClientePropiedades data,
    PropiedadCard p,
  ) {
    for (final m in data.mantenimiento) {
      if (m.id == p.id) return m;
      if (p.nombre != '-' &&
          m.propiedad != '-' &&
          (m.propiedad == p.nombre ||
              m.propiedad.contains(p.nombre) ||
              p.nombre.contains(m.propiedad))) {
        return m;
      }
    }
    return null;
  }

  String _kpiPlusvalia(double monto, double? pct) {
    final base = '${monto >= 0 ? '+' : ''}${formatMXN(monto)}';
    if (pct == null) return base;
    return '$base (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)';
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final props = ref.watch(propertiesProvider);

    // Modo portal (web ≥1024): sin AppBar propio, la topbar la pinta el shell.
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
                  title: 'Mi patrimonio',
                  subtitle: 'Tus propiedades entregadas',
                ),
                SizedBox(height: 20),
                PortalCardGrid(
                  gap: 12,
                  minItemWidth: 180,
                  maxCols: 3,
                  children: [
                    PortalKpiSkeleton(),
                    PortalKpiSkeleton(),
                    PortalKpiSkeleton(),
                  ],
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
                onRetry: () => ref.invalidate(propertiesProvider),
              ),
            ],
          ),
          data: (data) => _portalContenido(data),
        ),
      );
    }

    return Scaffold(
      appBar: const PortalTopBar(title: 'Mi patrimonio'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(propertiesProvider);
          try {
            await ref.read(propertiesProvider.future);
          } catch (_) {}
        },
        child: props.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
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
                onRetry: () => ref.invalidate(propertiesProvider),
              ),
            ],
          ),
          data: (data) {
            final items = data.patrimonioActivo;
            final filtrados = _filtrar(items);
            final n = items.length;

            // Valor actual de mercado (fallback al total invertido si el
            // backend aún no lo envía).
            final valorActual = data.totalActivoValorActual ?? data.totalActivo;
            final plusvalia = data.totalPlusvalia;
            double? plusvaliaPct;
            if (plusvalia != null && data.totalActivoValorActual != null) {
              final invertido = data.totalActivoValorActual! - plusvalia;
              if (invertido > 0) plusvaliaPct = plusvalia / invertido * 100;
            }

            return ContentFrame(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  Text(
                    n > 0
                        ? 'Tus propiedades entregadas · $n ${n == 1 ? 'unidad' : 'unidades'}'
                        : 'Tus propiedades entregadas',
                    style: TextStyle(fontSize: 14, color: tone.fgMuted),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, c) {
                      final kpis = <Widget>[
                        _KpiCard(
                          label: 'Unidades activas',
                          value: '$n',
                          color: tone.positive,
                        ),
                        _KpiCard(
                          label: 'Valor actual',
                          value: formatMXN(valorActual),
                        ),
                        if (plusvalia != null)
                          _KpiCard(
                            label: 'Plusvalía acumulada',
                            value: _kpiPlusvalia(plusvalia, plusvaliaPct),
                            color: plusvalia >= 0 ? tone.positive : tone.danger,
                          ),
                      ];
                      const gap = 12.0;
                      final maxCols = c.maxWidth >= 700 ? 3 : 2;
                      final cols = kpis.length < maxCols
                          ? kpis.length
                          : maxCols;
                      final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final k in kpis)
                            SizedBox(width: itemW, child: k),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const SEmptyState.card(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Aún no tienes propiedades entregadas.',
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
                    if (filtrados.isEmpty)
                      const SEmptyState.card(
                        icon: Icons.search_off_outlined,
                        title: 'Sin resultados',
                      )
                    else
                      ResponsiveCardGrid(
                        children: [
                          for (final it in filtrados)
                            PatrimonioCard(
                              item: it,
                              mantenimiento: _mantenimientoDe(data, it),
                              onTap: () => context.push('/propiedad/${it.id}'),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Vista "modo portal" ───────────────────────────────────────────────────
  Widget _portalContenido(ClientePropiedades data) {
    final items = data.patrimonioActivo;
    final filtrados = _filtrar(items);
    final n = items.length;

    // Valor actual de mercado con fallback al total invertido.
    final valorActual = data.totalActivoValorActual ?? data.totalActivo;
    final plusvalia = data.totalPlusvalia;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PortalPageHeader(
            title: 'Mi patrimonio',
            subtitle: n > 0
                ? 'Tus propiedades entregadas · $n '
                      '${n == 1 ? 'unidad' : 'unidades'}'
                : 'Tus propiedades entregadas',
          ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            const SEmptyState.card(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Tu patrimonio se construirá aquí',
              message:
                  'Cuando alguna de tus propiedades sea entregada, '
                  'pasará automáticamente a esta sección donde podrás '
                  'gestionar mantenimiento, ver plusvalía y administrar '
                  'tus activos.',
            )
          else ...[
            // KPIs (Valor actual / Plusvalía acumulada / Unidades activas)
            PortalCardGrid(
              gap: 12,
              minItemWidth: 180,
              maxCols: 3,
              children: [
                PortalKpiCell(
                  label: 'Valor actual',
                  value: formatMXN(valorActual),
                ),
                if (plusvalia != null)
                  PortalKpiCell(
                    label: 'Plusvalía acumulada',
                    // Solo monto, nunca negativo (clamp ≥ 0) y siempre verde:
                    // la plusvalía acumulada del patrimonio no muestra % ni rojo.
                    value: '+${formatMXN(plusvalia < 0 ? 0.0 : plusvalia)}',
                    valueColor: PortalColors.primary,
                  ),
                PortalKpiCell(label: 'Unidades activas', value: '$n'),
              ],
            ),
            const SizedBox(height: 20),
            SSearchField(
              controller: _busquedaCtrl,
              hintText: 'Buscar propiedad…',
              onChanged: (v) => setState(() => _busqueda = v),
            ),
            const SizedBox(height: 16),
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
              PortalCardGrid(
                children: [
                  for (final it in filtrados)
                    PortalPatrimonyCard(
                      item: it,
                      mantenimiento: _mantenimientoDe(data, it),
                      onTap: () => context.push('/propiedad/${it.id}'),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// KPI compacto del encabezado (Unidades / Valor actual / Plusvalía).
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _KpiCard({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: tone.fgSubtle)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color ?? tone.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
