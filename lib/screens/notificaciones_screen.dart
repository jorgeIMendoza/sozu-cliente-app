import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';
import '../widgets/portal_widgets.dart';

/// Notificaciones del cliente: lista, marcar leída, marcar todas.
class NotificacionesScreen extends ConsumerStatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  ConsumerState<NotificacionesScreen> createState() =>
      _NotificacionesScreenState();
}

class _NotificacionesScreenState extends ConsumerState<NotificacionesScreen> {
  /// Filtro "Sin leer" — solo lo usa la vista portal (web ≥1024).
  bool _soloNoLeidas = false;

  Future<void> _marcar({String? action, int? id}) async {
    try {
      await fetchClienteNotificaciones(action: action, id: id);
    } catch (_) {}
    ref.invalidate(clienteNotificacionesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final portal = isPortalMode(context);
    final notif = ref.watch(clienteNotificacionesProvider);
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
              child: Text('Marcar todas',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: tone.primaryDark)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clienteNotificacionesProvider);
          try {
            await ref.read(clienteNotificacionesProvider.future);
          } catch (_) {}
        },
        child: notif.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 18),
                    SizedBox(height: 8),
                    Skeleton(width: 200, height: 14),
                  ],
                ),
              ),
            ],
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorCard(
                title: 'No pudimos cargar tus notificaciones',
                onRetry: () => ref.invalidate(clienteNotificacionesProvider),
              ),
            ],
          ),
          data: (data) {
            if (portal) return _portalVista(data);
            if (data.notificaciones.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 60),
                  Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                            color: tone.primarySoft, shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_off_outlined,
                            size: 30, color: SozuColors.emerald600),
                      ),
                      const SizedBox(height: 16),
                      Text('Sin notificaciones',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: tone.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Aquí verás tus avisos SOZU.',
                          style: TextStyle(
                              fontSize: 14, color: tone.textSecondary)),
                    ],
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                for (final n in data.notificaciones) ...[
                  _NotifRow(
                    n: n,
                    onTap: n.leida
                        ? null
                        : () => _marcar(action: 'marcar_leida', id: n.id),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODO PORTAL (web ≥1024): réplica de la lista de Notificaciones del Portal
  // del Cliente (ClienteNotificaciones.tsx): subtítulo + "Marcar todas como
  // leídas", tabs Todas / Sin leer y filas anchas con borde primary si no
  // están leídas. Solo capa visual: mismas acciones (marcar leída / todas).
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _portalVista(ClienteNotificaciones data) {
    final total = data.notificaciones.length;
    final noLeidas = data.noLeidas;
    final lista = _soloNoLeidas
        ? data.notificaciones.where((n) => !n.leida).toList()
        : data.notificaciones;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  noLeidas > 0
                      ? 'Tienes $noLeidas sin leer.'
                      : 'Estás al día.',
                  style: portalText(
                    size: 12,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ),
              if (noLeidas > 0)
                PortalHoverBuilder(
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
                          style: portalText(
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
          const SizedBox(height: 16),
          Row(
            children: [
              _portalTab('Todas ($total)', !_soloNoLeidas,
                  () => setState(() => _soloNoLeidas = false)),
              const SizedBox(width: 8),
              _portalTab('Sin leer ($noLeidas)', _soloNoLeidas,
                  () => setState(() => _soloNoLeidas = true)),
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
    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
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
    return PortalCard(
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
              style: portalText(
                size: 11,
                color: PortalColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// (fondo del icono, color del icono, icono) por tipo — typeInfo del portal.
  (Color, Color, IconData) _portalTipo(Notificacion n) => switch (n.tipo) {
    'urgente' => (
      PortalColors.destructiveSoft10,
      PortalColors.destructive,
      Icons.error_outline,
    ),
    'accionable' => (
      PortalColors.warningSoft10,
      PortalColors.warning,
      Icons.flash_on_outlined,
    ),
    'exito' => (
      PortalColors.primarySoft10,
      PortalColors.primary,
      Icons.check_circle_outline,
    ),
    _ => (
      PortalColors.primarySoft10,
      PortalColors.primary,
      Icons.info_outline,
    ),
  };

  /// Fila ancha del portal: borde izquierdo verde + punto cuando no está
  /// leída; tocarla la marca como leída (misma acción que móvil).
  Widget _portalNotifRow(Notificacion n) {
    final (iconBg, iconFg, icon) = _portalTipo(n);
    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: n.leida ? null : () => _marcar(action: 'marcar_leida', id: n.id),
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
                padding: const EdgeInsets.all(16),
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
                                    size: 13,
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
                          Text(
                            formatDate(n.fecha),
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

  const _NotifRow({required this.n, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final (color, icon) = switch (n.tipo) {
      'urgente' => (tone.negative, Icons.error_outline),
      'accionable' => (SozuColors.amber600, Icons.flash_on_outlined),
      'exito' => (SozuColors.emerald600, Icons.check_circle_outline),
      _ => (SozuColors.emerald600, Icons.info_outline),
    };
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: n.leida ? 0.7 : 1,
        child: AppCard(
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
                          child: Text(n.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: tone.textPrimary)),
                        ),
                        if (!n.leida)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: SozuColors.emerald500,
                                shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(n.descripcion,
                        style: TextStyle(
                            fontSize: 12, color: tone.textSecondary)),
                    const SizedBox(height: 4),
                    Text(formatDate(n.fecha),
                        style:
                            TextStyle(fontSize: 11, color: tone.textMuted)),
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
