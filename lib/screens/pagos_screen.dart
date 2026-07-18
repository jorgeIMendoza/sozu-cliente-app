import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/open_media.dart';
import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../providers/impersonation_provider.dart';
import '../widgets/common.dart';
import '../widgets/payment_method_badge.dart';
import '../widgets/portal_widgets.dart';
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

  // — Solo modo portal (web ≥1024): la vista móvil usa estados por fila —
  int? _generandoPortal; // id del pago cuyo recibo se genera en la tabla
  final Set<int> _proximosExpandidos = {}; // próximos con desglose abierto

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
    final portal = isPortalMode(context);
    final pagos = ref.watch(clientePagosProvider);
    final props = ref.watch(clientePropiedadesProvider);

    return Scaffold(
      // Modo portal: el shell (sidebar + topbar) ya pinta el título de
      // sección; la pantalla NO muestra su AppBar propio.
      backgroundColor: portal ? Colors.transparent : null,
      appBar: portal
          ? null
          : AppBar(
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
              if (portal) {
                return _portalLista(
                  data,
                  propiedades.toList()..sort(),
                  props.valueOrNull,
                );
              }
              return _listaPropiedades(
                tone,
                data,
                propiedades.toList()..sort(),
                props.valueOrNull,
              );
            }
            if (portal) {
              return _portalDetalle(data, seleccion, propiedades.length > 1);
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

  // ═══════════════════════════════════════════════════════════════════════════
  // MODO PORTAL (web ≥1024): réplica del "Historial de pagos" del Portal del
  // Cliente (ClienteHistorialPagos.tsx + PaymentHistoryView.tsx de sozu-admin).
  // Solo capa visual: mismos providers, filtros y acciones que la vista móvil.
  // ═══════════════════════════════════════════════════════════════════════════

  // Anchos fijos de columnas de la tabla (CONCEPTO es flexible).
  static const double _wFecha = 112;
  static const double _wTipo = 130;
  static const double _wMonto = 150;
  static const double _wEstatus = 118;
  static const double _wComp = 96;

  /// Fondo de thead (`bg-muted/10` aplanado, tokens.md §1.1).
  static const Color _theadBg = Color(0xFFFDFEFE);

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Card de la propiedad (estatus/avance/monto) si cliente-propiedades ya
  /// está en caché; no dispara fetching nuevo.
  PropiedadCard? _cardDe(String numero) {
    final props = ref.watch(clientePropiedadesProvider).valueOrNull;
    for (final c in [
      ...?props?.enAdquisicion,
      ...?props?.patrimonioActivo,
    ]) {
      if (c.nombre == numero) return c;
    }
    return null;
  }

  /// Recibo de un pago del historial: abre el firmado o lo genera bajo demanda
  /// (misma acción que _HistorialRow de la vista móvil).
  Future<void> _portalAbrirReciboHistorial(HistorialPago h) async {
    if ((h.urlRecibo ?? '').isNotEmpty) {
      await openMedia(context, h.urlRecibo, titulo: 'Recibo');
      return;
    }
    if (_generandoPortal != null) return;
    setState(() => _generandoPortal = h.id);
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
      if (mounted) setState(() => _generandoPortal = null);
    }
  }

  /// Recibo de un pago aplicado a un próximo pago (misma acción que la fila
  /// expandible de _ProximoRow en móvil).
  Future<void> _portalAbrirReciboAplicacion(AplicacionPago a) async {
    if ((a.urlRecibo ?? '').isNotEmpty) {
      await openMedia(context, a.urlRecibo, titulo: 'Recibo');
      return;
    }
    if (_generandoPortal != null) return;
    setState(() => _generandoPortal = a.idPago);
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
      if (mounted) setState(() => _generandoPortal = null);
    }
  }

  // ── Selector de propiedad (ClienteHistorialPagos §lista) ──────────────────
  Widget _portalLista(
    ClientePagos data,
    List<String> propiedades,
    ClientePropiedades? props,
  ) {
    final q = _query.trim().toLowerCase();
    final filtradas = q.isEmpty
        ? propiedades
        : propiedades.where((numero) {
            final c = _cardDe(numero);
            return numero.toLowerCase().contains(q) ||
                (c?.proyecto.toLowerCase().contains(q) ?? false);
          }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pagos',
            style: portalText(
              size: 26,
              weight: FontWeight.w700,
              letterSpacing: -0.65,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Selecciona una propiedad.',
            style: portalText(size: 13, color: PortalColors.mutedForeground),
          ),
          const SizedBox(height: 16),
          if (propiedades.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aún no hay pagos',
                  style: portalText(
                    size: 14,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ),
            )
          else ...[
            PortalSearchField(
              hint: 'Buscar propiedad…',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
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
              for (final numero in filtradas) ...[
                _portalCardPropiedad(numero, _cardDe(numero), data),
                const SizedBox(height: 8),
              ],
          ],
        ],
      ),
    );
  }

  Widget _portalCardPropiedad(
    String numero,
    PropiedadCard? c,
    ClientePagos data,
  ) {
    final (bg, fg) = portalEstatusStyle(c?.estatusDerivado ?? '');
    final pendientes = data.proximosPagos
        .where((p) => p.propiedad == numero)
        .length;
    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: () => _seleccionar(numero),
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
                  color: bg,
                  borderRadius: BorderRadius.circular(kPortalRadiusLg),
                ),
                child: Text(
                  numero,
                  style: portalText(
                    size: 14,
                    weight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: c?.proyecto ?? 'Propiedad',
                            style: portalText(
                              size: 14,
                              weight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: ' · U$numero',
                            style: portalText(
                              size: 14,
                              color: PortalColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (c != null) ...[
                            TextSpan(
                              text: c.estatusDerivado,
                              style: portalText(
                                size: 11,
                                weight: FontWeight.w500,
                                color: fg,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' • ${c.avancePago.round()}% pagado · ${formatMXN(c.monto)}',
                              style: portalText(
                                size: 11,
                                color: PortalColors.mutedForeground,
                              ),
                            ),
                          ] else
                            TextSpan(
                              text:
                                  '$pendientes ${pendientes == 1 ? 'pago pendiente' : 'pagos pendientes'}',
                              style: portalText(
                                size: 11,
                                color: PortalColors.mutedForeground,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: PortalColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Detalle: header + grid 1fr/300 (PaymentHistoryView §desktop) ──────────
  Widget _portalDetalle(ClientePagos data, String propiedad, bool multi) {
    final proximos = data.proximosPagos
        .where((p) => p.propiedad == propiedad)
        .toList();
    final historial = data.historial
        .where((h) => h.propiedad == propiedad)
        .toList();
    final mantenimiento = data.historialMantenimiento
        .where((m) => m.propiedad == propiedad)
        .toList();

    final items = <_ItemHistorial>[
      for (final h in historial) _ItemHistorial.dePago(h),
      for (final m in mantenimiento) _ItemHistorial.deMantenimiento(m),
    ];

    final anios = <String>{
      for (final it in items)
        if (it.mesKey.length >= 4) it.mesKey.substring(0, 4),
    }.toList()..sort((a, b) => b.compareTo(a));

    // Mismos filtros que la vista móvil; tabla plana más reciente primero.
    final filtrados = items.where((it) {
      if (_anio != 'todos' && !it.mesKey.startsWith(_anio)) return false;
      if (_estatus == 'pagado' && !it.pagado) return false;
      if (_estatus == 'pendiente' && it.pagado) return false;
      if (_tipo == 'pagos' && it.pago == null) return false;
      if (_tipo == 'mantenimiento' && it.mantenimiento == null) return false;
      return true;
    }).toList()..sort((a, b) => b.ordenKey.compareTo(a.ordenKey));

    final card = _cardDe(propiedad);
    final det = card == null
        ? null
        : ref.watch(propiedadDetalleProvider(card.id)).valueOrNull;
    final conMantenimiento = mantenimiento.isNotEmpty;

    final izquierda = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (proximos.isNotEmpty) ...[
          _portalProximos(proximos),
          const SizedBox(height: 16),
        ],
        _portalFiltros(anios, conMantenimiento),
        const SizedBox(height: 16),
        _portalTabla(items, filtrados, conMantenimiento),
      ],
    );
    final derecha = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (det?.tipoFinanciamiento != null) ...[
          PaymentMethodBadge(
            tipoFinanciamiento: det!.tipoFinanciamiento,
            solicitud: det.solicitudCredito,
            portal: true,
          ),
          const SizedBox(height: 16),
        ],
        _portalResumen(card, propiedad, items),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pagos',
                      style: portalText(
                        size: 26,
                        weight: FontWeight.w700,
                        letterSpacing: -0.65,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card != null
                          ? '${card.proyecto} - U-$propiedad'
                          : 'U$propiedad',
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
              if (multi)
                PortalOutlineButton(
                  label: 'Cambiar propiedad',
                  icon: Icons.swap_horiz,
                  onPressed: () => _seleccionar(null),
                ),
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
    );
  }

  // ── Card "Próximos pagos" ─────────────────────────────────────────────────
  Widget _portalProximos(List<ProximoPago> proximos) {
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
                    'Próximos pagos',
                    style: portalText(size: 14, weight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${proximos.length} pendiente${proximos.length == 1 ? '' : 's'}',
                  style: portalText(
                    size: 11,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < proximos.length; i++)
            _portalProximoRow(proximos[i], last: i == proximos.length - 1),
        ],
      ),
    );
  }

  Widget _portalProximoRow(ProximoPago p, {required bool last}) {
    final parcial = p.pagado > 0 && p.pagado < p.monto;
    final expandido = _proximosExpandidos.contains(p.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: PortalColors.border)),
      ),
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
                      p.concepto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: portalText(size: 13, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vence ${portalShortDate(p.fechaPago)}',
                      style: portalText(
                        size: 11,
                        color: PortalColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        p.vencido
                            ? const PortalStatusChip(
                                label: 'Vencido',
                                icon: Icons.error_outline,
                                background: PortalColors.destructiveSoft10,
                                foreground: PortalColors.destructive,
                              )
                            : const PortalStatusChip(
                                label: 'Pendiente',
                                icon: Icons.schedule,
                                background: PortalColors.warningSoft10,
                                foreground: PortalColors.warning,
                              ),
                        if (parcial)
                          const PortalStatusChip(
                            label: 'Parcial',
                            background: PortalColors.warningSoft10,
                            foreground: PortalColors.warning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMXN(p.monto),
                    style: portalText(
                      size: 14,
                      weight: FontWeight.w700,
                      tabular: true,
                    ),
                  ),
                  if (parcial) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Pagado ${formatMXN(p.pagado)}',
                      style: portalText(
                        size: 10,
                        color: PortalColors.primary,
                        tabular: true,
                      ),
                    ),
                    Text(
                      'Faltan ${formatMXN(p.monto - p.pagado)}',
                      style: portalText(
                        size: 10,
                        weight: FontWeight.w500,
                        color: PortalColors.warning,
                        tabular: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  PortalPrimaryButton(
                    label: 'Pagar',
                    icon: Icons.credit_card_outlined,
                    onPressed: () => context.push('/pagar?id=${p.id}'),
                  ),
                ],
              ),
            ],
          ),
          if (p.aplicaciones.isNotEmpty) ...[
            const SizedBox(height: 10),
            PortalHoverBuilder(
              builder: (context, hovered) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  if (!_proximosExpandidos.remove(p.id)) {
                    _proximosExpandidos.add(p.id);
                  }
                }),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.layers_outlined,
                      size: 12,
                      color: PortalColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${p.aplicaciones.length} '
                      '${p.aplicaciones.length == 1 ? 'pago aplicado' : 'pagos aplicados'}',
                      style: portalText(
                        size: 11,
                        weight: FontWeight.w600,
                        color: PortalColors.primary,
                      ),
                    ),
                    Icon(
                      expandido ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: PortalColors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
            if (expandido) ...[
              const SizedBox(height: 4),
              for (final a in p.aplicaciones) _portalAppRow(a),
            ],
          ],
        ],
      ),
    );
  }

  /// Sub-fila de pago aplicado (AppRow del portal): regla verde + método/monto
  /// + fecha/clave + acciones Recibo y CEP existentes.
  Widget _portalAppRow(AplicacionPago a) {
    final clave = (a.claveRastreo ?? '').trim();
    final cep = (a.urlCep ?? '').trim();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: PortalColors.primary.withValues(alpha: .2),
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${a.metodo ?? 'Pago'} · ${formatMXN(a.monto)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: portalText(
                    size: 11,
                    weight: FontWeight.w500,
                    tabular: true,
                  ),
                ),
                Text(
                  '${portalShortDate(a.fecha)}${clave.isNotEmpty ? ' · Clave $clave' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: portalText(
                    size: 10,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          PortalIconBtn(
            icon: Icons.description_outlined,
            tooltip: 'Ver recibo',
            loading: _generandoPortal == a.idPago,
            onTap: () => _portalAbrirReciboAplicacion(a),
          ),
          PortalIconBtn(
            icon: Icons.receipt_long_outlined,
            tooltip: cep.isNotEmpty ? 'CEP electrónico' : 'Sin comprobante',
            onTap: cep.isNotEmpty
                ? () => openMedia(context, cep, titulo: 'CEP')
                : null,
          ),
        ],
      ),
    );
  }

  // ── Card de filtros (filterBar del portal) ────────────────────────────────
  Widget _portalFiltros(List<String> anios, bool conMantenimiento) {
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

    Widget separada(Widget child) => Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PortalColors.border)),
      ),
      child: child,
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
          separada(
            fila('Estatus', [
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
          if (conMantenimiento)
            separada(
              fila('Tipo', [
                PortalPill(
                  label: 'Todos',
                  active: _tipo == 'todos',
                  onTap: () => setState(() => _tipo = 'todos'),
                ),
                PortalPill(
                  label: 'Inversión',
                  active: _tipo == 'pagos',
                  onTap: () => setState(() => _tipo = 'pagos'),
                ),
                PortalPill(
                  label: 'Mantenimiento',
                  active: _tipo == 'mantenimiento',
                  onTap: () => setState(() => _tipo = 'mantenimiento'),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  // ── Card "Pagos registrados" con tabla (desktopPaymentsTable) ─────────────
  Widget _portalTabla(
    List<_ItemHistorial> todos,
    List<_ItemHistorial> items,
    bool conMantenimiento,
  ) {
    final minTabla = conMantenimiento ? 760.0 : 660.0;
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
                    'Pagos registrados',
                    style: portalText(size: 14, weight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${items.length} registro${items.length == 1 ? '' : 's'}',
                  style: portalText(
                    size: 11,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (todos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Aún no hay pagos registrados',
                  style: portalText(
                    size: 14,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Sin pagos con ese filtro',
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
                final w = cons.maxWidth < minTabla ? minTabla : cons.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _portalTablaHeader(conMantenimiento),
                        for (var i = 0; i < items.length; i++)
                          _portalTablaFila(
                            items[i],
                            conMantenimiento,
                            last: i == items.length - 1,
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

  Widget _portalTablaHeader(bool conMantenimiento) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: _theadBg,
        border: Border(bottom: BorderSide(color: PortalColors.border)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: _wFecha,
            child: Padding(
              padding: EdgeInsets.only(left: 20, right: 12),
              child: PortalSectionLabel('Fecha'),
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: PortalSectionLabel('Concepto'),
            ),
          ),
          if (conMantenimiento)
            const SizedBox(
              width: _wTipo,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: PortalSectionLabel('Tipo'),
              ),
            ),
          const SizedBox(
            width: _wMonto,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: PortalSectionLabel('Monto'),
              ),
            ),
          ),
          const SizedBox(
            width: _wEstatus,
            child: Center(child: PortalSectionLabel('Estatus')),
          ),
          const SizedBox(
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

  Widget _portalTablaFila(
    _ItemHistorial it,
    bool conMantenimiento, {
    required bool last,
  }) {
    final pago = it.pago;
    final mant = it.mantenimiento;

    // FECHA + CONCEPTO.
    final fecha = pago != null
        ? portalShortDate(pago.fechaPago)
        : _mesLabel(mant!.mes);
    final concepto = pago?.concepto ?? 'Mantenimiento';
    final sub = pago?.metodo;

    // ESTATUS con icono (Pagado verde / Pendiente ámbar / Vencido rojo).
    final vencido = (mant?.estatus.toLowerCase() ?? '') == 'vencido';
    final chip = it.pagado
        ? const PortalStatusChip(
            label: 'Pagado',
            icon: Icons.check_circle_outlined,
            background: PortalColors.primarySoft10,
            foreground: PortalColors.primary,
          )
        : PortalStatusChip(
            label: vencido ? 'Vencido' : 'Pendiente',
            icon: vencido ? Icons.error_outline : Icons.schedule,
            background: vencido
                ? PortalColors.destructiveSoft10
                : PortalColors.warningSoft10,
            foreground: vencido
                ? PortalColors.destructive
                : PortalColors.warning,
          );

    // COMPROBANTE: recibo (existente o bajo demanda) + CEP; mantenimiento no
    // tiene documentos.
    final Widget acciones = pago != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PortalIconBtn(
                icon: Icons.description_outlined,
                tooltip: 'Ver recibo',
                loading: _generandoPortal == pago.id,
                onTap: () => _portalAbrirReciboHistorial(pago),
              ),
              PortalIconBtn(
                icon: Icons.receipt_long_outlined,
                tooltip: (pago.urlCep ?? '').isNotEmpty
                    ? 'CEP electrónico'
                    : 'Sin comprobante',
                onTap: (pago.urlCep ?? '').isNotEmpty
                    ? () => openMedia(context, pago.urlCep, titulo: 'CEP')
                    : null,
              ),
            ],
          )
        : Text(
            '—',
            style: portalText(
              size: 11,
              color: PortalColors.mutedForeground.withValues(alpha: .4),
            ),
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
                  fecha,
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
                      concepto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: portalText(size: 13, weight: FontWeight.w500),
                    ),
                    if ((sub ?? '').isNotEmpty && sub != '—')
                      Text(
                        sub!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: portalText(
                          size: 10,
                          color: PortalColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (conMantenimiento)
              SizedBox(
                width: _wTipo,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PortalStatusChip(
                      small: true,
                      label: pago != null ? 'Inversión' : 'Mantenimiento',
                      background: pago != null
                          ? PortalColors.primarySoft10
                          : PortalColors.muted,
                      foreground: pago != null
                          ? PortalColors.primary
                          : PortalColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: _wMonto,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatMXN(it.monto),
                    style: portalText(
                      size: 13,
                      weight: FontWeight.w600,
                      tabular: true,
                    ),
                  ),
                ),
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
                child: Center(child: acciones),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card resumen (summaryBlock del portal) ────────────────────────────────
  Widget _portalResumen(
    PropiedadCard? card,
    String propiedad,
    List<_ItemHistorial> items,
  ) {
    final now = DateTime.now();
    final periodo = '${_kMeses[now.month - 1]} ${now.year}';

    final pagados = items.where((it) => it.pagado).toList()
      ..sort((a, b) => b.ordenKey.compareTo(a.ordenKey));
    final total = pagados.fold<double>(0, (s, it) => s + it.monto);
    final ultimo = pagados.isEmpty
        ? '—'
        : (pagados.first.pago != null
              ? portalShortDate(pagados.first.pago!.fechaPago)
              : _mesLabel(pagados.first.mesKey));

    Widget sep() => Container(
      height: 1,
      margin: const EdgeInsets.only(top: 16, bottom: 12),
      color: PortalColors.border,
    );

    Widget finRow(String label, String value, {Color? color}) => Row(
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
            weight: FontWeight.w600,
            color: color ?? PortalColors.foreground,
            tabular: true,
          ),
        ),
      ],
    );

    final (chipBg, chipFg) = portalEstatusStyle(card?.estatusDerivado ?? '');

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
                  'Historial de Pagos',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: portalText(size: 12, weight: FontWeight.w600),
                ),
              ),
              if (card != null) ...[
                const SizedBox(width: 8),
                PortalStatusChip(
                  small: true,
                  label: card.estatusDerivado,
                  background: chipBg,
                  foreground: chipFg,
                ),
              ],
            ],
          ),
          sep(),
          PortalInfoRow(
            label: 'Propiedad',
            value: card != null
                ? '${card.proyecto} · U-$propiedad'
                : 'U$propiedad',
          ),
          const SizedBox(height: 4),
          PortalInfoRow(label: 'Periodo', value: periodo),
          sep(),
          finRow(
            'Total Pagado',
            formatMXN(total),
            color: PortalColors.primary,
          ),
          const SizedBox(height: 10),
          finRow('Pagos realizados', '${pagados.length}'),
          const SizedBox(height: 10),
          finRow('Último pago', ultimo),
          if (card != null) ...[
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
                  '${card.avancePago.round()}%',
                  style: portalText(
                    size: 11,
                    weight: FontWeight.w600,
                    tabular: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            PortalProgressBar(percent: card.avancePago, height: 8),
          ],
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
