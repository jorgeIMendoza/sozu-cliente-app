import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/open_media.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../providers/impersonation_provider.dart';
import '../widgets/common.dart';
import '../widgets/payment_method_badge.dart';
import '../widgets/recibo_pago_sheet.dart';

const _kMeses = [
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

/// 'YYYY-MM' -> "Mes Año" en español ("2026-03" -> "Marzo 2026").
String _mesLabel(String key) {
  final parts = key.split('-');
  if (parts.length < 2) return 'Sin fecha';
  final m = int.tryParse(parts[1]);
  if (m == null || m < 1 || m > 12) return key;
  return '${_kMeses[m - 1]} ${parts[0]}';
}

/// Item unificado del historial: pago de inversión o cuota de mantenimiento.
class _ItemHistorial {
  final HistorialPago? pago;
  final MantenimientoPago? mantenimiento;

  _ItemHistorial.dePago(this.pago) : mantenimiento = null;

  _ItemHistorial.deMantenimiento(this.mantenimiento) : pago = null;

  /// 'YYYY-MM' para agrupar por mes ('' si no hay fecha).
  String get mesKey {
    final f = pago?.fechaPago ?? mantenimiento?.mes ?? '';
    return f.length >= 7 ? f.substring(0, 7) : '';
  }

  /// Clave para ordenar dentro del grupo (más reciente primero).
  String get ordenKey =>
      pago?.fechaPago ??
      (mantenimiento != null ? '${mantenimiento!.mes}-01' : '');

  double get monto => pago?.monto ?? mantenimiento!.monto;

  bool get pagado =>
      pago != null || mantenimiento!.estatus.toLowerCase() == 'pagado';
}

/// Pagos POR PROPIEDAD: primero se elige la propiedad (cards con
/// mini-resumen y buscador); luego saldo global + próximos pagos (vencidos en
/// rojo, badge "Parcial" y desglose de pagos aplicados) + historial de esa
/// propiedad con resumen, filtros (año/estatus/tipo), agrupación por mes,
/// cuotas de mantenimiento y recibo/CEP (con generación bajo demanda).
class PagosScreen extends ConsumerStatefulWidget {
  const PagosScreen({super.key});

  @override
  ConsumerState<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends ConsumerState<PagosScreen> {
  String? _propiedad; // numero de propiedad elegida (etiqueta de cliente-pagos)
  String _query = ''; // buscador de la lista de propiedades
  String _anio = 'todos'; // filtro de año del historial
  String _estatus = 'todos'; // todos | pagado | pendiente
  String _tipo = 'todos'; // todos | pagos | mantenimiento

  Color _colorEstatus(SozuTone tone, String estatus) {
    final e = estatus.toLowerCase();
    if (e.contains('pendiente') || e.contains('vencid')) return tone.pending;
    if (e.contains('liquidad') || e.contains('entregad')) return tone.positive;
    return tone.primaryDark;
  }

  void _seleccionar(String? numero) => setState(() {
    _propiedad = numero;
    _anio = 'todos';
    _estatus = 'todos';
    _tipo = 'todos';
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final pagos = ref.watch(clientePagosProvider);
    final props = ref.watch(clientePropiedadesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagos'),
        leading: _propiedad != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _seleccionar(null),
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => context.push('/estado-cuenta'),
            child: Text(
              'Estado de cuenta',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tone.primaryDark,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clientePagosProvider);
          try {
            await ref.read(clientePagosProvider.future);
          } catch (_) {}
        },
        child: pagos.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 18),
                    SizedBox(height: 8),
                    Skeleton(width: 200, height: 12),
                  ],
                ),
              ),
            ],
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorCard(
                title: 'No pudimos cargar tus pagos',
                onRetry: () => ref.invalidate(clientePagosProvider),
              ),
            ],
          ),
          data: (data) {
            // Propiedades presentes en pagos (para la lista de selección).
            final propiedades = <String>{
              for (final p in data.proximosPagos) p.propiedad,
              for (final h in data.historial) h.propiedad,
              for (final m in data.historialMantenimiento) m.propiedad,
            }..remove('—');

            // Una sola propiedad → directo al detalle.
            final seleccion =
                _propiedad ??
                (propiedades.length == 1 ? propiedades.first : null);

            if (seleccion == null) {
              return _listaPropiedades(
                tone,
                data,
                propiedades.toList()..sort(),
                props.valueOrNull,
              );
            }
            return _detalle(tone, data, seleccion);
          },
        ),
      ),
    );
  }

  Widget _listaPropiedades(
    SozuTone tone,
    ClientePagos data,
    List<String> propiedades,
    ClientePropiedades? props,
  ) {
    // Enriquecer con datos de la propiedad (estatus, avance, monto) si están.
    final cards = <PropiedadCard>[
      ...?props?.enAdquisicion,
      ...?props?.patrimonioActivo,
    ];
    PropiedadCard? cardDe(String numero) {
      for (final c in cards) {
        if (c.nombre == numero) return c;
      }
      return null;
    }

    // Buscador en vivo por proyecto + número de unidad.
    final q = _query.trim().toLowerCase();
    final filtradas = q.isEmpty
        ? propiedades
        : propiedades.where((numero) {
            final c = cardDe(numero);
            return numero.toLowerCase().contains(q) ||
                (c?.proyecto.toLowerCase().contains(q) ?? false);
          }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        AppCard(
          child: Row(
            children: [
              _saldoItem(tone, 'Total', data.saldoTotal, tone.textPrimary),
              _saldoItem(tone, 'Pagado', data.saldoPagado, tone.positive),
              _saldoItem(
                tone,
                'Pendiente',
                data.saldoPendiente,
                tone.pending,
                alignEnd: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Selecciona una propiedad',
          style: TextStyle(fontSize: 14, color: tone.textSecondary),
        ),
        const SizedBox(height: 12),
        if (propiedades.isEmpty)
          const EmptyCard(
            icon: Icons.receipt_outlined,
            text: 'Aún no hay pagos',
          )
        else ...[
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Buscar propiedad…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          if (filtradas.isEmpty)
            EmptyCard(
              icon: Icons.search_off_outlined,
              text: 'Sin resultados para "$_query".',
            )
          else
            for (final numero in filtradas) ...[
              _cardPropiedad(tone, numero, cardDe(numero), data),
              const SizedBox(height: 10),
            ],
        ],
      ],
    );
  }

  Widget _cardPropiedad(
    SozuTone tone,
    String numero,
    PropiedadCard? c,
    ClientePagos data,
  ) {
    final color = _colorEstatus(tone, c?.estatusDerivado ?? '');
    final pendientes = data.proximosPagos
        .where((p) => p.propiedad == numero)
        .length;
    final subtitulo = c != null
        ? '${c.estatusDerivado} · ${c.avancePago.round()}% pagado · ${formatMXN(c.monto)}'
        : '$pendientes pagos pendientes';
    return GestureDetector(
      onTap: () => _seleccionar(numero),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Text(
                numero,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c != null ? '${c.proyecto} · U$numero' : 'U$numero',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tone.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: tone.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: tone.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _detalle(SozuTone tone, ClientePagos data, String propiedad) {
    final proximos = data.proximosPagos
        .where((p) => p.propiedad == propiedad)
        .toList();
    final historial = data.historial
        .where((h) => h.propiedad == propiedad)
        .toList();
    final mantenimiento = data.historialMantenimiento
        .where((m) => m.propiedad == propiedad)
        .toList();

    // Historial unificado (pagos de inversión + cuotas de mantenimiento).
    final items = <_ItemHistorial>[
      for (final h in historial) _ItemHistorial.dePago(h),
      for (final m in mantenimiento) _ItemHistorial.deMantenimiento(m),
    ];

    final anios = <String>{
      for (final it in items)
        if (it.mesKey.length >= 4) it.mesKey.substring(0, 4),
    }.toList()..sort((a, b) => b.compareTo(a));

    final filtrados = items.where((it) {
      if (_anio != 'todos' && !it.mesKey.startsWith(_anio)) return false;
      if (_estatus == 'pagado' && !it.pagado) return false;
      if (_estatus == 'pendiente' && it.pagado) return false;
      if (_tipo == 'pagos' && it.pago == null) return false;
      if (_tipo == 'mantenimiento' && it.mantenimiento == null) return false;
      return true;
    }).toList();

    // Agrupación por mes (más reciente primero; sin fecha al final).
    final grupos = <String, List<_ItemHistorial>>{};
    for (final it in filtrados) {
      grupos.putIfAbsent(it.mesKey, () => []).add(it);
    }
    final claves = grupos.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty) return 1;
        if (b.isEmpty) return -1;
        return b.compareTo(a);
      });
    for (final g in grupos.values) {
      g.sort((a, b) => b.ordenKey.compareTo(a.ordenKey));
    }

    // Método de pago final elegido (badge informativo, espejo del portal):
    // lee el detalle ya cacheado con valueOrNull — sin loading propio; si aún
    // no hay datos (o el backend no lo expone) simplemente no se muestra.
    final cards = ref.watch(clientePropiedadesProvider).valueOrNull;
    final cuentaId = [
      ...?cards?.enAdquisicion,
      ...?cards?.patrimonioActivo,
    ].where((c) => c.nombre == propiedad).firstOrNull?.id;
    final det = cuentaId == null
        ? null
        : ref.watch(propiedadDetalleProvider(cuentaId)).valueOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Text(
          'U$propiedad',
          style: TextStyle(fontSize: 13, color: tone.textMuted),
        ),
        if (det?.tipoFinanciamiento != null) ...[
          const SizedBox(height: 12),
          PaymentMethodBadge(
            tipoFinanciamiento: det!.tipoFinanciamiento,
            solicitud: det.solicitudCredito,
          ),
        ],
        const SectionTitle(
          icon: Icons.schedule_outlined,
          text: 'Próximos pagos',
        ),
        if (proximos.isEmpty)
          const EmptyCard(
            icon: Icons.task_alt_outlined,
            text: 'Sin pagos pendientes',
          )
        else
          for (final p in proximos) ...[
            _ProximoRow(p: p, onPagar: () => context.push('/pagar?id=${p.id}')),
            const SizedBox(height: 12),
          ],
        const SectionTitle(icon: Icons.receipt_long_outlined, text: 'Historial'),
        if (items.isEmpty)
          const EmptyCard(
            icon: Icons.receipt_outlined,
            text: 'Aún no hay pagos registrados',
          )
        else ...[
          _resumenHistorial(tone, items),
          const SizedBox(height: 12),
          _filtrosHistorial(tone, anios, mantenimiento.isNotEmpty),
          const SizedBox(height: 8),
          if (filtrados.isEmpty)
            const EmptyCard(
              icon: Icons.filter_alt_off_outlined,
              text: 'Sin pagos para este filtro',
            )
          else
            for (final k in claves) ...[
              _mesHeader(tone, k, grupos[k]!),
              for (final it in grupos[k]!) ...[
                if (it.pago != null)
                  _HistorialRow(h: it.pago!)
                else
                  _MantenimientoRow(m: it.mantenimiento!),
                const SizedBox(height: 12),
              ],
            ],
        ],
      ],
    );
  }

  /// Resumen de la propiedad: total pagado, # pagos y último pago.
  Widget _resumenHistorial(SozuTone tone, List<_ItemHistorial> items) {
    final pagados = items.where((it) => it.pagado).toList()
      ..sort((a, b) => b.ordenKey.compareTo(a.ordenKey));
    final total = pagados.fold<double>(0, (s, it) => s + it.monto);
    final ultimo = pagados.isEmpty
        ? '—'
        : (pagados.first.pago != null
              ? formatDate(pagados.first.pago!.fechaPago)
              : _mesLabel(pagados.first.mesKey));
    return AppCard(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _kpi(tone, 'Total pagado', formatMXN(total), tone.positive),
          _kpi(tone, 'Pagos realizados', '${pagados.length}', tone.textPrimary),
          _kpi(tone, 'Último pago', ultimo, tone.textPrimary),
        ],
      ),
    );
  }

  Widget _kpi(SozuTone tone, String label, String value, Color color) {
    return SizedBox(
      width: 110,
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
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtrosHistorial(
    SozuTone tone,
    List<String> anios,
    bool conMantenimiento,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (anios.isNotEmpty) ...[
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
          const SizedBox(height: 8),
        ],
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
        if (conMantenimiento) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                tone,
                'Tipo: Todos',
                _tipo == 'todos',
                () => setState(() => _tipo = 'todos'),
              ),
              _chip(
                tone,
                'Pagos',
                _tipo == 'pagos',
                () => setState(() => _tipo = 'pagos'),
              ),
              _chip(
                tone,
                'Mantenimiento',
                _tipo == 'mantenimiento',
                () => setState(() => _tipo = 'mantenimiento'),
              ),
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

  /// Encabezado de grupo mensual: "Mes Año" + subtotal pagado del mes.
  Widget _mesHeader(SozuTone tone, String key, List<_ItemHistorial> items) {
    final subtotal = items.fold<double>(
      0,
      (s, it) => s + (it.pagado ? it.monto : 0),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              key.isEmpty ? 'Sin fecha' : _mesLabel(key),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tone.textSecondary,
              ),
            ),
          ),
          Text(
            formatMXN(subtotal),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tone.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _saldoItem(
    SozuTone tone,
    String label,
    double value,
    Color color, {
    bool alignEnd = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: tone.textMuted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatMXN(value),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProximoRow extends ConsumerStatefulWidget {
  final ProximoPago p;
  final VoidCallback onPagar;

  const _ProximoRow({required this.p, required this.onPagar});

  @override
  ConsumerState<_ProximoRow> createState() => _ProximoRowState();
}

class _ProximoRowState extends ConsumerState<_ProximoRow> {
  bool _expandido = false;
  int? _generando; // idPago de la aplicación cuyo recibo se está generando

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Recibo de una aplicación: abre el existente o lo genera bajo demanda.
  Future<void> _abrirRecibo(AplicacionPago a) async {
    if ((a.urlRecibo ?? '').isNotEmpty) {
      await openMedia(context, a.urlRecibo, titulo: 'Recibo');
      return;
    }
    if (_generando != null) return;
    setState(() => _generando = a.idPago);
    try {
      final imp = ref.read(impersonationProvider).idPersona;
      final url = await fetchReciboPagoUrl(a.idPago, impersonate: imp);
      if (!mounted) return;
      if (url == null) {
        _snack('No pudimos generar el recibo. Intenta de nuevo.');
      } else {
        await openMedia(context, url, titulo: 'Recibo');
      }
    } catch (_) {
      if (mounted) _snack('No pudimos generar el recibo. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _generando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final p = widget.p;
    final parcial = p.pagado > 0 && p.pagado < p.monto;
    return AppCard(
      borderColor: p.vencido ? tone.negative.withValues(alpha: 0.4) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.concepto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tone.textPrimary,
                      ),
                    ),
                    Text(
                      '${p.propiedad} · vence ${formatDate(p.fechaPago)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tone.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        p.vencido
                            ? const StatusBadge(
                                label: 'Vencido',
                                tone: BadgeTone.negative,
                              )
                            : const StatusBadge(
                                label: 'Pendiente',
                                tone: BadgeTone.pending,
                              ),
                        if (parcial)
                          const StatusBadge(
                            label: 'Parcial',
                            tone: BadgeTone.pending,
                          ),
                      ],
                    ),
                    if (parcial) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Faltan ${formatMXN(p.monto - p.pagado)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: SozuColors.amber600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMXN(p.monto),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tone.textPrimary,
                    ),
                  ),
                  if (parcial) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Pagado ${formatMXN(p.pagado)}',
                      style: TextStyle(fontSize: 11, color: tone.positive),
                    ),
                  ],
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: widget.onPagar,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: SozuColors.emerald500,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Pagar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (p.aplicaciones.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: tone.border, height: 1),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _expandido = !_expandido),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    size: 14,
                    color: SozuColors.emerald600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${p.aplicaciones.length} '
                      '${p.aplicaciones.length == 1 ? 'pago aplicado' : 'pagos aplicados'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tone.primaryDark,
                      ),
                    ),
                  ),
                  Icon(
                    _expandido ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: tone.textMuted,
                  ),
                ],
              ),
            ),
            if (_expandido) ...[
              const SizedBox(height: 10),
              for (final a in p.aplicaciones) _appRow(tone, a),
            ],
          ],
        ],
      ),
    );
  }

  /// Sub-fila de un pago aplicado: método · monto · fecha + Recibo/CEP.
  Widget _appRow(SozuTone tone, AplicacionPago a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: SozuColors.emerald500.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${a.metodo ?? 'Pago'} · ${formatMXN(a.monto)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tone.textPrimary,
            ),
          ),
          Text(
            '${formatDate(a.fecha)}'
            '${(a.claveRastreo ?? '').isNotEmpty ? ' · Clave ${a.claveRastreo}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: tone.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DocChip(
                icon: Icons.description_outlined,
                label: 'Recibo',
                loading: _generando == a.idPago,
                onTap: () => _abrirRecibo(a),
              ),
              if ((a.urlCep ?? '').isNotEmpty)
                _DocChip(
                  icon: Icons.verified_user_outlined,
                  label: 'CEP',
                  onTap: () => openMedia(context, a.urlCep, titulo: 'CEP'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistorialRow extends ConsumerStatefulWidget {
  final HistorialPago h;

  const _HistorialRow({required this.h});

  @override
  ConsumerState<_HistorialRow> createState() => _HistorialRowState();
}

class _HistorialRowState extends ConsumerState<_HistorialRow> {
  bool _generando = false;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Abre el recibo firmado; si aún no existe, lo genera bajo demanda.
  Future<void> _abrirRecibo() async {
    final h = widget.h;
    if ((h.urlRecibo ?? '').isNotEmpty) {
      await openMedia(context, h.urlRecibo, titulo: 'Recibo');
      return;
    }
    if (_generando) return;
    setState(() => _generando = true);
    try {
      final imp = ref.read(impersonationProvider).idPersona;
      final url = await fetchReciboPagoUrl(h.id, impersonate: imp);
      if (!mounted) return;
      if (url == null) {
        _snack('No pudimos generar el recibo. Intenta de nuevo.');
      } else {
        await openMedia(context, url, titulo: 'Recibo');
      }
    } catch (_) {
      if (mounted) _snack('No pudimos generar el recibo. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final h = widget.h;
    return GestureDetector(
      onTap: () => showReciboPagoSheet(context, pago: h),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.concepto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tone.textPrimary,
                        ),
                      ),
                      Text(
                        '${h.propiedad} · ${formatDate(h.fechaPago)} · ${h.metodo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: tone.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMXN(h.monto),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tone.positive,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: tone.border, height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DocChip(
                  icon: Icons.description_outlined,
                  label: 'Recibo',
                  loading: _generando,
                  onTap: _abrirRecibo,
                ),
                if ((h.urlCep ?? '').isNotEmpty)
                  _DocChip(
                    icon: Icons.verified_user_outlined,
                    label: 'CEP',
                    onTap: () => openMedia(context, h.urlCep, titulo: 'CEP'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuota de mantenimiento en el historial (mes, monto y estatus).
class _MantenimientoRow extends StatelessWidget {
  final MantenimientoPago m;

  const _MantenimientoRow({required this.m});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final e = m.estatus.toLowerCase();
    final (label, badgeTone) = e == 'pagado'
        ? ('Pagado', BadgeTone.positive)
        : e == 'vencido'
        ? ('Vencido', BadgeTone.negative)
        : ('Pendiente', BadgeTone.pending);
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mantenimiento',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tone.textPrimary,
                  ),
                ),
                Text(
                  '${m.propiedad} · ${_mesLabel(m.mes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: tone.textSecondary),
                ),
                const SizedBox(height: 6),
                StatusBadge(label: label, tone: badgeTone),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMXN(m.monto),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: e == 'pagado' ? tone.positive : tone.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de documento (Recibo/CEP) con estado de carga opcional.
class _DocChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;

  const _DocChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: tone.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SozuColors.emerald600,
                ),
              )
            else
              Icon(icon, size: 14, color: SozuColors.emerald600),
            const SizedBox(width: 6),
            Text(
              loading ? 'Generando…' : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tone.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
