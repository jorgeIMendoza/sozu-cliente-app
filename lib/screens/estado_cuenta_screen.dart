import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';

/// Estado de cuenta POR PROPIEDAD (paridad con el portal admin):
/// selector de propiedad → resumen (KPIs) + filtros (año/estatus) +
/// acuerdos de pago + multas + pagos realizados.
class EstadoCuentaScreen extends ConsumerStatefulWidget {
  const EstadoCuentaScreen({super.key});

  @override
  ConsumerState<EstadoCuentaScreen> createState() => _EstadoCuentaScreenState();
}

class _EstadoCuentaScreenState extends ConsumerState<EstadoCuentaScreen> {
  int? _cuentaId;
  String _estatus = 'todos'; // todos | pagado | pendiente
  String _anio = 'todos';

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final props = ref.watch(clientePropiedadesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Estado de cuenta')),
      body: props.when(
        loading: () => const _LoadingList(),
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
          final cuentas = <PropiedadCard>[
            ...data.enAdquisicion,
            ...data.patrimonioActivo,
          ];
          if (cuentas.isEmpty) {
            return const _EmptyState();
          }
          // Autoseleccionar si hay una sola.
          final cuentaId =
              _cuentaId ?? (cuentas.length == 1 ? cuentas.first.id : null);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _selectorPropiedad(tone, cuentas, cuentaId),
              const SizedBox(height: 8),
              if (cuentaId == null)
                const EmptyCard(
                  icon: Icons.receipt_long_outlined,
                  text: 'Elige una propiedad para ver su estado de cuenta.',
                )
              else
                _detalle(cuentaId),
            ],
          );
        },
      ),
    );
  }

  Widget _selectorPropiedad(
    SozuTone tone,
    List<PropiedadCard> cuentas,
    int? cuentaId,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROPIEDAD',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: tone.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: cuentaId,
              hint: const Text('Selecciona una propiedad'),
              items: [
                for (final c in cuentas)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.proyecto} · ${c.nombre}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() {
                _cuentaId = v;
                _estatus = 'todos';
                _anio = 'todos';
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detalle(int cuentaId) {
    final tone = SozuTone.of(context);
    final edo = ref.watch(estadoCuentaProvider(cuentaId));
    return edo.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ErrorCard(
          title: 'No pudimos cargar el estado de cuenta',
          onRetry: () => ref.invalidate(estadoCuentaProvider(cuentaId)),
        ),
      ),
      data: (d) => _contenido(tone, d),
    );
  }

  Widget _contenido(SozuTone tone, EstadoCuenta d) {
    // Años disponibles a partir de las fechas de acuerdos.
    final anios = <String>{
      for (final a in d.acuerdos)
        if ((a.fecha ?? '').length >= 4) a.fecha!.substring(0, 4),
    }.toList()..sort((a, b) => b.compareTo(a));

    final acuerdos = d.acuerdos.where((a) {
      if (_estatus == 'pagado' && !a.pagadoCompleto) return false;
      if (_estatus == 'pendiente' && a.pagadoCompleto) return false;
      if (_anio != 'todos' && !(a.fecha ?? '').startsWith(_anio)) return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _resumen(tone, d),
        const SizedBox(height: 8),
        _filtros(tone, anios),
        const SectionTitle(
          icon: Icons.receipt_long_outlined,
          text: 'Acuerdos de pago',
        ),
        if (acuerdos.isEmpty)
          const EmptyCard(
            icon: Icons.receipt_long_outlined,
            text: 'Sin acuerdos para este filtro',
          )
        else
          for (final a in acuerdos) ...[
            _acuerdoRow(tone, a),
            const SizedBox(height: 8),
          ],
        if (d.multas.isNotEmpty) ...[
          const SectionTitle(icon: Icons.gavel_outlined, text: 'Multas'),
          for (final m in d.multas) ...[
            _multaRow(tone, m),
            const SizedBox(height: 8),
          ],
        ],
        const SectionTitle(
          icon: Icons.payments_outlined,
          text: 'Pagos realizados',
        ),
        if (d.pagos.isEmpty)
          const EmptyCard(
            icon: Icons.payments_outlined,
            text: 'Sin pagos registrados',
          )
        else ...[
          for (final p in d.pagos) ...[
            _pagoRow(tone, p),
            const SizedBox(height: 8),
          ],
          _totalPagos(tone, d.totalPagos),
        ],
      ],
    );
  }

  Widget _resumen(SozuTone tone, EstadoCuenta d) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
        ],
      ),
    );
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

  Widget _filtros(SozuTone tone, List<String> anios) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chipRow('Estatus', [
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
        ]),
        if (anios.isNotEmpty) ...[
          const SizedBox(height: 8),
          _chipRow('Período', [
            _chip(
              tone,
              'Todos',
              _anio == 'todos',
              () => setState(() => _anio = 'todos'),
            ),
            for (final y in anios)
              _chip(tone, y, _anio == y, () => setState(() => _anio = y)),
          ]),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _chipRow(String label, List<Widget> chips) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: chips)),
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

  Widget _acuerdoRow(SozuTone tone, AcuerdoPago a) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${a.orden}. ${a.concepto}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tone.textPrimary,
                  ),
                ),
              ),
              StatusBadge(
                label: a.pagadoCompleto ? 'Pagado' : 'Pendiente',
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
        ],
      ),
    );
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

  Widget _pagoRow(SozuTone tone, PagoRealizado p) {
    return AppCard(
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
