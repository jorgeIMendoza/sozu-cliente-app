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
import 'package:sozu_cliente_app/features/client/home/components/quick_access_grid.dart';
import 'package:sozu_cliente_app/features/client/home/providers/home_providers.dart';
import 'package:sozu_cliente_app/features/client/properties/components/portal_property_card.dart';
import 'package:sozu_cliente_app/features/client/properties/components/property_card.dart';
import 'package:sozu_cliente_app/features/client/properties/providers/properties_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';

const _actividadMax = 3;

/// Los 8 destinos del grid, en orden de necesidad. Ninguno abre un objeto
/// concreto: con varias propiedades, adivinar cuál llevaba a "/pagar" sin
/// acuerdo y a un error. Vive aquí y no en el componente porque navega.
List<QuickAccessItem> _accesosRapidos(
  BuildContext context, {
  required int pendientes,
}) {
  String? conteo(int n) => n > 0 ? (n > 9 ? '9+' : '$n') : null;
  return [
    QuickAccessItem(
      icon: Icons.apartment_outlined,
      label: 'Propiedades',
      featured: true,
      badge: conteo(pendientes),
      onTap: () => context.go('/propiedades'),
    ),
    QuickAccessItem(
      icon: Icons.bar_chart_outlined,
      label: 'Estado de cuenta',
      onTap: () => context.push('/estado-cuenta'),
    ),
    QuickAccessItem(
      icon: Icons.credit_card_outlined,
      label: 'Pagos',
      onTap: () => context.push('/pagos'),
    ),
    // "Facturación" y "Mis documentos" antes se llamaban "Documentos" y
    // "Expediente": nadie sabía cuál era cuál. Ahora el nombre dice el
    // contenido - facturas de la unidad contra identidad del titular.
    QuickAccessItem(
      icon: Icons.receipt_long_outlined,
      label: 'Facturación',
      onTap: () => context.go('/documentos'),
    ),
    QuickAccessItem(
      icon: Icons.badge_outlined,
      label: 'Mis documentos',
      onTap: () => context.push('/expediente'),
    ),
    QuickAccessItem(
      icon: Icons.build_outlined,
      label: 'Mantenimientos',
      onTap: () => context.push('/mantenimientos'),
    ),
    QuickAccessItem(
      icon: Icons.inventory_2_outlined,
      label: 'Productos',
      onTap: () => context.push('/productos'),
    ),
    QuickAccessItem(
      icon: Icons.settings_outlined,
      label: 'Configuración',
      onTap: () => context.go('/perfil'),
    ),
  ];
}

