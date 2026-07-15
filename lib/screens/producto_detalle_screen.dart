import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/open_media.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';

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
    final productos = ref.watch(clienteProductosProvider);
    final producto = productos.valueOrNull?.productoPorCuenta(widget.cuentaId);

    return Scaffold(
      appBar: AppBar(title: Text(producto?.nombre ?? 'Producto')),
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
        data: (_) => producto == null
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  EmptyCard(
                    icon: Icons.inventory_2_outlined,
                    text: 'Producto no encontrado.',
                  ),
                ],
              )
            : _contenido(producto),
      ),
    );
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
