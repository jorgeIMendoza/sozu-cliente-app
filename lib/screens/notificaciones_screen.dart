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

  /// Al tocar una notificación: la marca como leída (si no lo está) y navega a
  /// la ruta del app correspondiente a su `url_accion`. Si la URL no mapea a
  /// ninguna ruta conocida, solo marca leída sin navegar (no rompe).
  void _abrir(Notificacion n) {
    if (!n.leida) _marcar(action: 'marcar_leida', id: n.id);
    final ruta = _rutaAppDesdeUrl(n.urlAccion);
    if (ruta != null) context.go(ruta);
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
                for (final n in _ordenadas(data.notificaciones)) ...[
                  _NotifRow(n: n, onTap: () => _abrir(n)),
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
    final ordenadas = _ordenadas(data.notificaciones);
    final lista = _soloNoLeidas
        ? ordenadas.where((n) => !n.leida).toList()
        : ordenadas;

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
    final (iconBg, iconFg, tipoIcon) = _portalTipo(n);
    // El glifo lo define la categoría; el color sigue por tipo/severidad.
    final icon = _iconoCategoria(n.categoria) ?? tipoIcon;
    final etiqueta = _etiquetaAccion(n);
    return PortalHoverBuilder(
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
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
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
    final (color, tipoIcon) = switch (n.tipo) {
      'urgente' => (tone.negative, Icons.error_outline),
      'accionable' => (SozuColors.amber600, Icons.flash_on_outlined),
      'exito' => (SozuColors.emerald600, Icons.check_circle_outline),
      _ => (SozuColors.emerald600, Icons.info_outline),
    };
    // El glifo lo define la categoría; el color sigue por tipo/severidad.
    final icon = _iconoCategoria(n.categoria) ?? tipoIcon;
    final etiqueta = _etiquetaAccion(n);
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
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fechaRelativa(n.fecha),
                            style: TextStyle(
                                fontSize: 11, color: tone.textMuted)),
                        if (etiqueta != null)
                          Flexible(
                            child: Text('$etiqueta →',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: color)),
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

// ═══════════════════════════════════════════════════════════════════════════
// Helpers de notificaciones (compartidos por vista móvil y portal)
// ═══════════════════════════════════════════════════════════════════════════

const _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
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
List<Notificacion> _ordenadas(List<Notificacion> src) {
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
