import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/portal_theme.dart';
import '../core/theme.dart' show sozuLightTheme;
import '../core/version.dart';
import '../data/models.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/impersonation_provider.dart';
import 'notification_bell.dart';
import 'portal_shell_widgets.dart';

/// Shell web "modo portal": réplica del layout del Portal del Cliente de
/// sozu-admin (docs/web_portal_spec/shell.md) — sidebar blanca fija de 256px
/// + topbar de 64px + contenido con fondo #F9FAFB y max-width 1280 centrado.
///
/// Solo se pinta con [isPortalMode] (web ≥1024px); en móvil/angosto
/// [PortalShellWrapper] devuelve el hijo intacto y el layout actual no cambia.

/// Ítems del menú lateral (mismo orden y rutas que el portal web).
class _PortalNavItemData {
  final String label;
  final String route;
  final IconData icon;

  const _PortalNavItemData(this.label, this.route, this.icon);
}

const List<_PortalNavItemData> _portalNavItems = [
  _PortalNavItemData('Inicio', '/inicio', Icons.home_outlined),
  _PortalNavItemData(
    'En adquisición',
    '/adquisicion',
    Icons.shopping_bag_outlined,
  ),
  _PortalNavItemData(
    'Patrimonio',
    '/patrimonio',
    Icons.account_balance_wallet_outlined,
  ),
  _PortalNavItemData('Productos', '/productos', Icons.inventory_2_outlined),
  _PortalNavItemData('Pagos', '/pagos', Icons.credit_card_outlined),
  _PortalNavItemData(
    'Estado de cuenta',
    '/estado-cuenta',
    Icons.bar_chart_outlined,
  ),
  _PortalNavItemData('Documentos', '/documentos', Icons.description_outlined),
  _PortalNavItemData(
    'Notificaciones',
    '/notificaciones',
    Icons.notifications_outlined,
  ),
  _PortalNavItemData('Perfil', '/perfil', Icons.person_outline),
];

/// Mapa de la `vista_front_end` del portal (lo que devuelve la edge function
/// `cliente-menu`) a la ruta interna de la app + su icono Material equivalente
/// del icono lucide que usa el portal (ROUTE_ICON de portal-nav-data.ts).
/// Una ruta del portal sin entrada aquí no la sabe pintar la app y se omite.
const Map<String, ({String route, IconData icon})> _portalRouteMap = {
  '/admin/portal-cliente/inicio': (route: '/inicio', icon: Icons.home_outlined),
  '/admin/portal-cliente/en-adquisicion': (
    route: '/adquisicion',
    icon: Icons.shopping_bag_outlined,
  ),
  // El portal puede exponer "Propiedades" como único ítem; la app lo lleva a
  // su pantalla de adquisición.
  '/admin/portal-cliente/propiedades': (
    route: '/adquisicion',
    icon: Icons.shopping_bag_outlined,
  ),
  '/admin/portal-cliente/patrimonio': (
    route: '/patrimonio',
    icon: Icons.account_balance_wallet_outlined,
  ),
  '/admin/portal-cliente/productos': (
    route: '/productos',
    icon: Icons.inventory_2_outlined,
  ),
  '/admin/portal-cliente/pagos': (
    route: '/pagos',
    icon: Icons.credit_card_outlined,
  ),
  '/admin/portal-cliente/historial-pagos': (
    route: '/pagos',
    icon: Icons.credit_card_outlined,
  ),
  '/admin/portal-cliente/estado-de-cuenta': (
    route: '/estado-cuenta',
    icon: Icons.bar_chart_outlined,
  ),
  '/admin/portal-cliente/documentos': (
    route: '/documentos',
    icon: Icons.description_outlined,
  ),
  '/admin/portal-cliente/notificaciones': (
    route: '/notificaciones',
    icon: Icons.notifications_outlined,
  ),
  '/admin/portal-cliente/perfil': (
    route: '/perfil',
    icon: Icons.person_outline,
  ),
};

