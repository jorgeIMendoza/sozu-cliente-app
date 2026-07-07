import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';

class _Movimiento {
  final String key;
  final String? fecha;
  final String concepto;
  final String propiedad;
  final double monto;
  final bool esPago;
  final bool vencido;

  _Movimiento({
    required this.key,
    required this.fecha,
    required this.concepto,
    required this.propiedad,
    required this.monto,
    required this.esPago,
    this.vencido = false,
  });
}

/// Estado de cuenta: saldo + movimientos cronológicos (pagos y cargos).
class EstadoCuentaScreen extends ConsumerWidget {
  const EstadoCuentaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SozuTone.of(context);
    final pagos = ref.watch(clientePagosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Estado de cuenta')),
      body: pagos.when(
        loading: () => ListView(
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
        ),
        error: (_, __) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ErrorCard(
              title: 'No pudimos cargar el estado de cuenta',
              onRetry: () => ref.invalidate(clientePagosProvider),
            ),
          ],
        ),
        data: (data) {
          final movimientos = <_Movimiento>[
            for (final h in data.historial)
              _Movimiento(
                key: 'p-${h.id}',
                fecha: h.fechaPago,
                concepto: h.concepto,
                propiedad: h.propiedad,
                monto: h.monto,
                esPago: true,
              ),
            for (final c in data.proximosPagos)
              _Movimiento(
                key: 'c-${c.id}',
                fecha: c.fechaPago,
                concepto: c.concepto,
                propiedad: c.propiedad,
                monto: c.monto,
                esPago: false,
                vencido: c.vencido,
              ),
          ]..sort((a, b) => (b.fecha ?? '').compareTo(a.fecha ?? ''));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SALDO PENDIENTE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: tone.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(formatMXN(data.saldoPendiente),
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: tone.pending)),
                    const SizedBox(height: 12),
                    Divider(color: tone.border, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total',
                                style: TextStyle(
                                    fontSize: 11, color: tone.textMuted)),
                            Text(formatMXN(data.saldoTotal),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: tone.textPrimary)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Pagado',
                                style: TextStyle(
                                    fontSize: 11, color: tone.textMuted)),
                            Text(formatMXN(data.saldoPagado),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: tone.positive)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SectionTitle(
                  icon: Icons.swap_vert_outlined, text: 'Movimientos'),
              if (movimientos.isEmpty)
                const EmptyCard(
                    icon: Icons.swap_vert_outlined, text: 'Sin movimientos')
              else
                for (final m in movimientos) ...[
                  AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: m.esPago ? tone.primarySoft : tone.pendingSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            m.esPago
                                ? Icons.arrow_downward
                                : Icons.schedule_outlined,
                            size: 16,
                            color: m.esPago
                                ? SozuColors.emerald600
                                : SozuColors.amber600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.concepto,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: tone.textPrimary)),
                              Text(
                                '${m.propiedad} · ${formatDate(m.fecha)}${m.vencido ? ' · vencido' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: tone.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${m.esPago ? '+' : ''}${formatMXN(m.monto)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: m.esPago ? tone.positive : tone.pending,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}
