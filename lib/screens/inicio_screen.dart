import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';
import '../widgets/property_card.dart';

const _actividadMax = 3;

/// Inicio: hero patrimonio (fórmulas del portal web), Tu actividad,
/// Pendientes por propiedad, Mis propiedades y accesos rápidos.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SozuTone.of(context);
    final resumen = ref.watch(clienteResumenProvider);
    final props = ref.watch(clientePropiedadesProvider);
    final notif = ref.watch(clienteNotificacionesProvider);
    final auth = ref.watch(authProvider);
    final hasUnread = (notif.valueOrNull?.noLeidas ?? 0) > 0;

    final misPropiedades = <PropiedadCard>[
      ...?props.valueOrNull?.enAdquisicion,
      ...?props.valueOrNull?.patrimonioActivo,
    ];

    final ultimoAcceso =
        formatDate(auth.session?.user.lastSignInAt);

    void abrirProp(int id) => context.push('/propiedad/$id');

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(clienteResumenProvider);
            ref.invalidate(clientePropiedadesProvider);
            ref.invalidate(clienteNotificacionesProvider);
            try {
              await ref.read(clienteResumenProvider.future);
            } catch (_) {
              // el estado de error lo pinta la UI
            }
          },
          child: ContentFrame(
            child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // Header
              Row(
                children: [
                  SozuAvatar(iniciales: resumen.valueOrNull?.iniciales ?? '··'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: resumen.isLoading
                        ? const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Skeleton(width: 180, height: 20),
                              SizedBox(height: 6),
                              Skeleton(width: 240, height: 12),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_saludo()}, ${resumen.valueOrNull?.nombreLegal.split(RegExp(r'\s+')).first ?? 'cliente'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: tone.textPrimary,
                                ),
                              ),
                              Text(
                                '${resumen.valueOrNull?.tipoCliente ?? 'Inversionista'} · '
                                '${resumen.valueOrNull?.resumen.propiedadesActivas ?? 0} propiedades activas · '
                                'Últ. acceso $ultimoAcceso',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: tone.textSecondary),
                              ),
                            ],
                          ),
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(Icons.notifications_outlined,
                            color: tone.textSecondary),
                        onPressed: () => context.push('/notificaciones'),
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: tone.negative,
                              shape: BoxShape.circle,
                              border: Border.all(color: tone.surface),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ...resumen.when(
                loading: () => [
                  const AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 140, height: 12),
                        SizedBox(height: 10),
                        Skeleton(width: 260, height: 34),
                        SizedBox(height: 16),
                        Skeleton(height: 12),
                      ],
                    ),
                  ),
                ],
                error: (_, __) => [
                  ErrorCard(
                    title: 'No pudimos cargar tu información',
                    onRetry: () => ref.invalidate(clienteResumenProvider),
                  ),
                ],
                data: (data) => _content(
                    context, ref, tone, data, misPropiedades, abrirProp),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    SozuTone tone,
    ClienteResumen data,
    List<PropiedadCard> misPropiedades,
    void Function(int) abrirProp,
  ) {
    final r = data.resumen;
    return [
      // Hero patrimonio
      FadeSlideIn(
        child: AppCard(
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
                        'PATRIMONIO TOTAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color: tone.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: CountUpMoney(
                          value: r.patrimonioTotal,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: tone.textPrimary,
                          ),
                        ),
                      ),
                      if (r.invertidoTotal > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${formatMXN(r.plusvaliaGenerada)} '
                            '(${r.plusvaliaPorcentaje}%) últimos 12 meses',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tone.positive,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _miniMetric(tone, 'Invertido total',
                        formatMXN(r.invertidoTotal), tone.textPrimary),
                    const SizedBox(height: 8),
                    _miniMetric(tone, 'Plusvalía generada',
                        '+${formatMXN(r.plusvaliaGenerada)}', tone.positive),
                    const SizedBox(height: 8),
                    _miniMetric(tone, 'Saldo pendiente',
                        formatMXN(r.saldoPendiente), tone.pending),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: tone.border, height: 1),
            const SizedBox(height: 12),
            _dotLine(tone, tone.positive,
                'Patrimonio activo: ${formatMXN(r.activoValor)} (${r.activoUnidades} ${r.activoUnidades == 1 ? 'unidad' : 'unidades'})'),
            const SizedBox(height: 4),
            _dotLine(tone, tone.pending,
                'En adquisición: ${formatMXN(r.adquisicionValor)} (${r.adquisicionUnidades} ${r.adquisicionUnidades == 1 ? 'unidad' : 'unidades'})'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pagado · ${r.porcentajePagado.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tone.textPrimary,
                  ),
                ),
                Text(
                  '${formatMXNCompact(r.pagadoTotal)} de ${formatMXNCompact(r.invertidoTotal)}',
                  style: TextStyle(fontSize: 12, color: tone.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SozuProgressBar(percent: r.porcentajePagado),
          ],
        ),
        ),
      ),

      // Tu actividad
      const FadeSlideIn(
        delayMs: 120,
        child: SectionTitle(icon: Icons.bolt_outlined, text: 'Tu actividad'),
      ),
      if (data.actividad.isEmpty)
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.check_circle,
                  color: SozuColors.emerald500, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estás al día',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tone.textPrimary)),
                  Text('Sin pagos pendientes',
                      style:
                          TextStyle(fontSize: 12, color: tone.textSecondary)),
                ],
              ),
            ],
          ),
        )
      else ...[
        AppCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: tone.pendingSoft, shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_outlined,
                    color: SozuColors.amber600, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tienes ${data.actividad.length} pendiente${data.actividad.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tone.textPrimary),
                  ),
                  Text('Revisa y liquida tus pagos',
                      style:
                          TextStyle(fontSize: 12, color: tone.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final a in data.actividad.take(_actividadMax)) ...[
          _ActividadCard(a: a, onTap: () => abrirProp(a.cuentaId)),
          const SizedBox(height: 12),
        ],
        if (data.actividad.length > _actividadMax)
          Center(
            child: TextButton(
              onPressed: () => context.go('/adquisicion'),
              child: Text(
                'Ver ${data.actividad.length - _actividadMax} más',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: tone.primaryDark),
              ),
            ),
          ),
      ],

      // Pendientes por propiedad
      if (data.pendientesPorPropiedad.isNotEmpty) ...[
        const SectionTitle(
            icon: Icons.pending_actions_outlined,
            text: 'Pendientes por propiedad'),
        for (final p in data.pendientesPorPropiedad) ...[
          _PendienteRow(p: p, onTap: () => abrirProp(p.cuentaId)),
          const SizedBox(height: 10),
        ],
      ],

      // Mis propiedades
      if (misPropiedades.isNotEmpty) ...[
        const SectionTitle(icon: Icons.home_outlined, text: 'Mis propiedades'),
        ResponsiveCardGrid(
          children: [
            for (final it in misPropiedades.take(3))
              PropertyCardWidget(item: it, onTap: () => abrirProp(it.id)),
          ],
        ),
        const SizedBox(height: 4),
        if (misPropiedades.length > 3)
          Center(
            child: TextButton(
              onPressed: () => context.go('/adquisicion'),
              child: Text(
                'Ver todas (${misPropiedades.length} propiedades)',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: tone.primaryDark),
              ),
            ),
          ),
      ],

      // Accesos rápidos
      const FadeSlideIn(
        delayMs: 200,
        child: SectionTitle(
            icon: Icons.grid_view_outlined, text: 'Accesos rápidos'),
      ),
      FadeSlideIn(
        delayMs: 260,
        child: Row(
        children: [
          Expanded(
            child: _QuickAccess(
              icon: Icons.bar_chart_outlined,
              label: 'Estado de cuenta',
              onTap: () => context.push('/estado-cuenta'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickAccess(
              icon: Icons.schedule_outlined,
              label: 'Historial de pagos',
              onTap: () => context.push('/pagos'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickAccess(
              icon: Icons.folder_outlined,
              label: 'Documentos',
              onTap: () => context.go('/documentos'),
            ),
          ),
        ],
        ),
      ),
    ];
  }

  Widget _miniMetric(SozuTone tone, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: tone.textMuted)),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _dotLine(SozuTone tone, Color dot, String text) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: tone.textSecondary)),
        ),
      ],
    );
  }
}

