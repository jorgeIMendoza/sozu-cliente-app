import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/open_media.dart';
import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';
import '../widgets/portal_widgets.dart';

/// Detalle/historial de un producto adicional (paridad con
/// ProductoHistorialView del portal admin): resumen con KPIs y progreso,
/// CLABE copiable, filtros (año/estatus) e historial agrupado por mes.
class ProductoDetalleScreen extends ConsumerStatefulWidget {
  final int cuentaId;

  const ProductoDetalleScreen({super.key, required this.cuentaId});

  @override
  ConsumerState<ProductoDetalleScreen> createState() =>
      _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends ConsumerState<ProductoDetalleScreen> {
  String _anio = 'todos';
  String _estatus = 'todos'; // todos | pagado | pendiente

  static const _meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final portal = isPortalMode(context);
    final productos = ref.watch(clienteProductosProvider);
    final producto = productos.valueOrNull?.productoPorCuenta(widget.cuentaId);

    return Scaffold(
      // Modo portal: el shell ya pinta el título; sin AppBar propio.
      backgroundColor: portal ? Colors.transparent : null,
      appBar: portal
          ? null
          : AppBar(title: Text(producto?.nombre ?? 'Producto')),
      body: productos.when(
        loading: () => const _LoadingDetalle(),
        error: (_, __) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ErrorCard(
              title: 'No pudimos cargar el producto',
              onRetry: () => ref.invalidate(clienteProductosProvider),
            ),
          ],
        ),
        data: (d) => producto == null
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  EmptyCard(
                    icon: Icons.inventory_2_outlined,
                    text: 'Producto no encontrado.',
                  ),
                ],
              )
            : portal
            ? _portalContenido(producto, _grupoDe(d, producto))
            : _contenido(producto),
      ),
    );
  }

  /// Propiedad a la que pertenece el producto (para el subtítulo y el resumen
  /// del modo portal).
  ProductosPropiedad? _grupoDe(ClienteProductos d, ProductoCliente p) {
    for (final g in d.propiedades) {
      if (g.productos.any((x) => x.cuentaId == p.cuentaId)) return g;
    }
    return null;
  }

  Future<void> _refresh() {
    ref.invalidate(clienteProductosProvider);
    return ref.read(clienteProductosProvider.future);
  }

  Widget _contenido(ProductoCliente p) {
    final tone = SozuTone.of(context);

    // Años disponibles (derivados de las fechas de los acuerdos).
    final anios = <String>{
      for (final a in p.acuerdos)
        if ((a.fecha ?? '').length >= 4) a.fecha!.substring(0, 4),
    }.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _resumen(tone, p),
          const SizedBox(height: 12),
          _filtros(tone, anios),
          const SizedBox(height: 4),
          ..._historial(tone, p),
        ],
      ),
    );
  }

  // ── Resumen ────────────────────────────────────────────────────────────────
  Widget _resumen(SozuTone tone, ProductoCliente p) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  p.nombre,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tone.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(label: p.estatus, tone: _badgeEstatus(p.estatus)),
            ],
          ),
          if ((p.descripcion ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              p.descripcion!.trim(),
              style: TextStyle(fontSize: 13, color: tone.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpi(tone, 'Valor', formatMXN(p.precioFinal), tone.textPrimary),
              _kpi(tone, 'Pagado', formatMXN(p.totalPagado), tone.positive),
              _kpi(tone, 'Saldo', formatMXN(p.saldoPendiente), tone.pending),
              if ((p.proximaFecha ?? '').isNotEmpty)
                _kpi(
                  tone,
                  'Próx. pago',
                  formatDate(p.proximaFecha),
                  tone.textPrimary,
                ),
            ],
          ),
          Divider(color: tone.border, height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Progreso de pago',
                  style: TextStyle(fontSize: 11, color: tone.textMuted),
                ),
              ),
              Text(
                '${p.avancePct.round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tone.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SozuProgressBar(percent: p.avancePct),
          if ((p.clabe ?? '').trim().isNotEmpty) ...[
            Divider(color: tone.border, height: 24),
            _clabeRow(tone, p.clabe!.trim()),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: tone.primaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Realiza tu transferencia (STP) solo a esta CLABE. '
                    'Está vinculada exclusivamente a este producto.',
                    style: TextStyle(fontSize: 12, color: tone.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _clabeRow(SozuTone tone, String clabe) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            'CLABE',
            style: TextStyle(fontSize: 13, color: tone.textSecondary),
          ),
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              clabe,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: tone.textPrimary,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copiar',
          iconSize: 16,
          icon: Icon(Icons.copy_outlined, color: tone.textMuted),
          onPressed: () => _copiar(clabe, 'CLABE'),
        ),
      ],
    );
  }

  Future<void> _copiar(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _snack('$label copiada.');
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  BadgeTone _badgeEstatus(String estatus) {
    final e = estatus.toLowerCase();
    if (e.contains('pagado') || e.contains('liquidad')) {
      return BadgeTone.positive;
    }
    if (e.contains('pendiente') || e.contains('vencid')) {
      return BadgeTone.pending;
    }
    return BadgeTone.neutral; // En curso
  }

  Widget _kpi(SozuTone tone, String label, String value, Color color) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: tone.textMuted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filtros ────────────────────────────────────────────────────────────────
  Widget _filtros(SozuTone tone, List<String> anios) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(
              tone,
              'Todos',
              _estatus == 'todos',
              () => setState(() => _estatus = 'todos'),
            ),
            _chip(
              tone,
              'Pagados',
              _estatus == 'pagado',
              () => setState(() => _estatus = 'pagado'),
            ),
            _chip(
              tone,
              'Pendientes',
              _estatus == 'pendiente',
              () => setState(() => _estatus = 'pendiente'),
            ),
          ],
        ),
        if (anios.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                tone,
                'Todos los años',
                _anio == 'todos',
                () => setState(() => _anio = 'todos'),
              ),
              for (final y in anios)
                _chip(tone, y, _anio == y, () => setState(() => _anio = y)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _chip(SozuTone tone, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? tone.primaryDark : tone.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : tone.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Historial agrupado por mes ─────────────────────────────────────────────
  List<Widget> _historial(SozuTone tone, ProductoCliente p) {
    final acuerdos = p.acuerdos.where((a) {
      if (_estatus == 'pagado' && !a.completado) return false;
      if (_estatus == 'pendiente' && a.completado) return false;
      if (_anio != 'todos' && !(a.fecha ?? '').startsWith(_anio)) return false;
      return true;
    }).toList()..sort((a, b) => (b.fecha ?? '').compareTo(a.fecha ?? ''));

    if (acuerdos.isEmpty) {
      return const [
        EmptyCard(
          icon: Icons.receipt_long_outlined,
          text: 'Sin movimientos con ese filtro.',
        ),
      ];
    }

    // Agrupación por mes (YYYY-MM), más reciente primero.
    final grupos = <String, List<ProductoAcuerdo>>{};
    for (final a in acuerdos) {
      final f = a.fecha ?? '';
      final key = f.length >= 7 ? f.substring(0, 7) : '';
      grupos.putIfAbsent(key, () => []).add(a);
    }

    return [
      for (final g in grupos.entries) ...[
        _mesHeader(tone, g.key, g.value),
        for (final a in g.value) ...[
          _acuerdoRow(tone, a),
          const SizedBox(height: 8),
        ],
      ],
    ];
  }

  Widget _mesHeader(SozuTone tone, String ym, List<ProductoAcuerdo> items) {
    final totalMes = items.fold<double>(0, (s, a) => s + a.monto);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _mesLabel(ym),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tone.textPrimary,
              ),
            ),
          ),
          Text(
            formatMXN(totalMes),
            style: TextStyle(fontSize: 12, color: tone.textSecondary),
          ),
        ],
      ),
    );
  }

  String _mesLabel(String ym) {
    if (ym.length < 7) return 'Sin fecha';
    final mes = int.tryParse(ym.substring(5, 7));
    if (mes == null || mes < 1 || mes > 12) return ym;
    return '${_meses[mes - 1]} ${ym.substring(0, 4)}';
  }

  Widget _acuerdoRow(SozuTone tone, ProductoAcuerdo a) {
    final parcial = !a.completado && a.pagado > 0.01 && a.pagado < a.monto;
    final faltante = (a.monto - a.pagado).clamp(0, a.monto).toDouble();
    // Fecha real de pago si difiere de la fecha compromiso.
    final pagadoOtroDia =
        a.completado &&
        (a.fechaPago ?? '').isNotEmpty &&
        a.fechaPago != a.fecha;
    final tieneCep = (a.urlCep ?? '').isNotEmpty;
    final tieneRecibo = (a.urlRecibo ?? '').isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  a.concepto,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tone.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: a.completado
                    ? 'Pagado'
                    : parcial
                    ? 'Parcial'
                    : 'Pendiente',
                tone: a.completado
                    ? BadgeTone.positive
                    : parcial
                    ? BadgeTone.pending
                    : BadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                formatDate(a.fecha),
                style: TextStyle(fontSize: 12, color: tone.textSecondary),
              ),
              if (pagadoOtroDia)
                Text(
                  'Pagado el ${formatDate(a.fechaPago)}',
                  style: TextStyle(fontSize: 12, color: tone.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatMXN(a.monto),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: tone.textPrimary,
            ),
          ),
          if (parcial) ...[
            const SizedBox(height: 4),
            Text(
              'Faltan ${formatMXN(faltante)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SozuColors.amber600,
              ),
            ),
          ],
          if (tieneCep || tieneRecibo) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (tieneCep)
                  _docBtn(
                    tone,
                    Icons.receipt_long_outlined,
                    'CEP',
                    () => openMedia(context, a.urlCep, titulo: 'CEP'),
                  ),
                if (tieneRecibo)
                  _docBtn(
                    tone,
                    Icons.description_outlined,
                    'Recibo',
                    () => openMedia(context, a.urlRecibo, titulo: 'Recibo'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _docBtn(
    SozuTone tone,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: tone.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: tone.primaryDark),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tone.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODO PORTAL (web ≥1024): réplica del historial de producto del Portal del
  // Cliente (ProductoHistorialView.tsx): filtros + tabla "Movimientos" a la
  // izquierda y card resumen (300px) a la derecha. Solo capa visual.
  // ═══════════════════════════════════════════════════════════════════════════

  // Anchos fijos de columnas de la tabla (CONCEPTO es flexible).
  static const double _wFecha = 112;
  static const double _wMonto = 140;
  static const double _wEstatus = 112;
  static const double _wComp = 110;
  static const double _minTablaWidth = 620;

  /// Fondo de thead (`bg-muted/10` aplanado, tokens.md §1.1).
  static const Color _theadBg = Color(0xFFFDFEFE);

  /// Chip de estatus del producto (STATUS_CLASS del portal).
  PortalStatusChip _portalChipEstatus(ProductoCliente p, {bool small = false}) {
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

  /// Fecha efectiva del movimiento (toMovement del portal): la de pago si ya
  /// se completó, si no la fecha compromiso.
  String? _fechaMov(ProductoAcuerdo a) =>
      (a.completado && (a.fechaPago ?? '').isNotEmpty) ? a.fechaPago : a.fecha;

  Widget _portalContenido(ProductoCliente p, ProductosPropiedad? g) {
    final anios = <String>{
      for (final a in p.acuerdos)
        if ((a.fecha ?? '').length >= 4) a.fecha!.substring(0, 4),
    }.toList()..sort((a, b) => b.compareTo(a));

    // Mismos filtros que la vista móvil; tabla plana más reciente primero.
    final acuerdos = p.acuerdos.where((a) {
      if (_estatus == 'pagado' && !a.completado) return false;
      if (_estatus == 'pendiente' && a.completado) return false;
      if (_anio != 'todos' && !(a.fecha ?? '').startsWith(_anio)) return false;
      return true;
    }).toList()..sort(
      (a, b) => (_fechaMov(b) ?? '').compareTo(_fechaMov(a) ?? ''),
    );

    final unidad = g == null
        ? null
        : (g.propiedad.startsWith('U-') ? g.propiedad : 'U-${g.propiedad}');
    final descripcion = (p.descripcion ?? '').trim();

    final izquierda = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _portalFiltros(anios),
        const SizedBox(height: 16),
        _portalMovimientos(acuerdos),
      ],
    );
    final derecha = _portalResumen(p, g);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 24, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: portalText(
                          size: 26,
                          weight: FontWeight.w700,
                          letterSpacing: -0.65,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (g != null) '${g.proyecto} · $unidad',
                          if (descripcion.isNotEmpty) descripcion,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: portalText(
                          size: 12,
                          color: PortalColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _portalChipEstatus(p),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, cons) {
                if (cons.maxWidth < kTwoColBreakpoint) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [izquierda, const SizedBox(height: 16), derecha],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: izquierda),
                    const SizedBox(width: 24),
                    SizedBox(width: 300, child: derecha),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Card de filtros (filterBar del portal) ────────────────────────────────
  Widget _portalFiltros(List<String> anios) {
    Widget fila(String label, List<Widget> pills) => Row(
      children: [
        PortalSectionLabel(label),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 6,
            children: pills,
          ),
        ),
      ],
    );

    return PortalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fila('Período', [
            PortalPill(
              label: 'Todos',
              active: _anio == 'todos',
              onTap: () => setState(() => _anio = 'todos'),
            ),
            for (final y in anios)
              PortalPill(
                label: y,
                active: _anio == y,
                onTap: () => setState(() => _anio = y),
              ),
          ]),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PortalColors.border)),
            ),
            child: fila('Estatus', [
              PortalPill(
                label: 'Todos',
                active: _estatus == 'todos',
                onTap: () => setState(() => _estatus = 'todos'),
              ),
              PortalPill(
                label: 'Pagados',
                active: _estatus == 'pagado',
                onTap: () => setState(() => _estatus = 'pagado'),
              ),
              PortalPill(
                label: 'Pendientes',
                active: _estatus == 'pendiente',
                onTap: () => setState(() => _estatus = 'pendiente'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Card "Movimientos" con tabla (desktopTable del portal) ────────────────
  Widget _portalMovimientos(List<ProductoAcuerdo> acuerdos) {
    return PortalCard(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: PortalColors.mutedSoft20,
              border: Border(bottom: BorderSide(color: PortalColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Movimientos',
                    style: portalText(size: 14, weight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${acuerdos.length} registro${acuerdos.length == 1 ? '' : 's'}',
                  style: portalText(
                    size: 11,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (acuerdos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Sin movimientos con ese filtro',
                  style: portalText(
                    size: 14,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, cons) {
                final w = cons.maxWidth < _minTablaWidth
                    ? _minTablaWidth
                    : cons.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _portalTablaHeader(),
                        for (var i = 0; i < acuerdos.length; i++)
                          _portalTablaFila(
                            acuerdos[i],
                            last: i == acuerdos.length - 1,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _portalTablaHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: _theadBg,
        border: Border(bottom: BorderSide(color: PortalColors.border)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: _wFecha,
            child: Padding(
              padding: EdgeInsets.only(left: 20, right: 12),
              child: PortalSectionLabel('Fecha'),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: PortalSectionLabel('Concepto'),
            ),
          ),
          SizedBox(
            width: _wMonto,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: PortalSectionLabel('Monto'),
              ),
            ),
          ),
          SizedBox(
            width: _wEstatus,
            child: Center(child: PortalSectionLabel('Estatus')),
          ),
          SizedBox(
            width: _wComp,
            child: Padding(
              padding: EdgeInsets.only(left: 12, right: 20),
              child: Center(child: PortalSectionLabel('Comprobante')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _portalTablaFila(ProductoAcuerdo a, {required bool last}) {
    final parcial = !a.completado && a.pagado > 0.01 && a.pagado < a.monto;
    final faltante = (a.monto - a.pagado).clamp(0, a.monto).toDouble();
    final tieneCep = (a.urlCep ?? '').isNotEmpty;
    final tieneRecibo = (a.urlRecibo ?? '').isNotEmpty;

    final chip = a.completado
        ? const PortalStatusChip(
            label: 'Pagado',
            icon: Icons.check_circle_outlined,
            background: PortalColors.primarySoft10,
            foreground: PortalColors.primary,
          )
        : PortalStatusChip(
            label: parcial ? 'Parcial' : 'Pendiente',
            icon: Icons.schedule,
            background: PortalColors.warningSoft10,
            foreground: PortalColors.warning,
          );

    // MONTO: parcial con desglose (MontoCell del portal).
    final Widget monto = parcial
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMXN(a.pagado),
                style: portalText(
                  size: 13,
                  weight: FontWeight.w600,
                  tabular: true,
                ),
              ),
              Text(
                'de ${formatMXN(a.monto)}',
                style: portalText(
                  size: 10,
                  color: PortalColors.mutedForeground,
                  tabular: true,
                ),
              ),
              Text(
                'Faltan ${formatMXN(faltante)}',
                style: portalText(
                  size: 10,
                  weight: FontWeight.w500,
                  color: PortalColors.warning,
                  tabular: true,
                ),
              ),
            ],
          )
        : Text(
            formatMXN(a.monto),
            style: portalText(size: 13, weight: FontWeight.w600, tabular: true),
          );

    return PortalHoverBuilder(
      builder: (context, hovered) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: hovered ? PortalColors.mutedSoft20 : Colors.transparent,
          border: last
              ? null
              : const Border(bottom: BorderSide(color: PortalColors.border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: _wFecha,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 12),
                child: Text(
                  portalShortDate(_fechaMov(a)),
                  style: portalText(
                    size: 12,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.concepto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: portalText(size: 13, weight: FontWeight.w500),
                    ),
                    if (a.completado &&
                        (a.fechaPago ?? '').isNotEmpty &&
                        a.fechaPago != a.fecha)
                      Text(
                        'Compromiso ${portalShortDate(a.fecha)}',
                        style: portalText(
                          size: 10,
                          color: PortalColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: _wMonto,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(alignment: Alignment.centerRight, child: monto),
              ),
            ),
            SizedBox(
              width: _wEstatus,
              child: Center(child: chip),
            ),
            SizedBox(
              width: _wComp,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 20),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PortalIconBtn(
                        icon: Icons.description_outlined,
                        tooltip: tieneRecibo ? 'Ver recibo' : 'Sin recibo',
                        onTap: tieneRecibo
                            ? () => openMedia(
                                context,
                                a.urlRecibo,
                                titulo: 'Recibo',
                              )
                            : null,
                      ),
                      PortalIconBtn(
                        icon: Icons.receipt_long_outlined,
                        tooltip: tieneCep
                            ? 'CEP electrónico'
                            : 'Sin comprobante',
                        onTap: tieneCep
                            ? () => openMedia(context, a.urlCep, titulo: 'CEP')
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card resumen (summaryBlock del portal) ────────────────────────────────
  Widget _portalResumen(ProductoCliente p, ProductosPropiedad? g) {
    final now = DateTime.now();
    final periodo = '${_meses[now.month - 1]} ${now.year}';
    final pendientes = p.acuerdos.where((a) => !a.completado).toList()
      ..sort((a, b) => (a.fecha ?? '').compareTo(b.fecha ?? ''));
    final proximo = pendientes.isEmpty ? null : pendientes.first;
    final unidad = g == null
        ? null
        : (g.propiedad.startsWith('U-') ? g.propiedad : 'U-${g.propiedad}');

    Widget sep() => Container(
      height: 1,
      margin: const EdgeInsets.only(top: 16, bottom: 12),
      color: PortalColors.border,
    );

    Widget finRow(
      String label,
      String value, {
      Color? color,
      bool bold = false,
    }) => Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: portalText(size: 12, color: PortalColors.mutedForeground),
          ),
        ),
        Text(
          value,
          style: portalText(
            size: 14,
            weight: bold ? FontWeight.w700 : FontWeight.w600,
            color: color ?? PortalColors.foreground,
            tabular: true,
          ),
        ),
      ],
    );

    return PortalCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'sozu',
                style: portalText(
                  size: 15,
                  weight: FontWeight.w700,
                  letterSpacing: -0.6,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '-',
                style: portalText(
                  size: 12,
                  color: PortalColors.mutedForeground,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Producto Adicional',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: portalText(size: 12, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              _portalChipEstatus(p, small: true),
            ],
          ),
          sep(),
          PortalInfoRow(label: 'Producto', value: p.nombre),
          if (g != null) ...[
            const SizedBox(height: 4),
            PortalInfoRow(
              label: 'Propiedad',
              value: '${g.proyecto} · $unidad',
            ),
          ],
          const SizedBox(height: 4),
          PortalInfoRow(label: 'Periodo', value: periodo),
          sep(),
          finRow('Valor del Activo', formatMXN(p.precioFinal), bold: true),
          const SizedBox(height: 10),
          finRow(
            'Total Pagado',
            formatMXN(p.totalPagado),
            color: PortalColors.primary,
          ),
          const SizedBox(height: 10),
          finRow('Saldo Pendiente', formatMXN(p.saldoPendiente)),
          if (proximo != null) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              color: PortalColors.border,
            ),
            Text(
              'Próximo Pago',
              style: portalText(size: 10, color: PortalColors.mutedForeground),
            ),
            const SizedBox(height: 2),
            Text(
              formatMXN(proximo.monto),
              style: portalText(
                size: 14,
                weight: FontWeight.w600,
                tabular: true,
              ),
            ),
            Text(
              'Vence ${portalShortDate(proximo.fecha)}',
              style: portalText(size: 11, color: PortalColors.mutedForeground),
            ),
          ],
          sep(),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Progreso',
                  style: portalText(
                    size: 11,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ),
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
          const SizedBox(height: 6),
          PortalProgressBar(percent: p.avancePct, height: 8),
          if ((p.clabe ?? '').trim().isNotEmpty) ...[
            sep(),
            PortalInfoRow(
              label: 'CLABE STP',
              value: p.clabe!.trim(),
              mono: true,
              onCopy: () => _copiar(p.clabe!.trim(), 'CLABE'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingDetalle extends StatelessWidget {
  const _LoadingDetalle();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 180, height: 16),
            SizedBox(height: 12),
            Skeleton(width: 240, height: 30),
            SizedBox(height: 12),
            Skeleton(height: 10, radius: 999),
          ],
        ),
      ),
      SizedBox(height: 12),
      Skeleton(height: 90, radius: 16),
      SizedBox(height: 8),
      Skeleton(height: 90, radius: 16),
    ],
  );
}