/// Inicio: saludo, accesos rápidos, pendientes más urgentes y propiedades. El
/// patrimonio total no va aquí: la cifra agregada no dice qué hacer.
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
                                  style: context.s.text.bodyLarge.copyWith(
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
                                  style: context.s.text.caption.copyWith(
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
                SizedBox(height: context.s.space.md),

                // Fuera del `when`: no dependen de la carga.
                QuickAccessGrid(
                  items: _accesosRapidos(
                    context,
                    pendientes: resumen.valueOrNull?.actividad.length ?? 0,
                  ),
                ),
                SizedBox(height: context.s.space.lg),

                ...resumen.when(
                  loading: () => [
                    const SCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SSkeleton(width: 140, height: 12),
                          SizedBox(height: 10),
                          SSkeleton(height: 64),
                          SizedBox(height: 12),
                          SSkeleton(height: 64),
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
    final pendientes = data.actividad.take(_actividadMax).toList();
    return [
      // Pendientes: lo primero bajo los accesos porque es lo unico de esta
      // pantalla que pide una accion con fecha.
      SSectionLabel.heading(
        icon: Icons.pending_actions_outlined,
        text: pendientes.isEmpty
            ? 'Pendientes'
            : 'Pendientes (${data.actividad.length})',
        trailing: data.actividad.length > _actividadMax
            ? TextButton(
                onPressed: () => context.go('/propiedades'),
                child: Text(
                  'Ver todos',
                  style: context.s.text.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.primaryHover,
                  ),
                ),
              )
            : null,
      ),
      if (pendientes.isEmpty)
        SCard(
          child: Row(
            children: [
              Icon(Icons.check_circle, color: tone.positive, size: 28),
              SizedBox(width: context.s.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estás al día',
                      style: context.s.text.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tone.fg,
                      ),
                    ),
                    Text(
                      data.resumen.mensajeContexto ?? 'Sin pagos pendientes',
                      style: context.s.text.caption.copyWith(
                        color: tone.fgMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
      else
        for (final a in pendientes) ...[
          _ActividadCard(a: a, onTap: () => abrirProp(a.cuentaId)),
          SizedBox(height: context.s.space.sm),
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
              onPressed: () => context.go('/propiedades'),
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
}

/// Card de un pendiente: propiedad, tipo, fecha, monto y CTA. El borde tiñe
/// por urgencia.
class _ActividadCard extends StatelessWidget {
  final ActividadItem a;
  final VoidCallback onTap;

  const _ActividadCard({required this.a, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final pagar = a.accion == 'pagar' && a.monto > 0;
    // Borde por urgencia: urgente (rojo), próximo (ámbar), futuro (verde).
    final borde = switch (a.urgencia) {
      'urgent' => tone.danger,
      'upcoming' => tone.warning,
      _ => tone.positive,
    };
    return SPressable(
      onTap: onTap,
      borderRadius: t.radius.lgBorder,
      hoverLift: true,
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
                    style: t.text.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                  SizedBox(height: t.space.xxs),
                  Row(
                    children: [
                      SBadge(
                        label: a.tipo,
                        tone: a.urgencia == 'urgent'
                            ? SBadgeTone.pending
                            : SBadgeTone.neutral,
                      ),
                      SizedBox(width: t.space.xxs),
                      Text(
                        a.categoria == 'patrimonio'
                            ? 'Patrimonio'
                            : 'En adquisición',
                        style: t.text.overline.copyWith(
                          color: tone.fgSubtle,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: t.space.xxs),
                  Text(
                    a.fecha != null ? formatDate(a.fecha) : 'Próximamente',
                    style: t.text.caption.copyWith(color: tone.fgMuted),
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
                    style: t.text.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                SizedBox(height: t.space.xxs),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: t.space.md,
                    vertical: t.space.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: pagar ? tone.primary : tone.surfaceAlt,
                    borderRadius: t.radius.fullBorder,
                  ),
                  child: Text(
                    pagar ? 'Pagar' : 'Ver',
                    style: t.text.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: pagar ? tone.onPrimary : tone.fgMuted,
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
            SizedBox(height: 24),
            SSkeleton(height: 108, radius: kPortalRadiusCard),
            SizedBox(height: 24),
            SSkeleton(height: 88, radius: kPortalRadiusCard),
            SizedBox(height: 12),
            SSkeleton(height: 88, radius: kPortalRadiusCard),
            SizedBox(height: 12),
            SSkeleton(height: 88, radius: kPortalRadiusCard),
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

        // Una sola columna, igual que en móvil: accesos, pendientes y
        // propiedades. Las dos columnas del portal existían para acomodar el
        // hero de patrimonio; sin él, partir el ancho solo alejaba lo urgente
        // de lo que se mira primero.
        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 24, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _welcome(data, ultimoAcceso),
              SizedBox(height: context.s.space.lg),
              QuickAccessGrid(
                items: _accesosRapidos(
                  context,
                  pendientes: data.actividad.length,
                ),
              ),
              if (sinPropiedades)
                _portafolioVacio()
              else ...[
                SizedBox(height: context.s.space.lg),
                _contenido(context, data, misPropiedades),
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

  // ── Pendientes + Mis propiedades ──────────────────────────────────────────
  Widget _contenido(
    BuildContext context,
    ClienteResumen data,
    List<PropiedadCard> misPropiedades,
  ) {
    final total = data.actividad.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tituloSeccion(
          context,
          total > 0 ? 'Pendientes ($total)' : 'Pendientes',
          verTodos: total > _actividadMax
              ? () => context.go('/propiedades')
              : null,
        ),
        const SizedBox(height: 12),
        ..._actividad(context, data),
        if (misPropiedades.isNotEmpty) ...[
          const SizedBox(height: 24),
          _tituloSeccion(
            context,
            'Mis propiedades',
            verTodos: misPropiedades.length > 3
                ? () => context.go('/propiedades')
                : null,
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
        ],
      ],
    );
  }

  /// Título de sección con un "Ver todos" opcional a la derecha.
  Widget _tituloSeccion(
    BuildContext context,
    String texto, {
    VoidCallback? verTodos,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(texto, style: portalText(size: 15, weight: FontWeight.w600)),
        if (verTodos != null)
          TextButton(
            onPressed: verTodos,
            child: Text(
              'Ver todos',
              style: context.s.text.label.copyWith(
                fontWeight: FontWeight.w600,
                color: context.s.color.primaryHover,
              ),
            ),
          ),
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
      for (var k = 0; k < data.actividad.length && k < _actividadMax; k++) ...[
        if (k > 0) const SizedBox(height: 12),
        _PortalActividadCard(
          a: data.actividad[k],
          onTap: () => context.push('/propiedad/${data.actividad[k].cuentaId}'),
        ),
      ],
    ];
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
