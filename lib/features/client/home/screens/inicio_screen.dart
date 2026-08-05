import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/app_download/components/app_download.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/client/home/components/notification_bell.dart';
import 'package:sozu_cliente_app/features/client/home/providers/home_providers.dart';
import 'package:sozu_cliente_app/features/client/properties/components/portal_property_card.dart';
import 'package:sozu_cliente_app/features/client/properties/components/property_card.dart';
import 'package:sozu_cliente_app/features/client/properties/providers/properties_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';

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
    // Modo portal (web ≥1024): réplica de ClienteInicio del Portal del
    // Cliente. El shell (sidebar + topbar) lo pinta PortalShellWrapper; la
    // vista móvil de abajo queda intacta.
    if (isPortalMode(context)) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: _PortalInicio(),
      );
    }

    final tone = context.s.color;
    final resumen = ref.watch(summaryProvider);
    final props = ref.watch(propertiesProvider);
    final auth = ref.watch(authProvider);

    final misPropiedades = <PropiedadCard>[
      ...?props.valueOrNull?.enAdquisicion,
      ...?props.valueOrNull?.patrimonioActivo,
    ];

    final ultimoAcceso = formatDate(auth.session?.lastSignInAt);

    void abrirProp(int id) => context.push('/propiedad/$id');

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(summaryProvider);
            ref.invalidate(propertiesProvider);
            ref.invalidate(notificationsProvider);
            try {
              await ref.read(summaryProvider.future);
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
                    SAvatar(initials: resumen.valueOrNull?.iniciales ?? '··'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: resumen.isLoading
                          ? const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SSkeleton(width: 180, height: 20),
                                SizedBox(height: 6),
                                SSkeleton(width: 240, height: 12),
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
                                    color: tone.fg,
                                  ),
                                ),
                                Text(
                                  '${resumen.valueOrNull?.tipoCliente ?? 'Inversionista'} · '
                                  '${resumen.valueOrNull?.resumen.propiedadesActivas ?? 0} propiedades activas · '
                                  'Últ. acceso $ultimoAcceso',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tone.fgMuted,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    // "Descargar app" solo en web-móvil (junto a la campana);
                    // en desktop lo pinta el topbar del shell.
                    if (kIsWeb && !isPortalMode(context))
                      IconButton(
                        tooltip: 'Descargar app',
                        icon: Icon(
                          Icons.download_outlined,
                          color: tone.fgMuted,
                        ),
                        onPressed: () => openAppStore(context),
                      ),
                    // En modo portal la campana ya la pinta el topbar del shell.
                    if (!isPortalMode(context)) const NotificationBell(),
                  ],
                ),
                const SizedBox(height: 12),

                ...resumen.when(
                  loading: () => [
                    const SCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SSkeleton(width: 140, height: 12),
                          SizedBox(height: 10),
                          SSkeleton(width: 260, height: 34),
                          SizedBox(height: 16),
                          SSkeleton(height: 12),
                        ],
                      ),
                    ),
                  ],
                  error: (_, __) => [
                    SErrorState(
                      title: 'No pudimos cargar tu información',
                      onRetry: () => ref.invalidate(summaryProvider),
                    ),
                  ],
                  data: (data) => _content(
                    context,
                    ref,
                    tone,
                    data,
                    misPropiedades,
                    props.hasValue,
                    abrirProp,
                  ),
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
    SozuColorRoles tone,
    ClienteResumen data,
    List<PropiedadCard> misPropiedades,
    bool propiedadesCargadas,
    void Function(int) abrirProp,
  ) {
    final r = data.resumen;
    return [
      // Hero patrimonio
      FadeSlideIn(
        child: SCard(
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
                            color: tone.fgSubtle,
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
                              color: tone.fg,
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
                      _miniMetric(
                        tone,
                        'Invertido total',
                        r.invertidoTotal,
                        tone.fg,
                      ),
                      const SizedBox(height: 8),
                      _miniMetric(
                        tone,
                        'Plusvalía generada',
                        r.plusvaliaGenerada,
                        tone.positive,
                        prefix: '+',
                      ),
                      const SizedBox(height: 8),
                      _miniMetric(
                        tone,
                        'Saldo pendiente',
                        r.saldoPendiente,
                        tone.warningFg,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: tone.border, height: 1),
              const SizedBox(height: 12),
              _dotLine(
                tone,
                tone.positive,
                'Patrimonio activo: ${formatMXN(r.activoValor)} (${r.activoUnidades} ${r.activoUnidades == 1 ? 'unidad' : 'unidades'})',
              ),
              const SizedBox(height: 4),
              _dotLine(
                tone,
                tone.warningFg,
                'En adquisición: ${formatMXN(r.adquisicionValor)} (${r.adquisicionUnidades} ${r.adquisicionUnidades == 1 ? 'unidad' : 'unidades'})',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pagado · ${r.porcentajePagado.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tone.fg,
                    ),
                  ),
                  Text(
                    '${formatMXNCompact(r.pagadoTotal)} de ${formatMXNCompact(r.invertidoTotal)}',
                    style: TextStyle(fontSize: 12, color: tone.fgMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SProgressBar(
                thickness: SProgressBarThickness.thick,
                percent: r.porcentajePagado,
              ),
            ],
          ),
        ),
      ),

      // Accesos rápidos (justo después del hero financiero)
      const FadeSlideIn(
        delayMs: 80,
        child: SSectionLabel.heading(
          icon: Icons.grid_view_outlined,
          text: 'Accesos rápidos',
        ),
      ),
      FadeSlideIn(
        delayMs: 100,
        child: Column(
          children: [
            _QuickAccess(
              icon: Icons.bar_chart_outlined,
              label: 'Estado de cuenta',
              subtitle: 'Saldo y movimientos',
              destacado: true,
              onTap: () => context.push('/estado-cuenta'),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _QuickAccess(
                    icon: Icons.schedule_outlined,
                    label: 'Historial de pagos',
                    subtitle: 'Todos tus pagos',
                    onTap: () => context.push('/pagos'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAccess(
                    icon: Icons.folder_outlined,
                    label: 'Documentos',
                    subtitle: 'Tu expediente',
                    onTap: () => context.go('/documentos'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      // Tu actividad
      const FadeSlideIn(
        delayMs: 120,
        child: SSectionLabel.heading(
          icon: Icons.bolt_outlined,
          text: 'Tu actividad',
        ),
      ),
      if (data.actividad.isEmpty)
        SCard(
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: SozuBrand.green500,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estás al día',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tone.fg,
                      ),
                    ),
                    Text(
                      data.resumen.mensajeContexto ?? 'Sin pagos pendientes',
                      style: TextStyle(fontSize: 12, color: tone.fgMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
      else ...[
        SCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.warningSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_outlined,
                  color: SozuAmber.strong,
                  size: 22,
                ),
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
                      color: tone.fg,
                    ),
                  ),
                  Text(
                    'Revisa y liquida tus pagos',
                    style: TextStyle(fontSize: 12, color: tone.fgMuted),
                  ),
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
                  fontWeight: FontWeight.w600,
                  color: tone.primaryHover,
                ),
              ),
            ),
          ),
      ],

      // Pendientes por propiedad
      if (data.pendientesPorPropiedad.isNotEmpty) ...[
        const SSectionLabel.heading(
          icon: Icons.pending_actions_outlined,
          text: 'Pendientes por propiedad',
        ),
        for (final p in data.pendientesPorPropiedad) ...[
          _PendienteRow(p: p, onTap: () => abrirProp(p.cuentaId)),
          const SizedBox(height: 10),
        ],
      ],

      // Mis propiedades (o estado vacío si no hay ninguna con data cargada)
      if (propiedadesCargadas && misPropiedades.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 24),
          child: _PortafolioVacio(),
        ),
      if (misPropiedades.isNotEmpty) ...[
        const SSectionLabel.heading(
          icon: Icons.home_outlined,
          text: 'Mis propiedades',
        ),
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
                  fontWeight: FontWeight.w600,
                  color: tone.primaryHover,
                ),
              ),
            ),
          ),
      ],
    ];
  }

  /// Recibe el MONTO, no una cadena ya formateada: la cifra cuenta hacia arriba
  /// al aparecer (y se muestra completa con "reducir movimiento", lo resuelve
  /// [CountUpMoney]).
  Widget _miniMetric(
    SozuColorRoles tone,
    String label,
    double value,
    Color color, {
    String prefix = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: tone.fgSubtle)),
        CountUpMoney(
          value: value,
          prefix: prefix,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _dotLine(SozuColorRoles tone, Color dot, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: tone.fgMuted),
          ),
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
    final tone = context.s.color;
    final pagar = a.accion == 'pagar' && a.monto > 0;
    // Borde por urgencia: urgente (rojo), próximo (ámbar), futuro (verde).
    final borde = switch (a.urgencia) {
      'urgent' => tone.danger,
      'upcoming' => SozuAmber.strong,
      _ => SozuBrand.green500,
    };
    return PressableScale(
      onTap: onTap,
      child: SCard(
        borderColor: borde.withValues(alpha: 0.35),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.propiedad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SBadge(
                        label: a.tipo,
                        tone: a.urgencia == 'urgent'
                            ? SBadgeTone.pending
                            : SBadgeTone.neutral,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        a.categoria == 'patrimonio'
                            ? 'Patrimonio'
                            : 'En adquisición',
                        style: TextStyle(fontSize: 11, color: tone.fgSubtle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.fecha != null ? formatDate(a.fecha) : 'Próximamente',
                    style: TextStyle(fontSize: 12, color: tone.fgMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (a.monto > 0)
                  Text(
                    formatMXN(a.monto),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pagar ? SozuBrand.green500 : tone.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    pagar ? 'Pagar' : 'Ver',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pagar ? Colors.white : tone.fgMuted,
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
    final tone = context.s.color;
    final dot = switch (p.urgencia) {
      'urgent' => tone.danger,
      'upcoming' => tone.warningFg,
      _ => tone.positive,
    };
    return PressableScale(
      onTap: onTap,
      child: SCard(
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.proyecto} · U-${p.unidad}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tone.fg,
                    ),
                  ),
                  Text(
                    '${p.tipo} · ${p.fecha != null ? formatDate(p.fecha) : 'Próximamente'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: tone.fgMuted),
                  ),
                ],
              ),
            ),
            Text(
              formatMXN(p.monto),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tone.warningFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado vacío del portafolio: el cliente aún no tiene propiedades.
class _PortafolioVacio extends StatelessWidget {
  const _PortafolioVacio();

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return SCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tone.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.apartment_outlined,
              size: 32,
              color: tone.fgSubtle,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aún no tienes propiedades',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: tone.fg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cuando adquieras una propiedad con SOZU '
            'aparecerá aquí con toda su información.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: tone.fgMuted),
          ),
        ],
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool destacado;
  final VoidCallback onTap;

  const _QuickAccess({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.destacado = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;

    final iconBox = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: destacado ? tone.primarySoft : tone.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 20,
        color: destacado ? SozuBrand.green600 : tone.fgMuted,
      ),
    );

    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: tone.fg,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: tone.fgSubtle),
        ),
      ],
    );

    return PressableScale(
      onTap: onTap,
      child: destacado
          // Tarjeta destacada de ancho completo (Estado de cuenta).
          ? SCard(
              child: Row(
                children: [
                  iconBox,
                  const SizedBox(width: 12),
                  Expanded(child: textos),
                  Text(
                    'Ver →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tone.primaryHover,
                    ),
                  ),
                ],
              ),
            )
          : SCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [iconBox, const SizedBox(height: 10), textos],
              ),
            ),
    );
  }
}

