import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/open_media.dart';
import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'common.dart';
import 'portal_widgets.dart';

/// Cronograma de pagos del detalle de propiedad (espejo de PaymentSchedule en
/// src/components/admin/portal-cliente/investor/PropertyAcquisitionDetail.tsx
/// del portal del cliente):
/// - Tarjeta colapsable con título "CRONOGRAMA DE PAGOS" y contador
///   "N/M pagados".
/// - Tabla CONCEPTO | MONTO | ESTATUS (en angosto el monto va bajo el
///   concepto para no desbordar).
/// - Filas expandibles: "N PAGOS APLICADOS A `<CONCEPTO>`" con método, monto,
///   fecha, clave de rastreo y botón para ver el CEP/comprobante de cada pago
///   (mismo visor in-app que el resto de la app).
class CronogramaPagos extends StatefulWidget {
  final List<EsquemaPagoItem> esquemaPago;

  /// true en modo portal web (≥1024): solo cambia el contenedor exterior a
  /// PortalCard (radio 24, sin sombra) y el label del título al estilo
  /// portal; el contenido y la vista móvil quedan idénticos.
  final bool portal;

  const CronogramaPagos({
    super.key,
    required this.esquemaPago,
    this.portal = false,
  });

  @override
  State<CronogramaPagos> createState() => _CronogramaPagosState();
}

/// Estatus visual de una fila (misma lógica del portal: pagado por
/// pago_completado, parcial si hay abonos, pendiente en otro caso).
enum _EstadoFila { pagado, parcial, pendiente }

/// Filas visibles antes del "Ver N más" (LIMIT 5 del portal).
const _limiteFilas = 5;

/// Ancho mínimo para el layout de tabla con columnas.
const _anchoTabla = 520.0;

class _CronogramaPagosState extends State<CronogramaPagos> {
  bool _seccionAbierta = true;
  bool _verTodos = false;
  final Set<int> _filasAbiertas = {};

  _EstadoFila _estado(EsquemaPagoItem e) {
    if (e.pagoCompletado) return _EstadoFila.pagado;
    if (e.pagado > 0.01) return _EstadoFila.parcial;
    return _EstadoFila.pendiente;
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);

    // Mismo orden del portal: fecha descendente (lo más reciente arriba).
    final filas = [...widget.esquemaPago]
      ..sort((a, b) => (b.fechaPago ?? '').compareTo(a.fechaPago ?? ''));
    final pagados = filas.where((e) => e.pagoCompletado).length;
    final visibles = _verTodos ? filas : filas.take(_limiteFilas).toList();