/// Resuelve los ítems del sidebar desde la lista de la BD (edge function
/// `cliente-menu`), con DEGRADACIÓN: si la lista es null/vacía (function no
/// desplegada aún, red, error) o ninguno mapea a una ruta de la app, cae a la
/// lista hardcodeada [_portalNavItems]. La etiqueta viene de la BD (`label`).
List<_PortalNavItemData> _resolvePortalNavItems(List<MenuItemDto>? dbItems) {
  if (dbItems == null || dbItems.isEmpty) return _portalNavItems;
  final out = <_PortalNavItemData>[];
  final vistas = <String>{};
  for (final it in dbItems) {
    final m = _portalRouteMap[it.route];
    if (m == null) continue; // ruta del portal no soportada por la app
    if (!vistas.add(m.route)) continue; // dedupe por ruta interna
    final label = it.label.trim().isEmpty ? m.route : it.label.trim();
    out.add(_PortalNavItemData(label, m.route, m.icon));
  }
  return out.isEmpty ? _portalNavItems : out;
}

/// Rutas internas permitidas por el menú de la BD, para filtrar la navegación
/// móvil (bottom nav) con el mismo criterio/degradación que el sidebar.
Set<String> portalAllowedRoutes(List<MenuItemDto>? dbItems) =>
    _resolvePortalNavItems(dbItems).map((e) => e.route).toSet();

/// Activo por prefijo de ruta; "Inicio" solo con match exacto (shell.md).
bool _isActive(String route, String path) {
  if (route == '/inicio') return path == '/inicio';
  return path == route || path.startsWith('$route/');
}

/// Iniciales para el avatar: 2 primeras palabras del nombre.
String _initials(String? nombre) {
  final parts = (nombre ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase());
  final s = parts.join();
  return s.isEmpty ? '?' : s;
}

