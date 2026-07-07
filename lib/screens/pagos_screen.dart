import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/open_media.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';

/// Pagos POR PROPIEDAD: primero se elige la propiedad (cards con
/// mini-resumen); luego saldo global + próximos pagos (vencidos en rojo) +
/// historial con recibo/CEP firmados de esa propiedad.
class PagosScreen extends ConsumerStatefulWidget {
  const PagosScreen({super.key});

  @override
  ConsumerState<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends ConsumerState<PagosScreen> {
  String? _propiedad; // numero de propiedad elegida (etiqueta de cliente-pagos)

  Color _colorEstatus(SozuTone tone, String estatus) {
    final e = estatus.toLowerCase();
    if (e.contains('pendiente') || e.contains('vencid')) return tone.pending;
    if (e.contains('liquidad') || e.contains('entregad')) return tone.positive;
    return tone.primaryDark;
  }

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
                onPressed: () => setState(() => _propiedad = null),
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
        else
          for (final numero in propiedades) ...[
            _cardPropiedad(tone, numero, cardDe(numero), data),
            const SizedBox(height: 10),
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
    final color = _colorEstatus(tone, c?.estatus ?? '');
    final pendientes = data.proximosPagos
        .where((p) => p.propiedad == numero)
        .length;
    final subtitulo = c != null
        ? '${c.estatus} · ${c.avancePago.round()}% pagado · ${formatMXN(c.monto)}'
        : '$pendientes pagos pendientes';
    return GestureDetector(
      onTap: () => setState(() => _propiedad = numero),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Text(
          'U$propiedad',
          style: TextStyle(fontSize: 13, color: tone.textMuted),
        ),
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
        const SectionTitle(
          icon: Icons.receipt_long_outlined,
          text: 'Historial',
        ),
        if (historial.isEmpty)
          const EmptyCard(
            icon: Icons.receipt_outlined,
            text: 'Aún no hay pagos registrados',
          )
        else
          for (final h in historial) ...[
            _HistorialRow(h: h),
            const SizedBox(height: 12),
          ],
      ],
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

class _ProximoRow extends StatelessWidget {
  final ProximoPago p;
  final VoidCallback onPagar;

  const _ProximoRow({required this.p, required this.onPagar});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return AppCard(
      borderColor: p.vencido ? tone.negative.withValues(alpha: 0.4) : null,
      child: Row(
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
                p.vencido
                    ? const StatusBadge(
                        label: 'Vencido',
                        tone: BadgeTone.negative,
                      )
                    : const StatusBadge(
                        label: 'Pendiente',
                        tone: BadgeTone.pending,
                      ),
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
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onPagar,
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
                      style: TextStyle(fontSize: 12, color: tone.textSecondary),
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
          if (h.urlRecibo != null || h.urlCep != null) ...[
            const SizedBox(height: 12),
            Divider(color: tone.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                if (h.urlRecibo != null)
                  _docChip(
                    context,
                    tone,
                    Icons.description_outlined,
                    'Recibo',
                    h.urlRecibo,
                  ),
                if (h.urlRecibo != null && h.urlCep != null)
                  const SizedBox(width: 8),
                if (h.urlCep != null)
                  _docChip(
                    context,
                    tone,
                    Icons.verified_user_outlined,
                    'CEP',
                    h.urlCep,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _docChip(
    BuildContext context,
    SozuTone tone,
    IconData icon,
    String label,
    String? url,
  ) {
    return GestureDetector(
      onTap: () => openMedia(context, url, titulo: label),
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
            Text(
              label,
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
