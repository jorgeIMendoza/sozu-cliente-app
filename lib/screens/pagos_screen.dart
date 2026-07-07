import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/open_doc.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';

/// Pagos: saldo + próximos pagos (vencidos en rojo) + historial con
/// recibo/CEP firmados.
class PagosScreen extends ConsumerWidget {
  const PagosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SozuTone.of(context);
    final pagos = ref.watch(clientePagosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagos'),
        actions: [
          TextButton(
            onPressed: () => context.push('/estado-cuenta'),
            child: Text(
              'Estado de cuenta',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: tone.primaryDark),
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
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              AppCard(
                child: Row(
                  children: [
                    _saldoItem(tone, 'Total', data.saldoTotal, tone.textPrimary),
                    _saldoItem(tone, 'Pagado', data.saldoPagado, tone.positive),
                    _saldoItem(
                        tone, 'Pendiente', data.saldoPendiente, tone.pending,
                        alignEnd: true),
                  ],
                ),
              ),

              const SectionTitle(
                  icon: Icons.schedule_outlined, text: 'Próximos pagos'),
              if (data.proximosPagos.isEmpty)
                const EmptyCard(
                    icon: Icons.task_alt_outlined,
                    text: 'Sin pagos pendientes')
              else
                for (final p in data.proximosPagos) ...[
                  _ProximoRow(
                      p: p,
                      onPagar: () => context.push('/pagar?id=${p.id}')),
                  const SizedBox(height: 12),
                ],

              const SectionTitle(
                  icon: Icons.receipt_long_outlined, text: 'Historial'),
              if (data.historial.isEmpty)
                const EmptyCard(
                    icon: Icons.receipt_outlined,
                    text: 'Aún no hay pagos registrados')
              else
                for (final h in data.historial) ...[
                  _HistorialRow(h: h),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _saldoItem(SozuTone tone, String label, double value, Color color,
      {bool alignEnd = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: tone.textMuted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(formatMXN(value),
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

class _ProximoRow extends StatelessWidget {
  final ProximoPago p;
  final VoidCallback onPagar;

  const _ProximoRow({required this.p, required this.onPagar});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return AppCard(
      borderColor:
          p.vencido ? tone.negative.withValues(alpha: 0.4) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.concepto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tone.textPrimary)),
                Text('${p.propiedad} · vence ${formatDate(p.fechaPago)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: tone.textSecondary)),
                const SizedBox(height: 6),
                p.vencido
                    ? const StatusBadge(
                        label: 'Vencido', tone: BadgeTone.negative)
                    : const StatusBadge(
                        label: 'Pendiente', tone: BadgeTone.pending),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatMXN(p.monto),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tone.textPrimary)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onPagar,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: SozuColors.emerald500,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Pagar',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistorialRow extends StatelessWidget {
  final HistorialPago h;

  const _HistorialRow({required this.h});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.concepto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tone.textPrimary)),
                    Text(
                        '${h.propiedad} · ${formatDate(h.fechaPago)} · ${h.metodo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: tone.textSecondary)),
                  ],
                ),
              ),
              Text(formatMXN(h.monto),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tone.positive)),
            ],
          ),
          if (h.urlRecibo != null || h.urlCep != null) ...[
            const SizedBox(height: 12),
            Divider(color: tone.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                if (h.urlRecibo != null)
                  _docChip(context, tone, Icons.description_outlined, 'Recibo',
                      h.urlRecibo),
                if (h.urlRecibo != null && h.urlCep != null)
                  const SizedBox(width: 8),
                if (h.urlCep != null)
                  _docChip(context, tone, Icons.verified_user_outlined, 'CEP',
                      h.urlCep),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _docChip(BuildContext context, SozuTone tone, IconData icon,
      String label, String? url) {
    return GestureDetector(
      onTap: () => openDoc(context, url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: tone.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: SozuColors.emerald600),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tone.textSecondary)),
          ],
        ),
      ),
    );
  }
}
