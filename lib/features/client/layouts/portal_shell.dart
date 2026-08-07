import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/core/version.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/client/home/providers/home_providers.dart';
import 'package:sozu_cliente_app/features/client/providers/client_providers.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/app_download/components/app_download.dart';
import 'package:sozu_cliente_app/features/client/home/components/notification_bell.dart';
import 'package:sozu_cliente_app/features/client/layouts/portal_shell_widgets.dart';
// Botón "Referir" oculto por ahora (a petición); restaurar junto con su uso.
// import 'package:sozu_cliente_app/features/client/referral/components/referral_action.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Ítem del menú lateral.
class _PortalNavItemData {
  final String label;
  final String route;
  final IconData icon;

  const _PortalNavItemData(this.label, this.route, this.icon);
}

/// EL menú del portal. Vive en código a propósito: el de la BD
/// (`cliente-menu`) existe pero su menú padre está apagado, así que devolvía
/// cero ítems y encenderlo borraría de la navegación todo lo que la BD no tenga.
/// Cuando se pueble allá se vuelve a conectar; mientras, una sola fuente.
const List<_PortalNavItemData> _portalNavItems = [
  _PortalNavItemData('Inicio', '/inicio', Icons.home_outlined),
  _PortalNavItemData('Propiedades', '/propiedades', Icons.apartment_outlined),
  _PortalNavItemData('Productos', '/productos', Icons.inventory_2_outlined),
  _PortalNavItemData('Pagos', '/pagos', Icons.credit_card_outlined),
  _PortalNavItemData(
    'Estado de cuenta',
    '/estado-cuenta',
    Icons.bar_chart_outlined,
  ),
  _PortalNavItemData('Facturas', '/facturas', Icons.receipt_long_outlined),
  _PortalNavItemData('Mis documentos', '/expediente', Icons.badge_outlined),
  _PortalNavItemData('Mantenimientos', '/mantenimientos', Icons.build_outlined),
  _PortalNavItemData(
    'Notificaciones',
    '/notificaciones',
    Icons.notifications_outlined,
  ),
  _PortalNavItemData('Perfil', '/perfil', Icons.person_outline),
];

/// Rutas que el menú permite. Se conserva la función (y no `_portalNavItems`
/// crudo) porque el bottom nav y el sidebar filtran por ella.
Set<String> portalAllowedRoutes() =>
    _portalNavItems.map((e) => e.route).toSet();

/// Menú del bottom nav móvil, en el orden del sidebar. El nav muestra los
/// primeros como tabs y el resto tras un botón "Más".
List<({IconData icon, String label, String route})> clienteMenuTabs() => [
  for (final it in _portalNavItems)
    (icon: it.icon, label: it.label, route: it.route),
];

/// Activo por prefijo de ruta; "Inicio" solo con match exacto.
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

/// Nombre truncado a 2 palabras y máx. 22 caracteres.
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

/// Sidebar de 256px + topbar de 64px + contenido centrado a 1280.
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
// Sidebar
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
        ref.watch(notificationsProvider).valueOrNull?.noLeidas ?? 0;
    final nombre =
        auth.profile?.displayName ?? auth.profile?.email ?? 'Usuario';
    const navItems = _portalNavItems;

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
                // `onLight`: la sidebar es blanca por definición.
                const SLogo.onLight(
                  height: 24,
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
                            'Viendo como: ${imp.clientName ?? 'Cliente'}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: PortalColors.primary,
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
                  rol: auth.profile?.roleName ?? 'Cliente',
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
                          // Limpiar la impersonación regresa al selector.
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

/// Ítem del menú: activo lleva barrita verde pegada al borde izquierdo.
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
        // Solo cambia el fondo, nada se desplaza: `fast` + `standard`.
        duration: context.s.motion.fast,
        curve: context.s.motion.standard,
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
        // Solo cambia el fondo, nada se desplaza: `fast` + `standard`.
        duration: context.s.motion.fast,
        curve: context.s.motion.standard,
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
                    ),
                  ),
                  Text(
                    widget.rol,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PortalColors.mutedForeground,
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
        // Solo cambia el fondo, nada se desplaza: `fast` + `standard`.
        duration: context.s.motion.fast,
        curve: context.s.motion.standard,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Topbar: buscador global + campana + popover del avatar. En desktop no lleva
// título de sección.
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
          // "Descargar app" solo en web: en la app nativa no aplica.
          if (kIsWeb) ...[AppDownloadButton(), SizedBox(width: 12)],
          // Botón "Referir" oculto por ahora (a petición). Restaurar:
          // ReferralButton(), SizedBox(width: 12),
          NotificationBell(),
          SizedBox(width: 8),
          PortalTopBarAvatarMenu(),
        ],
      ),
    );
  }
}

/// Avatar circular con las iniciales del nombre.
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
        ),
      ),
    );
  }
}