    final contenido = LayoutBuilder(
          builder: (context, constraints) {
            final ancha = constraints.maxWidth >= _anchoTabla;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _encabezado(tone, filas.length, pagados),
                if (_seccionAbierta) ...[
                  const SizedBox(height: 12),
                  if (filas.isEmpty)
                    _vacio(tone)
                  else ...[
                    if (ancha) _encabezadoTabla(tone),
                    for (final e in visibles) _fila(tone, e, ancha),
                    if (filas.length > _limiteFilas)
                      Center(
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _verTodos = !_verTodos),
                          icon: Icon(
                            _verTodos
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                            color: tone.primaryDark,
                          ),
                          label: Text(
                            _verTodos
                                ? 'Mostrar menos'
                                : 'Ver ${filas.length - _limiteFilas} más',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: tone.primaryDark,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            );
          },
        );

    if (widget.portal) {
      return PortalCard(
        padding: const EdgeInsets.all(20),
        child: contenido,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: AppCard(child: contenido),
    );
  }

  /// Encabezado de la tarjeta: título + contador "N/M pagados" + chevron.
  /// Tocarlo colapsa/expande toda la sección.
  Widget _encabezado(SozuTone tone, int total, int pagados) {
    return InkWell(
      onTap: () => setState(() => _seccionAbierta = !_seccionAbierta),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 16,
                color: widget.portal
                    ? PortalColors.mutedForeground
                    : SozuColors.emerald600),
            const SizedBox(width: 8),
            Expanded(
              child: widget.portal
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: PortalSectionLabel('Cronograma de pagos'),
                    )
                  : Text(
                      'CRONOGRAMA DE PAGOS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: tone.textSecondary,
                      ),
                    ),
            ),
            if (total > 0) ...[
              Text(
                '$pagados/$total pagados',
                style: TextStyle(fontSize: 12, color: tone.textMuted),
              ),
              const SizedBox(width: 4),
            ],
            AnimatedRotation(
              turns: _seccionAbierta ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more, size: 20, color: tone.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vacio(SozuTone tone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 32, color: tone.textMuted),
            const SizedBox(height: 8),
            Text(
              'Sin plan de pagos',
              style: TextStyle(fontSize: 14, color: tone.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  /// Fila de encabezado de la tabla (solo layout ancho).
  Widget _encabezadoTabla(SozuTone tone) {
    final estilo = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: tone.textMuted,
    );
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tone.border)),
      ),
      child: Row(
        children: [
          Expanded(child: Text('CONCEPTO', style: estilo)),
          SizedBox(
            width: 150,
            child: Text('MONTO', textAlign: TextAlign.right, style: estilo),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: Text('ESTATUS', textAlign: TextAlign.right, style: estilo),
          ),
          const SizedBox(width: 28),
        ],
      ),
    );
  }

  /// Fila de un concepto del plan; expandible cuando tiene pagos aplicados.
  Widget _fila(SozuTone tone, EsquemaPagoItem e, bool ancha) {
    final estado = _estado(e);
    final abierta = _filasAbiertas.contains(e.id);
    final expandible = e.aplicaciones.isNotEmpty;

    // Igual que el portal: las filas no pagadas van resaltadas en ámbar claro.
    final resaltada = estado != _EstadoFila.pagado;

    final contenido = ancha
        ? _filaAncha(tone, e, estado, expandible, abierta)
        : _filaAngosta(tone, e, estado, expandible, abierta);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: resaltada
          ? BoxDecoration(
              color: tone.pendingSoft.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SozuColors.amber500.withValues(alpha: 0.25),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toda la fila alterna el desglose (además del chevron).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: expandible ? () => _alternarFila(e.id) : null,
            child: contenido,
          ),
          if (expandible && abierta) _pagosAplicados(tone, e),
        ],
      ),
    );
  }

  void _alternarFila(int id) => setState(() {
        _filasAbiertas.contains(id)
            ? _filasAbiertas.remove(id)
            : _filasAbiertas.add(id);
      });

  /// Layout ancho: columnas CONCEPTO | MONTO | ESTATUS | chevron.
  Widget _filaAncha(SozuTone tone, EsquemaPagoItem e, _EstadoFila estado,
      bool expandible, bool abierta) {
    return Row(
      children: [
        Expanded(child: _concepto(tone, e, estado, conIcono: false)),
        SizedBox(
          width: 150,
          child: Align(
            alignment: Alignment.centerRight,
            child: _monto(tone, e, estado, derecha: true),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 88,
          child: Align(
            alignment: Alignment.centerRight,
            child: _chipEstado(estado),
          ),
        ),
        SizedBox(
          width: 28,
          child: expandible ? _chevron(tone, abierta) : null,
        ),
      ],
    );
  }

  /// Layout angosto: el monto va debajo del concepto (sin overflow).
  Widget _filaAngosta(SozuTone tone, EsquemaPagoItem e, _EstadoFila estado,
      bool expandible, bool abierta) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iconoEstado(tone, estado),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _concepto(tone, e, estado, conIcono: true),
              const SizedBox(height: 6),
              _monto(tone, e, estado, derecha: false),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _chipEstado(estado),
            if (expandible) ...[
              const SizedBox(height: 6),
              _chevron(tone, abierta),
            ],
          ],
        ),
      ],
    );
  }

  /// Nombre del concepto + badge "N pagos" + fecha.
  Widget _concepto(SozuTone tone, EsquemaPagoItem e, _EstadoFila estado,
      {required bool conIcono}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              e.concepto,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tone.textPrimary,
              ),
            ),
            if (e.aplicaciones.length > 1) _badgePagos(tone, e.aplicaciones.length),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _fechaCorta(e.fechaPago),
          style: TextStyle(fontSize: 11, color: tone.textSecondary),
        ),
      ],
    );
  }

  /// Badge "N pagos" (concepto compuesto por varias dispersiones).
  Widget _badgePagos(SozuTone tone, int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tone.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_outlined, size: 11, color: tone.primaryDark),
          const SizedBox(width: 3),
          Text(
            '$n pagos',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: tone.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  /// Monto según estatus: parcial muestra abonado, "de $total" y
  /// "Faltan $saldo"; pagado muestra lo aplicado (o lo planeado).
  Widget _monto(SozuTone tone, EsquemaPagoItem e, _EstadoFila estado,
      {required bool derecha}) {
    final alineacion =
        derecha ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final estiloMonto = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: tone.textPrimary,
    );
    if (estado == _EstadoFila.parcial) {
      return Column(
        crossAxisAlignment: alineacion,
        children: [
          Text(formatMXN(e.pagado), style: estiloMonto),
          Text(
            'de ${formatMXN(e.monto)}',
            style: TextStyle(fontSize: 11, color: tone.textMuted),
          ),
          Text(
            'Faltan ${formatMXN(e.saldo)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tone.negative,
            ),
          ),
        ],
      );
    }
    final monto = estado == _EstadoFila.pagado && e.pagado > 0.01
        ? e.pagado
        : e.monto;
    return Text(formatMXN(monto), style: estiloMonto);
  }

  Widget _chipEstado(_EstadoFila estado) {
    return switch (estado) {
      _EstadoFila.pagado =>
        const StatusBadge(label: 'Pagado', tone: BadgeTone.positive),
      _EstadoFila.parcial =>
        const StatusBadge(label: 'Parcial', tone: BadgeTone.pending),
      _EstadoFila.pendiente =>
        const StatusBadge(label: 'Pendiente', tone: BadgeTone.pending),
    };
  }

  Widget _iconoEstado(SozuTone tone, _EstadoFila estado) {
    final (icono, bg, fg) = switch (estado) {
      _EstadoFila.pagado => (
          Icons.check_circle_outline,
          tone.primarySoft,
          tone.primaryDark,
        ),
      _EstadoFila.parcial => (
          Icons.layers_outlined,
          tone.pendingSoft,
          SozuColors.amber600,
        ),
      _EstadoFila.pendiente => (
          Icons.calendar_today_outlined,
          tone.pendingSoft,
          SozuColors.amber600,
        ),
    };
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icono, size: 15, color: fg),
    );
  }

  Widget _chevron(SozuTone tone, bool abierta) {
    return Container(
      width: 24,
      height: 24,
      decoration:
          BoxDecoration(color: tone.surfaceAlt, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(
        abierta ? Icons.expand_less : Icons.expand_more,
        size: 16,
        color: tone.textMuted,
      ),
    );
  }

  /// Desglose "N PAGOS APLICADOS A `<CONCEPTO>`" de una fila expandida.
  Widget _pagosAplicados(SozuTone tone, EsquemaPagoItem e) {
    final apps = [...e.aplicaciones]
      ..sort((a, b) => (a.fecha ?? '').compareTo(b.fecha ?? ''));
    final n = apps.length;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$n ${n == 1 ? 'PAGO APLICADO' : 'PAGOS APLICADOS'} '
            'A ${e.concepto.toUpperCase()}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: tone.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          for (final a in apps) _pagoAplicado(tone, a),
        ],
      ),
    );
  }

  /// Sub-fila de un pago aplicado: método · monto, fecha · clave de rastreo,
  /// y botón para ver el CEP (o el comprobante si no hay CEP), igual que el
  /// portal (cepUrl ?? evidenceUrl → visor de documento).
  Widget _pagoAplicado(SozuTone tone, AplicacionPago a) {
    final esCep = (a.urlCep ?? '').isNotEmpty;
    final url = esCep
        ? a.urlCep
        : ((a.urlRecibo ?? '').isNotEmpty ? a.urlRecibo : null);
    final clave = (a.claveRastreo ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: SozuColors.emerald500.withValues(alpha: 0.3),
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tone.textPrimary,
                  ),
                ),
                Text(
                  '${_fechaCorta(a.fecha)}'
                  '${clave.isNotEmpty ? ' · Clave $clave' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: tone.textSecondary),
                ),
              ],
            ),
          ),
          if (url != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: esCep ? 'Ver CEP electrónico' : 'Ver comprobante',
              child: InkWell(
                onTap: () => openMedia(
                  context,
                  url,
                  titulo: esCep ? 'CEP' : 'Comprobante',
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tone.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 16,
                    color: tone.primaryDark,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Fecha corta estilo portal: "20 may 2026" ──

const _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _fechaCorta(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  return '${d.day} ${_mesesCortos[d.month - 1]} ${d.year}';
}