/// Vista "modo portal" (web >=1024): hero patrimonio, Tu actividad, grid de
/// propiedades y columna lateral. Mismos providers que la vista móvil.
class _PortalInicio extends ConsumerWidget {
  const _PortalInicio();

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// "Hoy 9:30 am" cuando el último acceso fue hoy; si no, fecha DD/MM/YYYY.
  String _ultimoAcceso(Object? input) {
    DateTime? dt;
    if (input is DateTime) {
      dt = input;
    } else if (input is String && input.isNotEmpty) {
      dt = DateTime.tryParse(input);
    }
    if (dt == null) return formatDate(input);
    final local = dt.toLocal();
    final now = DateTime.now();
    final esHoy =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (!esHoy) return formatDate(local);
    final ampm = local.hour < 12 ? 'am' : 'pm';
    var h = local.hour % 12;
    if (h == 0) h = 12;
    final mm = local.minute.toString().padLeft(2, '0');
    return 'Hoy $h:$mm $ampm';
  }

  String _unidades(int n) => n == 1 ? 'unidad' : 'unidades';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(summaryProvider);
    final props = ref.watch(propertiesProvider);
    final auth = ref.watch(authProvider);
    final ultimoAcceso = _ultimoAcceso(auth.session?.lastSignInAt);

    return resumen.when(
      loading: () => const SingleChildScrollView(
        padding: EdgeInsets.only(top: 24, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SSkeleton(width: 240, height: 24),
            ),
            SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SSkeleton(width: 320, height: 12),
            ),
            SizedBox(height: 16),
            SSkeleton(height: 220, radius: kPortalRadiusCard),
            SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SSkeleton(height: 88, radius: kPortalRadiusCard),
                      SizedBox(height: 12),
                      SSkeleton(height: 120, radius: kPortalRadiusCard),
                      SizedBox(height: 12),
                      SSkeleton(height: 120, radius: kPortalRadiusCard),
                    ],
                  ),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SSkeleton(height: 72, radius: kPortalRadiusLg),
                      SizedBox(height: 12),
                      SSkeleton(height: 150, radius: kPortalRadiusCard),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      error: (_, __) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          SErrorState(
            title: 'No pudimos cargar tu información',
            onRetry: () => ref.invalidate(summaryProvider),
          ),
        ],
      ),
      data: (data) {
        final misPropiedades = <PropiedadCard>[
          ...?props.valueOrNull?.enAdquisicion,
          ...?props.valueOrNull?.patrimonioActivo,
        ];
        final sinPropiedades = props.hasValue && misPropiedades.isEmpty;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 24, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _welcome(data, ultimoAcceso),
              if (sinPropiedades)
                _portafolioVacio()
              else ...[
                const SizedBox(height: 16),
                _heroPatrimonio(data.resumen),
                const SizedBox(height: 24),
                // Grid 2/1 del portal: columna principal + lateral.
                LayoutBuilder(
                  builder: (context, c) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: c.maxWidth >= 960 ? 2 : 1,
                        child: _columnaPrincipal(context, data, misPropiedades),
                      ),
                      const SizedBox(width: 24),
                      Expanded(child: _columnaLateral(context, data)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── 1. Saludo (WelcomeSection) ────────────────────────────────────────────
  Widget _welcome(ClienteResumen data, String ultimoAcceso) {
    Widget punto() => Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: PortalColors.border,
        shape: BoxShape.circle,
      ),
    );
    final n = data.resumen.propiedadesActivas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_saludo()}, ${data.nombreLegal.split(RegExp(r'\s+')).first}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: portalText(
            size: 20,
            weight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              data.tipoCliente,
              style: portalText(size: 12, color: PortalColors.mutedForeground),
            ),
            punto(),
            Text(
              '$n propiedad${n == 1 ? '' : 'es'} activa${n == 1 ? '' : 's'}',
              style: portalText(size: 12, color: PortalColors.mutedForeground),
            ),
            punto(),
            Text(
              'Último acceso: $ultimoAcceso',
              style: portalText(
                size: 11,
                color: PortalColors.mutedForeground.withValues(alpha: .6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 2. Hero PATRIMONIO TOTAL (HeroFinancialSummary) ───────────────────────
  Widget _heroPatrimonio(ResumenFinanciero r) {
    final plusvalia = r.plusvaliaGenerada < 0 ? 0.0 : r.plusvaliaGenerada;
    return SCard(
      borderColor: PortalColors.borderSoft,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final izquierda = _heroIzquierda(r, plusvalia);
              final derecha = _heroMetricas(r, plusvalia);
              if (c.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [izquierda, const SizedBox(height: 24), derecha],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: izquierda),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.only(left: 32),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: PortalColors.borderSoft),
                        ),
                      ),
                      child: derecha,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // Barra "Pagado · %"
          Container(
            padding: const EdgeInsets.only(top: 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PortalColors.borderSoft)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pagado · ${r.porcentajePagado.toStringAsFixed(0)}%',
                      style: portalText(size: 12, weight: FontWeight.w500),
                    ),
                    Text(
                      '${formatMXNCompact(r.pagadoTotal)} de '
                      '${formatMXNCompact(r.invertidoTotal)}',
                      style: portalText(
                        size: 12,
                        color: PortalColors.mutedForeground,
                        tabular: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SProgressBar(
                  percent: r.porcentajePagado,
                  thickness: SProgressBarThickness.thin,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroIzquierda(ResumenFinanciero r, double plusvalia) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PATRIMONIO TOTAL',
          style: portalText(
            size: 10,
            weight: FontWeight.w600,
            color: PortalColors.mutedForeground,
            letterSpacing: 2, // tracking-[0.2em]
          ),
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: CountUpMoney(
            value: r.patrimonioTotal,
            style: portalText(
              size: 56,
              weight: FontWeight.w700,
              letterSpacing: -1.4,
              height: 1,
              tabular: true,
            ),
          ),
        ),
        if (r.invertidoTotal > 0) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.trending_up,
                    size: 14,
                    color: PortalColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '+${formatMXN(plusvalia)}',
                    style: portalText(
                      size: 13,
                      weight: FontWeight.w600,
                      color: PortalColors.primary,
                      tabular: true,
                    ),
                  ),
                ],
              ),
              Text(
                '(${r.plusvaliaPorcentaje.toStringAsFixed(1)}%)',
                style: portalText(
                  size: 13,
                  weight: FontWeight.w500,
                  color: PortalColors.primary,
                  tabular: true,
                ),
              ),
              Text(
                'últimos 12 meses',
                style: portalText(
                  size: 13,
                  color: PortalColors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '${r.propiedadesActivas} '
          'propiedad${r.propiedadesActivas == 1 ? '' : 'es'} '
          'activa${r.propiedadesActivas == 1 ? '' : 's'}',
          style: portalText(size: 12, color: PortalColors.mutedForeground),
        ),
        const SizedBox(height: 16),
        // Indicadores por categoría
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            _categoria(
              PortalColors.primary,
              'Patrimonio activo:',
              r.activoValor,
              r.activoUnidades,
            ),
            _categoria(
              PortalColors.warning,
              'En adquisición:',
              r.adquisicionValor,
              r.adquisicionUnidades,
            ),
          ],
        ),
      ],
    );
  }

  Widget _categoria(Color dot, String label, double valor, int unidades) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: portalText(size: 12, color: PortalColors.mutedForeground),
        ),
        const SizedBox(width: 6),
        Text(
          formatMXN(valor),
          style: portalText(size: 12, weight: FontWeight.w600, tabular: true),
        ),
        const SizedBox(width: 6),
        Text(
          '($unidades ${_unidades(unidades)})',
          style: portalText(size: 12, color: PortalColors.mutedForeground),
        ),
      ],
    );
  }

  Widget _heroMetricas(ResumenFinanciero r, double plusvalia) {
    Widget fila(
      String label,
      double value,
      Color color, {
      String prefix = '',
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: portalText(size: 12, color: PortalColors.mutedForeground),
          ),
          CountUpMoney(
            value: value,
            prefix: prefix,
            style: portalText(
              size: 14,
              weight: FontWeight.w600,
              color: color,
              tabular: true,
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        fila('Invertido total', r.invertidoTotal, PortalColors.foreground),
        const Divider(height: 1, color: PortalColors.borderSoft),
        fila(
          'Plusvalía generada',
          plusvalia,
          PortalColors.primary,
          prefix: '+',
        ),
        const Divider(height: 1, color: PortalColors.borderSoft),
        fila('Saldo pendiente', r.saldoPendiente, PortalColors.foreground),
      ],
    );
  }

  // ── Columna principal: Tu actividad + Mis propiedades ─────────────────────
  Widget _columnaPrincipal(
    BuildContext context,
    ClienteResumen data,
    List<PropiedadCard> misPropiedades,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tu actividad',
          style: portalText(size: 15, weight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ..._actividad(context, data),
        if (misPropiedades.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Mis propiedades',
            style: portalText(size: 15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          PortalCardGrid(
            minItemWidth: 320,
            children: [
              for (final it in misPropiedades.take(3))
                PortalPropertyCard(
                  item: it,
                  onTap: () => context.push('/propiedad/${it.id}'),
                ),
            ],
          ),
          if (misPropiedades.length > 3) ...[
            const SizedBox(height: 12),
            PortalDashedButton(
              label: 'Ver todas (${misPropiedades.length} propiedades)',
              onTap: () => context.go('/adquisicion'),
            ),
          ],
        ],
      ],
    );
  }

  List<Widget> _actividad(BuildContext context, ClienteResumen data) {
    if (data.actividad.isEmpty) {
      return [
        SCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PortalColors.primarySoft15,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: PortalColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estás al día',
                      style: portalText(size: 14, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.resumen.mensajeContexto ?? 'Sin pagos pendientes',
                      style: portalText(
                        size: 12,
                        color: PortalColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      // Banner resumen de pendientes
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: PortalColors.warningSoft10,
          borderRadius: BorderRadius.circular(kPortalRadiusCard),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PortalColors.warningSoft15,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_outlined,
                size: 20,
                color: PortalColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tienes ${data.actividad.length} '
                    'pendiente${data.actividad.length == 1 ? '' : 's'}',
                    style: portalText(size: 14, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Revisa y liquida tus pagos',
                    style: portalText(
                      size: 12,
                      color: PortalColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      for (final a in data.actividad.take(_actividadMax)) ...[
        const SizedBox(height: 12),
        _PortalActividadCard(
          a: a,
          onTap: () => context.push('/propiedad/${a.cuentaId}'),
        ),
      ],
      if (data.actividad.length > _actividadMax) ...[
        const SizedBox(height: 12),
        PortalDashedButton(
          label: 'Ver ${data.actividad.length - _actividadMax} más',
          onTap: () => context.go('/adquisicion'),
        ),
      ],
    ];
  }

  // ── Columna lateral: Accesos rápidos + Pendientes por propiedad ───────────
  Widget _columnaLateral(BuildContext context, ClienteResumen data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Accesos rápidos',
          style: portalText(size: 15, weight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _PortalQuickAction(
          icon: Icons.receipt_long_outlined,
          label: 'Estado de cuenta',
          subtitle: 'Saldo y movimientos',
          featured: true,
          onTap: () => context.push('/estado-cuenta'),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PortalQuickAction(
                icon: Icons.schedule_outlined,
                label: 'Historial de pagos',
                subtitle: 'Todos tus pagos',
                onTap: () => context.push('/pagos'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PortalQuickAction(
                icon: Icons.description_outlined,
                label: 'Documentos',
                subtitle: 'Tu expediente',
                onTap: () => context.go('/documentos'),
              ),
            ),
          ],
        ),
        if (data.pendientesPorPropiedad.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Pendientes por propiedad',
            style: portalText(size: 14, weight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SCard(
            clip: true,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (
                  var i = 0;
                  i < data.pendientesPorPropiedad.length;
                  i++
                ) ...[
                  if (i > 0)
                    const Divider(height: 1, color: PortalColors.border),
                  _PortalPendienteRow(
                    p: data.pendientesPorPropiedad[i],
                    onTap: () => context.push(
                      '/propiedad/${data.pendientesPorPropiedad[i].cuentaId}',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Portafolio vacío (EmptyPortfolio) ─────────────────────────────────────
  Widget _portafolioVacio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PortalColors.muted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.apartment_outlined,
              size: 32,
              color: PortalColors.mutedForeground.withValues(alpha: .5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aún no tienes propiedades',
            style: portalText(size: 15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              'Cuando adquieras una propiedad con SOZU aparecerá aquí '
              'con toda su información.',
              textAlign: TextAlign.center,
              style: portalText(size: 13, color: PortalColors.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card de pendiente de "Tu actividad" (ActivitySection): barrita izquierda
/// de 3px por urgencia, chips de tipo y categoría, fecha y CTA Pagar/Ver.
class _PortalActividadCard extends StatelessWidget {
  final ActividadItem a;
  final VoidCallback onTap;

  const _PortalActividadCard({required this.a, required this.onTap});

  /// Tono del chip de tipo: pago final en rojo, parcialidad/mensualidad en
  /// ámbar, el resto en verde.
  SBadgeTone _toneTipo() {
    final t = a.tipo.toLowerCase();
    if (t.contains('final')) return SBadgeTone.negative;
    if (t.contains('parcialidad') || t.contains('mensualidad')) {
      return SBadgeTone.pending;
    }
    return SBadgeTone.positive;
  }

  @override
  Widget build(BuildContext context) {
    final barra = switch (a.urgencia) {
      'urgent' => PortalColors.destructive,
      'upcoming' => PortalColors.warning,
      _ => PortalColors.primary,
    };
    final toneTipo = _toneTipo();
    final pagar = a.accion == 'pagar' && a.monto > 0;
    final esPatrimonio = a.categoria == 'patrimonio';

    return SPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kPortalRadiusCard),
      child: SHoverBuilder(
        builder: (context, hovered) => AnimatedContainer(
          // Solo el borde se anima aquí: el hundido de press lo pone SPressable.
          duration: context.s.motion.fast,
          curve: context.s.motion.emphasized,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: PortalColors.surface,
            borderRadius: BorderRadius.circular(kPortalRadiusCard),
            border: Border.all(
              color: hovered ? PortalColors.borderSoft : PortalColors.border,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: barra),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                a.propiedad,
                                style: portalText(
                                  size: 14,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              SBadge(
                                label: a.tipo,
                                tone: toneTipo,
                                size: SBadgeSize.sm,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: esPatrimonio
                                      ? PortalColors.primarySoft6
                                      : PortalColors.mutedSoft30,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: esPatrimonio
                                        ? PortalColors.primaryBorder30
                                        : PortalColors.border,
                                  ),
                                ),
                                child: Text(
                                  esPatrimonio
                                      ? 'Patrimonio'
                                      : 'En adquisición',
                                  style: portalText(
                                    size: 9,
                                    weight: FontWeight.w500,
                                    color: esPatrimonio
                                        ? PortalColors.primary
                                        : PortalColors.mutedForeground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            a.fecha != null
                                ? formatDate(a.fecha)
                                : 'Próximamente',
                            style: portalText(
                              size: 12,
                              color: PortalColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (a.monto > 0) ...[
                          Text(
                            formatMXN(a.monto),
                            style: portalText(
                              size: 16,
                              weight: FontWeight.w700,
                              tabular: true,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              pagar
                                  ? Icons.credit_card_outlined
                                  : Icons.chevron_right,
                              size: 12,
                              color: PortalColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              pagar ? 'Pagar' : 'Ver',
                              style: portalText(
                                size: 11,
                                weight: FontWeight.w600,
                                color: PortalColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acceso rápido del portal (QuickActionsGrid): destacado en fila con
/// "Ver →" o celda vertical con icono en caja muted.
class _PortalQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool featured;
  final VoidCallback onTap;

  const _PortalQuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.featured = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBox = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: featured ? PortalColors.primarySoft10 : PortalColors.muted,
        borderRadius: BorderRadius.circular(kPortalRadiusMd),
      ),
      child: Icon(
        icon,
        size: 16,
        color: featured ? PortalColors.primary : PortalColors.mutedForeground,
      ),
    );
    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: portalText(size: 13, weight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: portalText(size: 11, color: PortalColors.mutedForeground),
        ),
      ],
    );
    return SPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kPortalRadiusLg),
      child: SHoverBuilder(
        builder: (context, hovered) => AnimatedContainer(
          // Solo el borde y la sombra se animan aquí: el hundido de press lo
          // pone SPressable.
          duration: context.s.motion.fast,
          curve: context.s.motion.emphasized,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PortalColors.surface,
            borderRadius: BorderRadius.circular(kPortalRadiusLg),
            border: Border.all(
              color: hovered ? PortalColors.borderSoft : PortalColors.border,
            ),
            boxShadow: featured && hovered
                ? const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ]
                : const [],
          ),
          child: featured
              ? Row(
                  children: [
                    iconBox,
                    const SizedBox(width: 12),
                    Expanded(child: textos),
                    Text(
                      'Ver →',
                      style: portalText(
                        size: 12,
                        weight: FontWeight.w500,
                        color: PortalColors.primary,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [iconBox, const SizedBox(height: 10), textos],
                ),
        ),
      ),
    );
  }
}

/// Fila de "Pendientes por propiedad" (PendingsByProperty): punto de
/// urgencia, proyecto + unidad, tipo · fecha y monto con chevron.
class _PortalPendienteRow extends StatelessWidget {
  final PendientePropiedad p;
  final VoidCallback onTap;

  const _PortalPendienteRow({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dot = switch (p.urgencia) {
      'urgent' => PortalColors.destructive,
      'upcoming' => PortalColors.warning,
      _ => PortalColors.primary,
    };
    return SHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: hovered ? PortalColors.mutedHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: p.proyecto,
                            style: portalText(
                              size: 13,
                              weight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: '  U-${p.unidad}',
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
                    const SizedBox(height: 2),
                    Text(
                      '${p.tipo} · '
                      '${p.fecha != null ? formatDate(p.fecha) : 'Próximamente'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: portalText(
                        size: 11,
                        color: PortalColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatMXN(p.monto),
                style: portalText(
                  size: 14,
                  weight: FontWeight.w700,
                  tabular: true,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: PortalColors.mutedForeground.withValues(alpha: .4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