class _ActividadCard extends StatelessWidget {
  final ActividadItem a;
  final VoidCallback onTap;

  const _ActividadCard({required this.a, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final pagar = a.accion == 'pagar' && a.monto > 0;
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        borderColor: a.urgencia == 'urgent'
            ? tone.negative.withValues(alpha: 0.3)
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.propiedad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tone.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StatusBadge(
                        label: a.tipo,
                        tone: a.urgencia == 'urgent'
                            ? BadgeTone.pending
                            : BadgeTone.neutral,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        a.categoria == 'patrimonio'
                            ? 'Patrimonio'
                            : 'En adquisición',
                        style: TextStyle(fontSize: 11, color: tone.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.fecha != null ? formatDate(a.fecha) : 'Próximamente',
                    style: TextStyle(fontSize: 12, color: tone.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (a.monto > 0)
                  Text(formatMXN(a.monto),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tone.textPrimary)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: pagar ? SozuColors.emerald500 : tone.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    pagar ? 'Pagar' : 'Ver',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pagar ? Colors.white : tone.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PendienteRow extends StatelessWidget {
  final PendientePropiedad p;
  final VoidCallback onTap;

  const _PendienteRow({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final dot = switch (p.urgencia) {
      'urgent' => tone.negative,
      'upcoming' => tone.pending,
      _ => tone.positive,
    };
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p.proyecto} · U-${p.unidad}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tone.textPrimary)),
                  Text(
                    '${p.tipo} · ${p.fecha != null ? formatDate(p.fecha) : 'Próximamente'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: tone.textSecondary),
                  ),
                ],
              ),
            ),
            Text(formatMXN(p.monto),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tone.pending)),
          ],
        ),
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAccess(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 26, color: SozuColors.emerald500),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
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
