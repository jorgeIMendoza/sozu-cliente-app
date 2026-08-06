import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/home/providers/home_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';

/// Notificaciones del cliente: lista, marcar leída, marcar todas.
class NotificacionesScreen extends ConsumerStatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  ConsumerState<NotificacionesScreen> createState() =>
      _NotificacionesScreenState();
}

class _NotificacionesScreenState extends ConsumerState<NotificacionesScreen> {
  /// Filtro "Sin leer" - tabs Todas / Sin leer, compartido por la vista portal
  /// (web ≥1024) y la vista móvil/angosta.
  bool _soloNoLeidas = false;

  Future<void> _marcar({String? action, int? id}) =>
      marcarNotificacion(ref, action: action, id: id);

  void _abrir(Notificacion n) => abrirNotificacion(context, ref, n);

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final portal = isPortalMode(context);
    final notif = ref.watch(notificationsProvider);
    final noLeidas = notif.valueOrNull?.noLeidas ?? 0;

    return Scaffold(
      // Modo portal: el shell ya pinta el título; sin AppBar propio.
      backgroundColor: portal ? Colors.transparent : null,
      appBar: portal
          ? null
          : AppBar(
              title: const Text('Notificaciones'),
              // Flecha siempre presente: si no hay stack (se llegó por deep link o
              // notificación en frío) regresa a Inicio en lugar de desaparecer.
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/inicio'),
              ),
              actions: [
                if (noLeidas > 0)
                  TextButton(
                    onPressed: () => _marcar(action: 'marcar_todas'),
                    child: Text(
                      'Marcar todas',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: tone.primaryHover,
                      ),
                    ),
                  ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          try {
            await ref.read(notificationsProvider.future);
          } catch (_) {}
        },
        child: notif.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SSkeleton(height: 18),
                    SizedBox(height: 8),
                    SSkeleton(width: 200, height: 14),
                  ],
                ),
              ),
            ],
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SErrorState(
                title: 'No pudimos cargar tus notificaciones',
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
            ],
          ),
          data: (data) {
            if (portal) return _portalVista(data);
            return _movilVista(data);
          },
        ),
      ),
    );
  }

  /// Vista móvil / angosta: tabs Todas / Sin leer y filas con botón X.
  Widget _movilVista(ClienteNotificaciones data) {
    final total = data.notificaciones.length;
    final noLeidas = data.noLeidas;
    final ordenadas = ordenarNotificaciones(data.notificaciones);
    final lista = _soloNoLeidas
        ? ordenadas.where((n) => !n.leida).toList()
        : ordenadas;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _movilTabs(total, noLeidas),
        const SizedBox(height: 16),
        if (lista.isEmpty)
          _movilVacio()
        else
          for (final n in lista) ...[
            _NotifRow(
              n: n,
              onTap: () => _abrir(n),
              onDismiss: () => _marcar(action: 'descartar', id: n.id),
              onToggleLeida: () => alternarLeidaNotificacion(ref, n),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  /// Tabs segmentadas Todas / Sin leer para la vista móvil (mismo conteo que el
  /// portal); espejo del control segmentado de NotificationSheet.
  Widget _movilTabs(int total, int noLeidas) {
    final tone = context.s.color;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tone.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _movilTab(
              'Todas ($total)',
              !_soloNoLeidas,
              () => setState(() => _soloNoLeidas = false),
              tone,
            ),
          ),
          Expanded(
            child: _movilTab(
              'Sin leer ($noLeidas)',
              _soloNoLeidas,
              () => setState(() => _soloNoLeidas = true),
              tone,
            ),
          ),
        ],
      ),
    );
  }

  Widget _movilTab(
    String label,
    bool active,
    VoidCallback onTap,
    SozuColorRoles tone,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        // tab de filtro: cambia fondo y sombra, no se mueve -> `fast` +
        // `standard`.
        duration: context.s.motion.fast,
        curve: context.s.motion.standard,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? tone.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? tone.fg : tone.fgMuted,
          ),
        ),
      ),
    );
  }

  /// Estado vacío móvil - mismos textos/icono que `_portalVacio` (campana
  /// `notifications_outlined`; textos según el filtro activo).
  Widget _movilVacio() {
    final tone = context.s.color;
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tone.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              size: 30,
              color: SozuBrand.green600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _soloNoLeidas
                ? 'Sin notificaciones nuevas'
                : 'No tienes notificaciones',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tone.fg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _soloNoLeidas
                ? 'Ya leíste todas tus notificaciones.'
                : 'Aquí verás avisos importantes sobre tus propiedades.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: tone.fgMuted),
          ),
        ],
      ),
    );
  }

  /// Vista modo portal (web >=1024): filas anchas con borde primary si no están
  /// leídas. Solo capa visual: mismas acciones que [_movilVista].
  Widget _portalVista(ClienteNotificaciones data) {
    final total = data.notificaciones.length;
    final noLeidas = data.noLeidas;
    final ordenadas = ordenarNotificaciones(data.notificaciones);
    final lista = _soloNoLeidas
        ? ordenadas.where((n) => !n.leida).toList()
        : ordenadas;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 24, bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  noLeidas > 0 ? 'Tienes $noLeidas sin leer.' : 'Estás al día.',
                  style: portalText(
                    size: 12,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ),
              if (noLeidas > 0)
                SHoverBuilder(
                  builder: (context, hovered) => GestureDetector(
                    onTap: () => _marcar(action: 'marcar_todas'),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check,
                          size: 14,
                          color: PortalColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Marcar todas como leídas',
                          style:
                              portalText(
                                size: 12,
                                weight: FontWeight.w500,
                                color: PortalColors.primary,
                              ).copyWith(
                                decoration: hovered
                                    ? TextDecoration.underline
                                    : null,
                                decorationColor: PortalColors.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _portalTab(
                'Todas ($total)',
                !_soloNoLeidas,
                () => setState(() => _soloNoLeidas = false),
              ),
              const SizedBox(width: 8),
              _portalTab(
                'Sin leer ($noLeidas)',
                _soloNoLeidas,
                () => setState(() => _soloNoLeidas = true),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (lista.isEmpty)
            _portalVacio()
          else
            for (final n in lista) ...[
              _portalNotifRow(n),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  /// Tab de filtro del portal: activa con fondo oscuro (foreground) y texto
  /// blanco; inactiva transparente con borde.
  Widget _portalTab(String label, bool active, VoidCallback onTap) {
    return SHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          // tab de filtro: cambia fondo y borde, no se mueve -> `fast` +
          // `standard`.
          duration: context.s.motion.fast,
          curve: context.s.motion.standard,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? PortalColors.foreground : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? PortalColors.foreground
                  : hovered
                  ? PortalColors.mutedForeground
                  : PortalColors.border,
            ),
          ),
          child: Text(
            label,
            style: portalText(
              size: 12,
              weight: FontWeight.w500,
              color: active ? Colors.white : PortalColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }

  Widget _portalVacio() {
    return SCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: PortalColors.muted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_outlined,
                size: 20,
                color: PortalColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _soloNoLeidas
                  ? 'Sin notificaciones nuevas'
                  : 'No tienes notificaciones',
              style: portalText(size: 13, weight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _soloNoLeidas
                  ? 'Ya leíste todas tus notificaciones.'
                  : 'Aquí verás avisos importantes sobre tus propiedades.',
              textAlign: TextAlign.center,
              style: portalText(size: 11, color: PortalColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }

  /// Fila ancha del portal: borde izquierdo verde + punto cuando no está
  /// leída; tocarla la marca como leída (misma acción que móvil).
  Widget _portalNotifRow(Notificacion n) {
    final (iconBg, iconFg, tipoIcon) = _tipoInfoPortal(n);
    // El glifo lo define la categoría; el color sigue por tipo/severidad.
    final icon = _iconoCategoria(n.categoria) ?? tipoIcon;
    final etiqueta = _etiquetaAccion(n);
    return SHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: () => _abrir(n),
        behavior: HitTestBehavior.opaque,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: hovered ? PortalColors.mutedSoft30 : PortalColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PortalColors.border),
          ),
          child: Stack(
            children: [
              if (!n.leida)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: PortalColors.primary),
                ),
              Padding(
                // pr amplio: reserva el hueco de los botones de la esquina
                // superior derecha (toggle leída + X descartar) para que el
                // texto no colisione con ellos.
                padding: const EdgeInsets.fromLTRB(16, 16, 74, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 16, color: iconFg),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  n.titulo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: portalText(
                                    size: 14,
                                    weight: n.leida
                                        ? FontWeight.w600
                                        : FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!n.leida) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(top: 5),
                                  decoration: const BoxDecoration(
                                    color: PortalColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            n.descripcion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: portalText(
                              size: 12,
                              color: PortalColors.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _fechaRelativa(n.fecha),
                                style: portalText(
                                  size: 10,
                                  color: PortalColors.mutedForeground,
                                ),
                              ),
                              if (etiqueta != null)
                                Flexible(
                                  child: Text(
                                    '$etiqueta →',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: portalText(
                                      size: 11,
                                      weight: FontWeight.w500,
                                      color: iconFg,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Botones de la esquina superior derecha (top-3 right-3 del
              // portal): toggle leída/no-leída + X descartar. Ninguno dispara el
              // onTap de la fila.
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToggleLeidaBtn(
                      n: n,
                      onTap: () => alternarLeidaNotificacion(ref, n),
                    ),
                    const SizedBox(width: 2),
                    SHoverBuilder(
                      builder: (context, xHovered) => Tooltip(
                        message: 'Descartar',
                        child: GestureDetector(
                          onTap: () => _marcar(action: 'descartar', id: n.id),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: xHovered
                                  ? PortalColors.muted
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: PortalColors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
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

class _NotifRow extends StatelessWidget {
  final Notificacion n;
  final VoidCallback? onTap;

  /// Acción `descartar` (X arriba a la derecha). Espejo del `_portalNotifRow`:
  /// en móvil también debe poder descartarse una notificación.
  final VoidCallback? onDismiss;

  /// Toggle leída ↔ no-leída (icono junto a la X). Espejo del `_portalNotifRow`.
  final VoidCallback? onToggleLeida;

  const _NotifRow({
    required this.n,
    this.onTap,
    this.onDismiss,
    this.onToggleLeida,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final (color, tipoIcon) = switch (n.tipo) {
      'urgente' => (tone.danger, Icons.error_outline),
      'accionable' => (SozuAmber.strong, Icons.flash_on_outlined),
      'exito' => (SozuBrand.green600, Icons.check_circle_outline),
      _ => (SozuBrand.green600, Icons.info_outline),
    };
    // El glifo lo define la categoría; el color sigue por tipo/severidad.
    final icon = _iconoCategoria(n.categoria) ?? tipoIcon;
    final etiqueta = _etiquetaAccion(n);
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: n.leida ? 0.7 : 1,
            child: SCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: tone.fg,
                                ),
                              ),
                            ),
                            if (!n.leida)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: SozuBrand.green500,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            // Reserva el hueco de los botones (top-right) para
                            // que el título/punto no colisionen con ellos
                            // (toggle leída + X descartar).
                            if (onDismiss != null || onToggleLeida != null)
                              SizedBox(
                                width:
                                    (onDismiss != null ? 28.0 : 0.0) +
                                    (onToggleLeida != null ? 28.0 : 0.0),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          n.descripcion,
                          style: TextStyle(fontSize: 12, color: tone.fgMuted),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fechaRelativa(n.fecha),
                              style: TextStyle(
                                fontSize: 11,
                                color: tone.fgSubtle,
                              ),
                            ),
                            if (etiqueta != null)
                              Flexible(
                                child: Text(
                                  '$etiqueta →',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
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
        ),
        // Botones top-right: toggle leída/no-leída + X descartar. Mismo
        // posicionamiento y acciones que en la vista portal.
        if (onDismiss != null || onToggleLeida != null)
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onToggleLeida != null)
                  _ToggleLeidaBtn(
                    n: n,
                    onTap: onToggleLeida!,
                    iconSize: 16,
                    color: tone.fgSubtle,
                  ),
                if (onDismiss != null)
                  Tooltip(
                    message: 'Descartar',
                    child: GestureDetector(
                      onTap: onDismiss,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: tone.fgSubtle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers de notificaciones (compartidos por vista móvil y portal)
// ═══════════════════════════════════════════════════════════════════════════

const _mesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Fecha relativa estilo portal: "Ahora" / "Hace 5 min" / "Hace 2 h" /
/// "Hace 3 d"; a partir de 7 días, fecha corta "15 jul".
String _fechaRelativa(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return formatDate(iso);
  final diff = DateTime.now().difference(d);
  if (diff.isNegative) return 'Ahora';
  final min = diff.inMinutes;
  if (min < 1) return 'Ahora';
  if (min < 60) return 'Hace $min min';
  final h = diff.inHours;
  if (h < 24) return 'Hace $h h';
  final dias = diff.inDays;
  if (dias < 7) return 'Hace $dias d';
  return '${d.day} ${_mesesCortos[d.month - 1]}';
}

/// Prioridad de orden por tipo (0 = más arriba), espejo del portal
/// (urgente > accionable > informativa > éxito).
int _prioridadTipo(String tipo) => switch (tipo) {
  'urgente' => 0,
  'accionable' => 1,
  'exito' => 3,
  _ => 2,
};

/// Ordena por prioridad de tipo y luego por fecha descendente.
List<Notificacion> ordenarNotificaciones(List<Notificacion> src) {
  final l = [...src];
  l.sort((a, b) {
    final p = _prioridadTipo(a.tipo).compareTo(_prioridadTipo(b.tipo));
    if (p != 0) return p;
    final da = DateTime.tryParse(a.fecha ?? '')?.millisecondsSinceEpoch ?? 0;
    final db = DateTime.tryParse(b.fecha ?? '')?.millisecondsSinceEpoch ?? 0;
    return db.compareTo(da);
  });
  return l;
}

/// Ejecuta una acción del endpoint de notificaciones (`marcar_leida`,
/// `marcar_todas`, `descartar`) y refresca el provider. Compartida por la
/// pantalla y por la vista previa de la campana ([NotificationBell]).
Future<void> marcarNotificacion(
  WidgetRef ref, {
  String? action,
  int? id,
}) async {
  final port = ref.read(homePortProvider);
  try {
    switch (action) {
      case 'marcar_leida':
        await port.markNotificationRead(id!);
      case 'marcar_todas':
        await port.markAllNotificationsRead();
      case 'descartar':
        await port.dismissNotification(id!);
      default:
        break; // sin acción: solo refrescar
    }
  } catch (_) {}
  ref.invalidate(notificationsProvider);
}

/// Marca una notificación como NO leída (revierte el "leído") y refresca el
/// provider para actualizar el conteo. Análoga a [marcarNotificacion]; espejo
/// de `useMarkAsUnread` del portal.
Future<void> marcarNoLeidaNotificacion(WidgetRef ref, int id) async {
  try {
    await ref.read(homePortProvider).markNotificationUnread(id);
  } catch (_) {}
  ref.invalidate(notificationsProvider);
}

/// Alterna el estado leída ↔ no-leída de una notificación: si está leída la
/// marca como NO leída (`marcar_no_leida`); si no, como leída (`marcar_leida`).
/// Réplica del botón toggle de NotificationPopover/NotificationSheet.
Future<void> alternarLeidaNotificacion(WidgetRef ref, Notificacion n) {
  return n.leida
      ? marcarNoLeidaNotificacion(ref, n.id)
      : marcarNotificacion(ref, action: 'marcar_leida', id: n.id);
}

/// Al tocar una notificación: la marca como leída (si no lo está) y navega a
/// la ruta del app correspondiente a su `url_accion`. Si la URL no mapea a
/// ninguna ruta conocida, solo marca leída sin navegar (no rompe).
void abrirNotificacion(BuildContext context, WidgetRef ref, Notificacion n) {
  if (!n.leida) marcarNotificacion(ref, action: 'marcar_leida', id: n.id);
  final ruta = _rutaAppDesdeUrl(n.urlAccion);
  if (ruta != null) context.go(ruta);
}

/// (fondo del icono, color del icono, icono) por tipo - typeInfo del portal.
/// Compartida por la fila del portal y la vista previa de la campana.
(Color, Color, IconData) _tipoInfoPortal(Notificacion n) => switch (n.tipo) {
  'urgente' => (
    PortalColors.destructiveSoft15,
    PortalColors.destructive,
    Icons.error_outline,
  ),
  'accionable' => (
    PortalColors.warningSoft15,
    PortalColors.warning,
    Icons.flash_on_outlined,
  ),
  'exito' => (
    PortalColors.primarySoft15,
    PortalColors.primary,
    Icons.check_circle_outline,
  ),
  _ => (PortalColors.primarySoft15, PortalColors.primary, Icons.info_outline),
};

/// Botón toggle leída · no-leída de una fila de notificación. Va junto al botón
/// X de descartar y no dispara el onTap de la fila.
class _ToggleLeidaBtn extends StatelessWidget {
  final Notificacion n;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color color;

  const _ToggleLeidaBtn({
    required this.n,
    required this.onTap,
    this.size = 28,
    this.iconSize = 14,
    this.color = PortalColors.mutedForeground,
  });

  @override
  Widget build(BuildContext context) {
    final leida = n.leida;
    return SHoverBuilder(
      builder: (context, hovered) => Tooltip(
        message: leida ? 'Marcar como no leída' : 'Marcar como leída',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hovered ? PortalColors.muted : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              leida
                  ? Icons.mark_email_unread_outlined
                  : Icons.mark_email_read_outlined,
              size: iconSize,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila compacta de la vista previa de la campana (popover web / bottom-sheet
/// móvil). [onTap] marca leída, navega y cierra; la X dispara [onDismiss].
class NotifPreviewRow extends StatelessWidget {
  final Notificacion n;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  /// Toggle leída ↔ no-leída (icono junto a la X). Espejo del portal.
  final VoidCallback? onToggleLeida;

  const NotifPreviewRow({
    super.key,
    required this.n,
    required this.onTap,
    required this.onDismiss,
    this.onToggleLeida,
  });

  @override
  Widget build(BuildContext context) {
    final (iconBg, iconFg, tipoIcon) = _tipoInfoPortal(n);
    final icon = _iconoCategoria(n.categoria) ?? tipoIcon;
    return Stack(
      children: [
        SHoverBuilder(
          builder: (context, hovered) => GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: BoxDecoration(
                color: hovered ? PortalColors.mutedSoft30 : Colors.transparent,
                border: const Border(
                  bottom: BorderSide(color: PortalColors.borderSoft),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                onToggleLeida != null ? 78 : 48,
                12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: iconFg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                n.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: portalText(
                                  size: 12,
                                  weight: n.leida
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            if (!n.leida) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: const BoxDecoration(
                                  color: PortalColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          n.descripcion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: portalText(
                            size: 11,
                            color: PortalColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fechaRelativa(n.fecha),
                          style: portalText(
                            size: 10,
                            color: PortalColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onToggleLeida != null)
                _ToggleLeidaBtn(n: n, onTap: onToggleLeida!, size: 26),
              if (onToggleLeida != null) const SizedBox(width: 2),
              SHoverBuilder(
                builder: (context, xHovered) => Tooltip(
                  message: 'Descartar',
                  child: GestureDetector(
                    onTap: onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: xHovered
                            ? PortalColors.muted
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: PortalColors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Icono Material según la `categoria` (glifo). El color sigue por
/// tipo/severidad. Devuelve null si la categoría es desconocida, para caer al
/// icono por tipo. Acepta los valores de BD (español) y los alias del portal.
IconData? _iconoCategoria(String? categoria) {
  switch ((categoria ?? '').toLowerCase()) {
    case 'pagos':
    case 'payments':
    case 'creditcard':
      return Icons.credit_card_outlined; // CreditCard
    case 'documentos':
    case 'documents':
    case 'filetext':
      return Icons.description_outlined; // FileText
    case 'mantenimiento':
    case 'maintenance':
    case 'wrench':
      return Icons.build_outlined; // Wrench
    case 'construccion':
    case 'construction':
    case 'hardhat':
      return Icons.engineering_outlined; // HardHat
    case 'reventa':
    case 'resale':
    case 'trendingup':
      return Icons.trending_up; // TrendingUp
    case 'entrega':
    case 'delivery':
    case 'packagecheck':
      return Icons.inventory_2_outlined; // PackageCheck
    default:
      return null;
  }
}

/// Mapea la `url_accion` del portal a una ruta del router del app. Devuelve
/// null si no hay mapeo conocido (se ignora sin romper la navegación).
String? _rutaAppDesdeUrl(String? url) {
  if (url == null) return null;
  var u = url.trim();
  if (u.isEmpty) return null;
  // Tolerar URLs absolutas del portal (con prefijo del admin).
  const prefijo = '/admin/portal-cliente';
  if (u.startsWith(prefijo)) u = u.substring(prefijo.length);
  // Quitar query/hash.
  final corte = u.indexOf(RegExp(r'[?#]'));
  if (corte != -1) u = u.substring(0, corte);
  if (u.isEmpty || u == '/') return '/inicio';

  // Detalle de propiedad: el portal usa /propiedades/:id; el app, /propiedad/:id.
  final prop = RegExp(r'^/propiedades?/([^/]+)').firstMatch(u);
  if (prop != null) return '/propiedad/${prop.group(1)}';

  // Detalle de producto: /productos/:id (misma ruta en el app).
  final prod = RegExp(r'^/productos/([^/]+)').firstMatch(u);
  if (prod != null) return '/productos/${prod.group(1)}';

  // Rutas simples soportadas por el router del app.
  const directas = {
    '/pagos',
    '/estado-cuenta',
    '/documentos',
    '/expediente',
    '/notificaciones',
    '/perfil',
    '/inicio',
    '/propiedades',
    '/mantenimientos',
    // Se quedan aunque ya no sean rutas propias: el router las redirige al
    // filtro correspondiente de /propiedades, y hay avisos ya enviados que
    // apuntan ahí. Quitarlas los dejaría sin enlace.
    '/adquisicion',
    '/patrimonio',
    '/productos',
  };
  final segs = u.split('/').where((s) => s.isNotEmpty);
  if (segs.isEmpty) return null;
  final base = '/${segs.first}';
  return directas.contains(base) ? base : null;
}

/// Etiqueta de acción a mostrar al pie ("{etiqueta} →"). Usa
/// `etiqueta_accion`; si viene vacía pero la URL mapea, cae a "Ver". Si no hay
/// etiqueta ni ruta mapeable, devuelve null (no se pinta enlace).
String? _etiquetaAccion(Notificacion n) {
  final e = n.etiquetaAccion?.trim();
  if (e != null && e.isNotEmpty) return e;
  if (_rutaAppDesdeUrl(n.urlAccion) != null) return 'Ver';
  return null;
}
