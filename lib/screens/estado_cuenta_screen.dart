import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/open_media.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../providers/impersonation_provider.dart';
import '../widgets/common.dart';

/// Estado de cuenta POR PROPIEDAD (paridad con el portal admin):
/// lista de propiedades (buscador) → detalle con resumen (KPIs), filtros
/// (año/estatus), orden y pestañas de Acuerdos de pago / Pagos realizados.
class EstadoCuentaScreen extends ConsumerStatefulWidget {
  const EstadoCuentaScreen({super.key});

  @override
  ConsumerState<EstadoCuentaScreen> createState() => _EstadoCuentaScreenState();
}

class _EstadoCuentaScreenState extends ConsumerState<EstadoCuentaScreen> {
  int? _selected; // propiedad elegida por el usuario
  String _query = '';
  String _estatus = 'todos'; // todos | pagado | pendiente
  String _anio = 'todos';
  int _tab = 0; // 0 = acuerdos, 1 = pagos
  bool _ordenDesc = true; // más reciente primero
  bool _descargando = false;
  int? _generandoRecibo; // id del pago cuyo recibo se está generando
  // Acuerdos con desglose de pagos expandido (clave = orden-concepto-fecha).
  final Set<String> _acuerdosExpandidos = {};

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

  Color _colorEstatus(SozuTone tone, String estatus) {
    final e = estatus.toLowerCase();
    if (e.contains('pendiente') || e.contains('vencid')) return tone.pending;
    if (e.contains('liquidad') || e.contains('entregad')) return tone.positive;
    return tone.primaryDark;
  }

  Future<void> _descargarPdf(int cuentaId) async {
    setState(() => _descargando = true);
    try {
      final imp = ref.read(impersonationProvider).idPersona;
      final url = await fetchEstadoCuentaPdfUrl(cuentaId, impersonate: imp);
      if (!mounted) return;
      if (url == null) {
        _snack('No pudimos generar el PDF. Intenta de nuevo.');
      } else {
        await openMedia(context, url, titulo: 'Estado de cuenta');
      }
    } catch (_) {
      if (mounted) _snack('No pudimos generar el PDF. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final props = ref.watch(clientePropiedadesProvider);

    return props.when(
      loading: () => _scaffold(context, const _LoadingList(), null),
      error: (_, __) => _scaffold(
        context,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ErrorCard(
              title: 'No pudimos cargar tus propiedades',
              onRetry: () => ref.invalidate(clientePropiedadesProvider),
            ),
          ],
        ),
        null,
      ),
      data: (data) {
        final cuentas = <PropiedadCard>[
          ...data.enAdquisicion,
          ...data.patrimonioActivo,
        ];
        if (cuentas.isEmpty) {
          return _scaffold(context, const _EmptyState(), null);
        }

        final single = cuentas.length == 1 ? cuentas.first : null;
        final cuenta = _selected != null
            ? cuentas.firstWhere(
                (c) => c.id == _selected,
                orElse: () => cuentas.first,
              )
            : single;

        if (cuenta == null) {
          return _scaffold(context, _lista(cuentas), null);
        }
        // Detalle. Si el usuario eligió de la lista, el back vuelve a la lista.
        final volverALista = _selected != null && single == null;
        return _scaffold(
          context,
          _detalle(cuenta),
          cuenta.id,
          onBack: volverALista ? () => setState(() => _selected = null) : null,
        );
      },
    );
  }