/// Nombre truncado a 2 palabras y máx. 22 caracteres, como el portal
/// (PortalClienteLayout.tsx:20-24).
String _shortName(String? nombre) {
  final words = (nombre ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .join(' ');
  if (words.length <= 22) return words;
  return '${words.substring(0, 22)}…';
}

/// Envuelve una pantalla del cliente con [PortalShell] SOLO en modo portal;
/// en cualquier otro caso devuelve el hijo tal cual (layout móvil intacto).
class PortalShellWrapper extends StatelessWidget {
  final String currentPath;
  final Widget child;

  const PortalShellWrapper({
    super.key,
    required this.currentPath,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPortalMode(context)) return child;
    return PortalShell(currentPath: currentPath, child: child);
  }
}

/// Réplica del PortalClienteLayout del portal web.
class PortalShell extends ConsumerWidget {
  final String currentPath;
  final Widget child;

  const PortalShell({
    super.key,
    required this.currentPath,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // El portal es solo claro (.inmob-portal nunca aplica .dark): en modo
    // portal se fuerza el tema claro también en el contenido.
    return Theme(
      data: sozuLightTheme(),
      child: Material(
        color: PortalColors.background,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PortalSidebar(currentPath: currentPath),
            Expanded(
              child: Column(
                children: [
                  const _PortalShellTopBar(),
                  Expanded(
                    child: ColoredBox(
                      color: PortalColors.background,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: kPortalContentMaxWidth,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kPortalContentGutter,
                            ),
                            child: child,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar (shell.md §Sidebar)
// ---------------------------------------------------------------------------

class _PortalSidebar extends ConsumerWidget {
  final String currentPath;

  const _PortalSidebar({required this.currentPath});

  Future<void> _confirmarSalir(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: PortalColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      // Igual que el perfil: con biometría solo bloquea; si no, signOut real.
      await ref.read(authProvider).lockOrSignOut();
      // Limpia la impersonación y la caché de datos del cliente para que la
      // próxima sesión (otro cliente) no herede el resumen/perfil del anterior.
      ref.read(impersonationProvider).clear();
      invalidateAllData(ref);
      if (context.mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final imp = ref.watch(impersonationProvider);
    final impersonando = auth.isSuperAdmin && imp.active;
    final noLeidas =
        ref.watch(clienteNotificacionesProvider).valueOrNull?.noLeidas ?? 0;
    final nombre = auth.profile?.nombre ?? auth.profile?.email ?? 'Usuario';
    // Ítems del menú desde la BD (edge function `cliente-menu`), con
    // degradación a la lista hardcodeada si aún no responde.
    final navItems = _resolvePortalNavItems(
      ref.watch(clienteMenuProvider).valueOrNull,
    );

    return Container(
      width: kPortalSidebarWidth,
      decoration: const BoxDecoration(
        color: PortalColors.surface,
        border: Border(right: BorderSide(color: PortalColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Brand: logo + "PORTAL DEL CLIENTE" ----
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: PortalColors.borderSoft, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wordmark SOZU: el mismo PNG negro del logo que usa el login
                // (assets/sozu-logo-black.png), a 24px de alto como el portal.
                Image.asset(
                  'assets/sozu-logo-black.png',
                  height: 24,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 4),
                Text(
                  'PORTAL DEL CLIENTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                    color: PortalColors.mutedForeground,
                    fontFamilyFallback: kPortalFontFallback,
                  ),
                ),
              ],
            ),
          ),
          // ---- Navegación ----
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in navItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _PortalNavItem(
                        data: item,
                        active: _isActive(item.route, currentPath),
                        badge: item.route == '/notificaciones' ? noLeidas : 0,
                        onTap: () => context.go(item.route),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ---- Footer: usuario + acciones + versión ----
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: PortalColors.borderSoft, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (impersonando) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: PortalColors.primarySoft6,
                      borderRadius: BorderRadius.circular(kPortalRadiusSm),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: PortalColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Viendo como: ${imp.nombre ?? 'Cliente'}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: PortalColors.primary,
                              fontFamilyFallback: kPortalFontFallback,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                _SidebarProfileButton(
                  nombre: nombre,
                  rol: auth.profile?.rolNombre ?? 'Cliente',
                  onTap: () => context.go('/perfil'),
                ),
                const SizedBox(height: 4),
                if (impersonando)
                  Row(
                    children: [
                      Expanded(
                        child: _FooterActionButton(
                          icon: Icons.arrow_back,
                          label: 'Regresar',
                          destructive: false,
                          // Igual que "Salir" del banner actual: limpiar la
                          // impersonación regresa al selector de clientes.
                          onTap: () => ref.read(impersonationProvider).clear(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FooterActionButton(
                          icon: Icons.logout,
                          label: 'Cerrar sesión',
                          destructive: true,
                          onTap: () => _confirmarSalir(context, ref),
                        ),
                      ),
                    ],
                  )
                else
                  _FooterActionButton(
                    icon: Icons.logout,
                    label: 'Cerrar sesión',
                    destructive: true,
                    onTap: () => _confirmarSalir(context, ref),
                  ),
                const SizedBox(height: 8),
                Text(
                  appVersionLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: PortalColors.mutedForeground.withValues(alpha: .4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ítem del menú: 36px de alto, radio 6; activo con fondo #F2F9F6, texto e
/// icono #239F6D y barrita verde de 2px pegada al borde izquierdo; hover
/// suave #F8F9FA con texto #14161A.
class _PortalNavItem extends StatefulWidget {
  final _PortalNavItemData data;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  const _PortalNavItem({
    required this.data,
    required this.active,
    required this.badge,
    required this.onTap,
  });

  @override
  State<_PortalNavItem> createState() => _PortalNavItemState();
}

class _PortalNavItemState extends State<_PortalNavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final bg = active
        ? PortalColors.primarySoft6
        : _hover
        ? PortalColors.mutedHover
        : Colors.transparent;
    final fg = active
        ? PortalColors.primary
        : _hover
        ? PortalColors.foreground
        : PortalColors.mutedForeground;
    final iconColor = active
        ? PortalColors.primary
        : _hover
        ? PortalColors.foreground
        : PortalColors.mutedForeground.withValues(alpha: .6);

    return InkWell(
      onTap: widget.onTap,
      onHover: (h) => setState(() => _hover = h),
      borderRadius: BorderRadius.circular(kPortalRadiusSm),
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kPortalRadiusSm),
        ),
        child: Stack(
          children: [
            if (active)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  decoration: const BoxDecoration(
                    color: PortalColors.primary,
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              child: Row(
                children: [
                  Icon(widget.data.icon, size: 16, color: iconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.data.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: fg,
                        fontFamilyFallback: kPortalFontFallback,
                      ),
                    ),
                  ),
                  if (widget.badge > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: PortalColors.destructive,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      child: Text(
                        widget.badge > 9 ? '9+' : '${widget.badge}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de usuario del footer: avatar con iniciales + nombre + rol.
class _SidebarProfileButton extends StatefulWidget {
  final String nombre;
  final String rol;
  final VoidCallback onTap;

  const _SidebarProfileButton({
    required this.nombre,
    required this.rol,
    required this.onTap,
  });

  @override
  State<_SidebarProfileButton> createState() => _SidebarProfileButtonState();
}

class _SidebarProfileButtonState extends State<_SidebarProfileButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onHover: (h) => setState(() => _hover = h),
      borderRadius: BorderRadius.circular(kPortalRadiusSm),
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _hover ? PortalColors.mutedHover : Colors.transparent,
          borderRadius: BorderRadius.circular(kPortalRadiusSm),
        ),
        child: Row(
          children: [
            _PortalAvatar(nombre: widget.nombre, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _shortName(widget.nombre),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: PortalColors.foreground,
                      fontFamilyFallback: kPortalFontFallback,
                    ),
                  ),
                  Text(
                    widget.rol,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PortalColors.mutedForeground,
                      fontFamilyFallback: kPortalFontFallback,
                    ),
                  ),
                ],
              ),
            ),
            if (_hover)
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: PortalColors.mutedForeground,
              ),
          ],
        ),
      ),
    );
  }
}

/// Botón de acción del footer ("Cerrar sesión" rojo / "Regresar" gris).
class _FooterActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback onTap;

  const _FooterActionButton({
    required this.icon,
    required this.label,
    required this.destructive,
    required this.onTap,
  });

  @override
  State<_FooterActionButton> createState() => _FooterActionButtonState();
}

class _FooterActionButtonState extends State<_FooterActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.destructive
        ? PortalColors.destructive
        : _hover
        ? PortalColors.foreground
        : PortalColors.mutedForeground;
    final Color bg = !_hover
        ? Colors.transparent
        : widget.destructive
        ? PortalColors.destructiveSoft10
        : PortalColors.mutedHover;

    return InkWell(
      onTap: widget.onTap,
      onHover: (h) => setState(() => _hover = h),
      borderRadius: BorderRadius.circular(kPortalRadiusSm),
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kPortalRadiusSm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: fg,
                fontFamilyFallback: kPortalFontFallback,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Topbar (shell.md §TopBar) — buscador global a la izquierda + campana +
// popover del avatar (el portal desktop no muestra título de sección).
// ---------------------------------------------------------------------------

class _PortalShellTopBar extends StatelessWidget {
  const _PortalShellTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kPortalTopBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: PortalColors.surface,
        border: Border(
          bottom: BorderSide(color: PortalColors.borderSoft, width: 1),
        ),
      ),
      child: const Row(
        children: [
          PortalTopBarSearch(),
          Spacer(),
          NotificationBell(),
          SizedBox(width: 8),
          PortalTopBarAvatarMenu(),
        ],
      ),
    );
  }
}

/// Avatar circular verde con iniciales blancas (11px w600).
class _PortalAvatar extends StatelessWidget {
  final String? nombre;
  final double size;

  const _PortalAvatar({required this.nombre, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: PortalColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(nombre),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontFamilyFallback: kPortalFontFallback,
        ),
      ),
    );
  }
}