  Widget _scaffold(
    BuildContext context,
    Widget body,
    int? cuentaId, {
    VoidCallback? onBack,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de cuenta'),
        leading: onBack != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
            : null,
        actions: [
          if (cuentaId != null)
            _descargando
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Descargar PDF',
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () => _descargarPdf(cuentaId),
                  ),
        ],
      ),
      body: body,
    );
  }

  // ── Lista de propiedades ──────────────────────────────────────────────────
  Widget _lista(List<PropiedadCard> cuentas) {
    final tone = SozuTone.of(context);
    final q = _query.trim().toLowerCase();
    final filtradas = q.isEmpty
        ? cuentas
        : cuentas
              .where(
                (c) =>
                    c.nombre.toLowerCase().contains(q) ||
                    c.proyecto.toLowerCase().contains(q),
              )
              .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Selecciona una propiedad',
          style: TextStyle(fontSize: 14, color: tone.textSecondary),
        ),
        const SizedBox(height: 12),
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
          for (final c in filtradas) ...[
            _cardPropiedad(tone, c),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _cardPropiedad(SozuTone tone, PropiedadCard c) {
    final color = _colorEstatus(tone, c.estatusDerivado);
    return GestureDetector(
      onTap: () => setState(() {
        _selected = c.id;
        _estatus = 'todos';
        _anio = 'todos';
        _tab = 0;
        _ordenDesc = true;
        _acuerdosExpandidos.clear();
      }),
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
                c.nombre,
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
                    '${c.proyecto} · U${c.nombre}',
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
                    '${c.estatusDerivado} · ${c.avancePago.round()}% pagado · ${formatMXN(c.monto)}',
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

  // ── Detalle ────────────────────────────────────────────────────────────────
  Widget _detalle(PropiedadCard c) {
    final tone = SozuTone.of(context);
    final edo = ref.watch(estadoCuentaProvider(c.id));
    return edo.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ErrorCard(
            title: 'No pudimos cargar el estado de cuenta',
            onRetry: () => ref.invalidate(estadoCuentaProvider(c.id)),
          ),
        ],
      ),
      data: (d) => _contenido(tone, c, d),
    );
  }

  Widget _contenido(SozuTone tone, PropiedadCard c, EstadoCuenta d) {
    // Años de acuerdos Y pagos (antes solo acuerdos → faltaba 2026).
    final anios = <String>{
      for (final a in d.acuerdos)
        if ((a.fecha ?? '').length >= 4) a.fecha!.substring(0, 4),
      for (final p in d.pagos)
        if ((p.fecha ?? '').length >= 4) p.fecha!.substring(0, 4),
    }.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          '${c.proyecto} · U${c.nombre}',
          style: TextStyle(fontSize: 13, color: tone.textMuted),
        ),
        const SizedBox(height: 8),
        _resumen(tone, d),
        const SizedBox(height: 12),
        _tabs(tone, d),
        const SizedBox(height: 12),
        _filtros(tone, anios),
        const SizedBox(height: 4),
        if (_tab == 0) ..._listaAcuerdos(tone, d) else ..._listaPagos(tone, d),
        if (d.instrucciones != null &&
            (d.instrucciones!.clabe ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _instruccionesPago(tone, d.instrucciones!),
        ],
        const SizedBox(height: 16),
        Text(
          'Estado de cuenta generado automáticamente por SOZU.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: tone.textMuted),
        ),
      ],
    );
  }

  Widget _resumen(SozuTone tone, EstadoCuenta d) {
    final now = DateTime.now();
    final periodo = '${_meses[now.month - 1]} ${now.year}';

    // Próxima parcialidad: primer acuerdo no completado por fecha ascendente.
    final pendientes = d.acuerdos.where((a) => !a.pagadoCompleto).toList()
      ..sort((a, b) => (a.fecha ?? '').compareTo(b.fecha ?? ''));
    final proxima = pendientes.isEmpty ? null : pendientes.first;

    // Chip como el portal: "Pago Pendiente" (ámbar) con saldo, si no
    // "Al corriente". (Antes decía "Con adeudo" solo con vencidos.)
    final conAdeudo = d.saldoPendiente > 0.01;

    final progreso = d.precioFinal > 0
        ? (d.totalPagado / d.precioFinal).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Periodo · $periodo',
                  style: TextStyle(fontSize: 12, color: tone.textSecondary),
                ),
              ),
              StatusBadge(
                label: conAdeudo ? 'Pago Pendiente' : 'Al corriente',
                tone: conAdeudo ? BadgeTone.pending : BadgeTone.positive,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpi(
                tone,
                'Valor del activo',
                formatMXN(d.precioFinal),
                tone.textPrimary,
              ),
              _kpi(
                tone,
                'Total pagado',
                formatMXN(d.totalPagado),
                tone.positive,
              ),
              if (d.totalMultas > 0)
                _kpi(tone, 'Multas', formatMXN(d.totalMultas), tone.negative),
              _kpi(
                tone,
                'Saldo pendiente',
                formatMXN(d.saldoPendiente),
                tone.pending,
              ),
            ],
          ),
          if (proxima != null) ...[
            Divider(color: tone.border, height: 24),
            Text(
              'PRÓXIMA PARCIALIDAD',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: tone.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _conceptoAcuerdo(proxima),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tone.textPrimary,
                  ),
                ),
                Text(
                  '${formatMXN(proxima.monto)} · vence ${formatDate(proxima.fecha)}',
                  style: TextStyle(fontSize: 12, color: tone.textSecondary),
                ),
              ],
            ),
          ],
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
                '${(progreso * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tone.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: tone.surfaceAlt,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progreso,
                child: Container(color: tone.primaryDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _conceptoAcuerdo(AcuerdoPago a) =>
      a.concepto == 'Parcialidad' ? 'Parcialidad ${a.orden}' : a.concepto;

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

  Widget _tabs(SozuTone tone, EstadoCuenta d) {
    Widget tab(int i, String label, int count) {
      final active = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? tone.primaryDark : tone.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : tone.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(0, 'Acuerdos', d.acuerdos.length),
        const SizedBox(width: 8),
        tab(1, 'Pagos', d.pagos.length),
      ],
    );
  }

  Widget _filtros(SozuTone tone, List<String> anios) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Estatus solo aplica a acuerdos.
        if (_tab == 0)
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
        if (_tab == 0 && anios.isNotEmpty) const SizedBox(height: 8),
        if (anios.isNotEmpty)
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
        Row(
          children: [
            Icon(Icons.swap_vert, size: 18, color: tone.textMuted),
            const SizedBox(width: 4),
            TextButton(
              onPressed: () => setState(() => _ordenDesc = !_ordenDesc),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                _ordenDesc ? 'Más reciente' : 'Más antiguo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tone.primaryDark,
                ),
              ),
            ),
          ],
        ),
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

  int _cmpFecha(String? a, String? b) {
    final r = (a ?? '').compareTo(b ?? '');
    return _ordenDesc ? -r : r;
  }

  List<Widget> _listaAcuerdos(SozuTone tone, EstadoCuenta d) {
    final acuerdos = d.acuerdos.where((a) {
      if (_estatus == 'pagado' && !a.pagadoCompleto) return false;
      if (_estatus == 'pendiente' && a.pagadoCompleto) return false;
      if (_anio != 'todos' && !(a.fecha ?? '').startsWith(_anio)) return false;
      return true;
    }).toList()..sort((a, b) => _cmpFecha(a.fecha, b.fecha));

    if (acuerdos.isEmpty) {
      return [
        const EmptyCard(
          icon: Icons.receipt_long_outlined,
          text: 'Sin acuerdos para este filtro',
        ),
      ];
    }

    // Agrupación por mes (YYYY-MM) respetando el orden elegido.
    final grupos = <String, List<AcuerdoPago>>{};
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
      if (d.multas.isNotEmpty) ...[
        const SectionTitle(icon: Icons.gavel_outlined, text: 'Multas'),
        for (final m in d.multas) ...[
          _multaRow(tone, m),
          const SizedBox(height: 8),
        ],
      ],
    ];
  }

  List<Widget> _listaPagos(SozuTone tone, EstadoCuenta d) {
    final pagos = d.pagos.where((p) {
      if (_anio != 'todos' && !(p.fecha ?? '').startsWith(_anio)) return false;
      return true;
    }).toList()..sort((a, b) => _cmpFecha(a.fecha, b.fecha));

    if (pagos.isEmpty) {
      return [
        const EmptyCard(
          icon: Icons.payments_outlined,
          text: 'Sin pagos para este filtro',
        ),
      ];
    }
    return [
      for (final p in pagos) ...[_pagoRow(tone, p), const SizedBox(height: 8)],
      _totalPagos(tone, pagos.fold<double>(0, (s, p) => s + p.monto)),
    ];
  }

  Widget _mesHeader(SozuTone tone, String ym, List<AcuerdoPago> items) {
    final pagadoMes = items.fold<double>(0, (s, a) => s + a.pagado);
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
            '${formatMXN(pagadoMes)} pagado',
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

  Widget _acuerdoRow(SozuTone tone, AcuerdoPago a) {
    final parcial = !a.pagadoCompleto && a.pagado > 0.01;
    final apps = a.aplicaciones;
    final key = '${a.orden}-${a.concepto}-${a.fecha ?? ''}';
    final expanded = _acuerdosExpandidos.contains(key);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _conceptoAcuerdo(a),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tone.textPrimary,
                      ),
                    ),
                    if (apps.isNotEmpty) _pagosBadge(tone, apps.length),
                  ],
                ),
              ),
              StatusBadge(
                label: a.pagadoCompleto
                    ? 'Pagado'
                    : parcial
                    ? 'Parcial'
                    : 'Pendiente',
                tone: a.pagadoCompleto ? BadgeTone.positive : BadgeTone.pending,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatDate(a.fecha),
            style: TextStyle(fontSize: 12, color: tone.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _mini(tone, 'Monto', formatMXN(a.monto), tone.textPrimary),
              _mini(tone, 'Pagado', formatMXN(a.pagado), tone.positive),
              _mini(
                tone,
                'Pendiente',
                formatMXN(a.pendiente),
                a.pendiente > 0 ? tone.pending : tone.textMuted,
              ),
            ],
          ),
          if (parcial) ...[
            const SizedBox(height: 6),
            Text(
              'Faltan ${formatMXN(a.pendiente)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SozuColors.amber600,
              ),
            ),
          ],
          if (apps.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                if (!_acuerdosExpandidos.remove(key)) {
                  _acuerdosExpandidos.add(key);
                }
              }),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: tone.primaryDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    expanded
                        ? 'Ocultar pagos'
                        : 'Ver ${apps.length} ${apps.length == 1 ? 'pago' : 'pagos'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tone.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            if (expanded)
              for (final app in apps) _aplicacionRow(tone, app),
          ],
        ],
      ),
    );
  }

  Widget _pagosBadge(SozuTone tone, int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tone.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_outlined, size: 12, color: tone.primaryDark),
          const SizedBox(width: 4),
          Text(
            n == 1 ? '1 pago' : '$n pagos',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tone.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aplicacionRow(SozuTone tone, AplicacionPago app) {
    final clave = (app.claveRastreo ?? '').trim();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: tone.border, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${app.metodo ?? 'Pago'} · ${formatMXN(app.monto)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tone.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatDate(app.fecha),
            style: TextStyle(fontSize: 12, color: tone.textSecondary),
          ),
          if (clave.isNotEmpty) ...[
            const SizedBox(height: 2),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _copiar(clave, 'Clave de rastreo'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Clave $clave',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: tone.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.copy_outlined, size: 13, color: tone.textMuted),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _generandoRecibo == app.idPago
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _docBtn(
                      tone,
                      Icons.description_outlined,
                      'Recibo',
                      () => _abrirReciboAplicacion(app),
                    ),
              if ((app.urlCep ?? '').isNotEmpty)
                _docBtn(
                  tone,
                  Icons.receipt_long_outlined,
                  'CEP',
                  () => openMedia(context, app.urlCep, titulo: 'CEP'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _abrirReciboAplicacion(AplicacionPago app) async {
    // Recibo ya firmado en la respuesta: abrir directo.
    if ((app.urlRecibo ?? '').isNotEmpty) {
      await openMedia(context, app.urlRecibo, titulo: 'Recibo');
      return;
    }
    // No existe: pedir al backend que lo genere.
    setState(() => _generandoRecibo = app.idPago);
    try {
      final imp = ref.read(impersonationProvider).idPersona;
      final url = await fetchReciboPagoUrl(app.idPago, impersonate: imp);
      if (!mounted) return;
      if (url == null) {
        _snack('No pudimos generar el recibo. Intenta de nuevo.');
      } else {
        await openMedia(context, url, titulo: 'Recibo');
      }
    } catch (_) {
      if (mounted) _snack('No pudimos generar el recibo. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _generandoRecibo = null);
    }
  }

  Widget _multaRow(SozuTone tone, MultaItem m) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.descripcion,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tone.textPrimary,
                  ),
                ),
              ),
              StatusBadge(
                label: m.pagada ? 'Pagada' : 'Pendiente',
                tone: m.pagada ? BadgeTone.positive : BadgeTone.negative,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _mini(tone, 'Monto', formatMXN(m.monto), tone.textPrimary),
              _mini(tone, 'Pagado', formatMXN(m.pagado), tone.positive),
              _mini(
                tone,
                'Pendiente',
                formatMXN(m.pendiente),
                m.pendiente > 0 ? tone.pending : tone.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _abrirRecibo(PagoRealizado p) async {
    // Recibo ya firmado en la respuesta: abrir directo.
    if ((p.urlRecibo ?? '').isNotEmpty) {
      await openMedia(context, p.urlRecibo, titulo: 'Recibo');
      return;
    }
    // No existe: pedir al backend que lo genere.
    setState(() => _generandoRecibo = p.id);
    try {
      final imp = ref.read(impersonationProvider).idPersona;
      final url = await fetchReciboPagoUrl(p.id, impersonate: imp);
      if (!mounted) return;
      if (url == null) {
        _snack('No pudimos generar el recibo. Intenta de nuevo.');
      } else {
        await openMedia(context, url, titulo: 'Recibo');
      }
    } catch (_) {
      if (mounted) _snack('No pudimos generar el recibo. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _generandoRecibo = null);
    }
  }

  Widget _pagoRow(SozuTone tone, PagoRealizado p) {
    final tieneCep = (p.urlCep ?? '').isNotEmpty;
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tone.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_downward,
                  size: 16,
                  color: SozuColors.emerald600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.metodo,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tone.textPrimary,
                      ),
                    ),
                    Text(
                      '${formatDate(p.fecha)}${p.referencia != null ? ' · ${p.referencia}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tone.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                '+${formatMXN(p.monto)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tone.positive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Recibo: siempre disponible; si no existe, el backend lo genera.
              _generandoRecibo == p.id
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _docBtn(
                      tone,
                      Icons.description_outlined,
                      'Recibo',
                      () => _abrirRecibo(p),
                    ),
              if (tieneCep) ...[
                const SizedBox(width: 8),
                _docBtn(
                  tone,
                  Icons.receipt_long_outlined,
                  'CEP',
                  () => openMedia(context, p.urlCep, titulo: 'CEP'),
                ),
              ],
            ],
          ),
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

  Widget _totalPagos(SozuTone tone, double total) {
    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total pagos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: tone.textPrimary,
            ),
          ),
          Text(
            formatMXN(total),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: tone.positive,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(SozuTone tone, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: tone.textMuted)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ── Instrucciones de pago ─────────────────────────────────────────────────
  Widget _instruccionesPago(SozuTone tone, InstruccionesPago i) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INSTRUCCIONES DE PAGO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: tone.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          if ((i.banco ?? '').isNotEmpty) ...[
            _filaInfo(tone, 'Banco receptor', i.banco!),
            Divider(color: tone.border, height: 20),
          ],
          _filaCopiable(tone, 'CLABE', i.clabe!, mono: true),
          if (i.referencia.isNotEmpty) ...[
            Divider(color: tone.border, height: 20),
            _filaCopiable(tone, 'Referencia', i.referencia, mono: true),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 16, color: tone.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Realiza tu transferencia solo a esta cuenta. '
                  'CLABE vinculada exclusivamente a tu propiedad.',
                  style: TextStyle(fontSize: 12, color: tone.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filaInfo(SozuTone tone, String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: tone.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: tone.textPrimary,
            ),
          ),
        ),
        // Alineación con las filas copiables (ancho del IconButton).
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _filaCopiable(
    SozuTone tone,
    String label,
    String value, {
    bool mono = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: tone.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: mono ? 'monospace' : null,
              color: tone.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copiar',
          iconSize: 16,
          icon: Icon(Icons.copy_outlined, color: tone.textMuted),
          onPressed: () => _copiar(value, label),
        ),
      ],
    );
  }

  Future<void> _copiar(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _snack('$label copiado.');
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 160, height: 12),
            SizedBox(height: 8),
            Skeleton(width: 220, height: 30),
          ],
        ),
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      EmptyCard(
        icon: Icons.receipt_long_outlined,
        text: 'Aún no tienes propiedades con estado de cuenta.',
      ),
    ],
  );
}
