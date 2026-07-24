import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/portal_theme.dart';
import 'core/theme.dart';
import 'core/version.dart';
import 'providers/auth_provider.dart';
import 'providers/data_providers.dart';
import 'providers/impersonation_provider.dart';
import 'screens/admin_avisos_screen.dart';
import 'screens/adquisicion_screen.dart';
import 'screens/cambiar_password_screen.dart';
import 'screens/change_password_forced_screen.dart';
import 'screens/documentos_screen.dart';
import 'screens/estado_cuenta_screen.dart';
import 'screens/expediente_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/inicio_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notificaciones_screen.dart';
import 'screens/pagar_screen.dart';
import 'screens/pagos_screen.dart';
import 'screens/patrimonio_screen.dart';
import 'screens/perfil_screen.dart';
import 'screens/producto_detalle_screen.dart';
import 'screens/productos_screen.dart';
import 'screens/propiedad_detalle_screen.dart';
import 'screens/seleccionar_cliente_screen.dart';
import 'widgets/fx.dart';
import 'widgets/notificaciones_fx.dart';
import 'widgets/portal_shell.dart';

/// Página secundaria con transición sutil (fade + deslizamiento) y contenido
/// responsive (WebFrame) para web/desktop.
///
/// [portalFullWidth]: pantallas con layout de portal propio (p.ej. estado de
/// cuenta) no se limitan a los 900px del WebFrame en modo portal — el shell
/// ya acota el contenido a 1280px; fuera del portal se comportan igual que
/// siempre.
CustomTransitionPage<void> _slidePage(
  GoRouterState state,
  Widget child, {
  bool portalFullWidth = false,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: portalFullWidth
        ? _PortalAwareFrame(child: child)
        : WebFrame(child: child),
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Navegación (espejo de Expo Router del app RN):
/// - Guards: sin sesión → /login; contraseña temporal → /change-password.
/// - Shell con 5 tabs: Inicio · Adquisición · Patrimonio · Documentos · Perfil.
/// - Secundarias: pagos, estado-cuenta, pagar, notificaciones,
///   cambiar-password, propiedad/:id.
final routerProvider = Provider<GoRouter>((ref) {
  // read (NO watch) para ambos: Listenable.merge ya re-evalúa el redirect en
  // cada notify; watch reconstruiría el GoRouter completo en cada cambio de
  // sesión/perfil, remontando las pantallas (p.ej. el login perdería su
  // estado y el mensaje de error al validar rol).
  final auth = ref.read(authProvider);
  final imp = ref.read(impersonationProvider);

  return GoRouter(
    initialLocation: '/inicio',
    refreshListenable: Listenable.merge([auth, imp]),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final inAuthArea = loc == '/login' || loc == '/forgot-password';

      // Login validando rol: no salir de /login (ni a /splash) hasta que
      // la pantalla decida; si no, el signOut por rol inválido desmonta el
      // login y el mensaje de error se pierde.
      if (auth.loginEnCurso && loc == '/login') return null;
      if (auth.isLoading) return loc == '/splash' ? null : '/splash';
      if (loc == '/splash') {
        // Sesión resuelta: salir del splash.
        if (auth.session == null || auth.locked) return '/login';
        if (auth.mustChangePassword) return '/change-password';
        if (auth.isSuperAdmin && !imp.active) return '/seleccionar-cliente';
        return '/inicio';
      }
      // Candado biométrico puesto: la sesión sigue viva por debajo pero la
      // app se comporta como deslogueada hasta desbloquear.
      if (auth.session == null || auth.locked) {
        return inAuthArea ? null : '/login';
      }
      if (auth.mustChangePassword) {
        return loc == '/change-password' ? null : '/change-password';
      }
      // Super admin: sin cliente seleccionado solo selector o envío de avisos.
      if (auth.isSuperAdmin) {
        if (!imp.active) {
          const permitidas = {'/seleccionar-cliente', '/admin-avisos'};
          return permitidas.contains(loc) ? null : '/seleccionar-cliente';
        }
        if (loc == '/seleccionar-cliente' || loc == '/admin-avisos') {
          return null; // cambiar de cliente / enviar avisos
        }
        if (inAuthArea || loc == '/change-password') return '/inicio';
        return null;
      }
      if (loc == '/seleccionar-cliente' || loc == '/admin-avisos') {
        return '/inicio';
      }
      if (inAuthArea || loc == '/change-password') return '/inicio';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _slidePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) =>
            _slidePage(state, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/change-password',
        pageBuilder: (context, state) =>
            _slidePage(state, const ChangePasswordForcedScreen()),
      ),
      // Admin sin cliente seleccionado (fuera del shell del portal).
      GoRoute(
        path: '/seleccionar-cliente',
        pageBuilder: (context, state) =>
            _slidePage(state, const SeleccionarClienteScreen()),
      ),
      GoRoute(
        path: '/admin-avisos',
        pageBuilder: (context, state) =>
            _slidePage(state, const AdminAvisosScreen()),
      ),
      // Modo portal (web ≥1024px): PortalShellWrapper envuelve TODAS las
      // pantallas del cliente con el shell del portal (sidebar 256 + topbar
      // 64, ruta activa marcada); en móvil/angosto devuelve el hijo tal cual
      // y el layout actual no cambia.
      ShellRoute(
        // En móvil (<1024) el wrapper añade la barra inferior flotante a TODAS
        // las pantallas del cliente (tabs + secundarias), de modo que el menú
        // NUNCA desaparezca; en modo portal (web ≥1024) o escritorio nativo el
        // _ClienteMobileChrome es un pass-through y manda el sidebar/_SideNav.
        builder: (context, state, child) {
          final path = state.uri.path;
          // NotificacionesFx envuelve TODAS las pantallas del cliente (móvil,
          // portal y escritorio): observa la campana a nivel app y dispara la
          // animación de llegada hacia el destino visible de cada pantalla, sin
          // depender de que una campana concreta esté montada/visible.
          return NotificacionesFx(
            child: PortalShellWrapper(
              currentPath: path,
              child: _ClienteMobileChrome(currentPath: path, child: child),
            ),
          );
        },
        routes: [
          // Secundarias (con back; en modo portal se muestran dentro del shell).
          GoRoute(
            path: '/pagos',
            pageBuilder: (context, state) =>
                _slidePage(state, const PagosScreen()),
          ),
          GoRoute(
            path: '/estado-cuenta',
            // Con layout de portal propio (grid 1fr+300 y tabla con min-width
            // 680): sin el tope de 900px del WebFrame en modo portal.
            pageBuilder: (context, state) => _slidePage(
              state,
              const EstadoCuentaScreen(),
              portalFullWidth: true,
            ),
          ),
          GoRoute(
            path: '/pagar',
            pageBuilder: (context, state) => _slidePage(
              state,
              PagarScreen(referencia: state.uri.queryParameters['id']),
            ),
          ),
          GoRoute(
            path: '/notificaciones',
            pageBuilder: (context, state) =>
                _slidePage(state, const NotificacionesScreen()),
          ),
          GoRoute(
            path: '/expediente',
            pageBuilder: (context, state) =>
                _slidePage(state, const ExpedienteScreen()),
          ),
          GoRoute(
            path: '/cambiar-password',
            pageBuilder: (context, state) =>
                _slidePage(state, const CambiarPasswordScreen()),
          ),
          GoRoute(
            path: '/productos',
            pageBuilder: (context, state) =>
                _slidePage(state, const ProductosScreen()),
          ),
          GoRoute(
            path: '/productos/:id',
            pageBuilder: (context, state) => _slidePage(
              state,
              ProductoDetalleScreen(
                cuentaId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              ),
            ),
          ),
          GoRoute(
            path: '/propiedad/:id',
            pageBuilder: (context, state) => _slidePage(
              state,
              PropiedadDetalleScreen(
                cuentaId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              ),
            ),
          ),
          // Shell de tabs.
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => _TabsShell(shell: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/inicio',
                    builder: (context, state) => const InicioScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/adquisicion',
                    builder: (context, state) => const AdquisicionScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/patrimonio',
                    builder: (context, state) => const PatrimonioScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/documentos',
                    builder: (context, state) => const DocumentosScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/perfil',
                    builder: (context, state) => const PerfilScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Tabs del shell (icono, label, ruta interna). La ruta permite filtrar qué
/// tabs se muestran según el menú de la BD (mismo criterio que el sidebar del
/// portal), degradando a los 5 tabs si el endpoint aún no responde.
const _navItems = [
  (Icons.home_outlined, 'Inicio', '/inicio'),
  (Icons.shopping_bag_outlined, 'En adquisición', '/adquisicion'),
  (Icons.account_balance_wallet_outlined, 'Patrimonio', '/patrimonio'),
  (Icons.description_outlined, 'Documentos', '/documentos'),
  (Icons.person_outline, 'Perfil', '/perfil'),
];

/// Shell de las 5 ramas: en escritorio pinta la sidebar (`_SideNav`); en móvil
/// solo entrega el contenido (la barra inferior flotante la añade
/// [_ClienteMobileChrome] a nivel del ShellRoute, para que persista también en
/// las pantallas secundarias). Si un super admin impersona a un cliente,
/// muestra la franja "Viendo como" sobre el layout.
class _TabsShell extends ConsumerWidget {
  final StatefulNavigationShell shell;

  const _TabsShell({required this.shell});

  void _go(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Modo portal (web ≥1024px): el PortalShellWrapper del router ya pinta
    // sidebar, topbar e impersonación; aquí solo va el contenido de las tabs,
    // sin bottom nav ni _SideNav.
    if (isPortalMode(context)) {
      return Scaffold(body: shell);
    }
    final auth = ref.watch(authProvider);
    final imp = ref.watch(impersonationProvider);
    final banner = auth.isSuperAdmin && imp.active
        ? _ImpersonationBanner(nombre: imp.nombre ?? 'Cliente')
        : null;

    if (isDesktop(context)) {
      final layout = Row(
        children: [
          _SideNav(currentIndex: shell.currentIndex, onSelect: _go),
          Expanded(child: shell),
        ],
      );
      return Scaffold(
        body: banner == null
            ? layout
            : Column(
                children: [
                  banner,
                  Expanded(child: layout),
                ],
              ),
      );
    }
    // Móvil (<1024): la barra inferior flotante la provee _ClienteMobileChrome
    // (envuelve tabs + secundarias). Aquí solo el contenido (+ franja de
    // impersonación cuando aplica).
    return Scaffold(
      body: banner == null
          ? shell
          : Column(
              children: [
                banner,
                Expanded(child: shell),
              ],
            ),
    );
  }
}

/// Envoltorio móvil (<1024) común a TODAS las pantallas del cliente: añade la
/// barra inferior flotante ([_ClienteBottomNav]) tanto sobre las tabs como
/// sobre las pantallas secundarias (pagos, estado de cuenta, productos,
/// notificaciones, expediente, detalles), de modo que el menú nunca desaparezca
/// y siempre haya cómo moverse. En modo portal (web ≥1024) o escritorio nativo
/// es un pass-through: el sidebar del portal / `_SideNav` ya navegan.
class _ClienteMobileChrome extends StatelessWidget {
  final String currentPath;
  final Widget child;

  const _ClienteMobileChrome({required this.currentPath, required this.child});

  @override
  Widget build(BuildContext context) {
    if (isPortalMode(context) || isDesktop(context)) return child;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: child,
      bottomNavigationBar: _ClienteBottomNav(currentPath: currentPath),
    );
  }
}

/// Barra inferior flotante del cliente (móvil): tarjeta redondeada con sombra
/// suave, respetando SafeArea. Muestra los primeros ítems del menú y agrupa el
/// resto tras el botón "Más" (…). El ítem activo se resuelve por la ruta actual
/// (un detalle como `/productos/:id` resalta su tab padre). Los tabs cambian de
/// sección con `context.go` (preservan el estado del IndexedStack); las
/// secundarias del menú "Más" se abren con `context.push` para que quede stack
/// y aparezca la flecha de regresar.
class _ClienteBottomNav extends ConsumerWidget {
  final String currentPath;

  const _ClienteBottomNav({required this.currentPath});

  /// Rutas que corresponden a ramas del StatefulShellRoute: siempre se navegan
  /// con `context.go` (nunca push) para conservar el estado de la rama.
  static const _branchRoutes = {
    '/inicio',
    '/adquisicion',
    '/patrimonio',
    '/documentos',
    '/perfil',
  };

  /// Activo por prefijo de ruta; "Inicio" solo con match exacto.
  bool _isActive(String route, String path) {
    if (route == '/inicio') return path == '/inicio';
    return path == route || path.startsWith('$route/');
  }

  String _shortLabel(String label) =>
      label == 'En adquisición' ? 'Adquisición' : label;

  void _navigateTo(BuildContext context, String route, {required bool push}) {
    if (_branchRoutes.contains(route)) {
      context.go(route); // preserva el estado de la rama
    } else if (push) {
      context.push(route); // stack → flecha de regresar
    } else {
      context.go(route);
    }
  }

  void _mostrarMasMenu(
    BuildContext context,
    List<({IconData icon, String label, String route})> items,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final it in items)
              ListTile(
                leading: Icon(it.icon),
                title: Text(it.label),
                selected: _isActive(it.route, currentPath),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  // Secundarias con push (stack); ramas con go.
                  _navigateTo(context, it.route, push: true);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SozuTone.of(context);
    // Menú completo del portal (misma resolución/orden/permisos que el sidebar,
    // vía cliente-menu con degradación). Los primeros ítems como tabs; el resto
    // tras "Más" (…) para que TODOS sean alcanzables aunque no quepan.
    final menu = clienteMenuTabs(ref.watch(clienteMenuProvider).valueOrNull);
    const maxTabs = 4; // 4 tabs + "Más" cuando hay más de 5 ítems
    final hasOverflow = menu.length > 5;
    final tabs = hasOverflow ? menu.take(maxTabs).toList() : menu;
    final overflow = hasOverflow
        ? menu.skip(maxTabs).toList()
        : <({IconData icon, String label, String route})>[];

    final selected = tabs.indexWhere((t) => _isActive(t.route, currentPath));
    // "Más" resaltado cuando la pantalla actual no es ninguno de los tabs
    // visibles (estás en una secundaria o en un ítem del overflow).
    final masActive = hasOverflow && selected < 0;
    // Destino de la animación de llegada (NotificacionesFx) cuando no hay
    // campana visible: el ítem "Notificaciones" si es una pestaña visible, o
    // el botón "Más" (…) si vive dentro del overflow.
    final notifTabIdx = tabs.indexWhere((t) => t.route == '/notificaciones');
    final notifEnMas =
        notifTabIdx < 0 && overflow.any((t) => t.route == '/notificaciones');

    return Container(
      color: tone.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Container(
            decoration: BoxDecoration(
              color: tone.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: tone.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _NavBarItem(
                      key: i == notifTabIdx ? notifNavKey : null,
                      icon: tabs[i].icon,
                      label: _shortLabel(tabs[i].label),
                      active: i == selected,
                      onTap: () =>
                          _navigateTo(context, tabs[i].route, push: false),
                    ),
                  if (hasOverflow)
                    _NavBarItem(
                      key: notifEnMas ? notifNavKey : null,
                      icon: Icons.more_horiz,
                      label: 'Más',
                      active: masActive,
                      onTap: () => _mostrarMasMenu(context, overflow),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ítem de la barra inferior flotante: icono + etiqueta, resaltado en verde
/// cuando está activo.
class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final color = active ? tone.primary : tone.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Franja de impersonación: "Super admin {admin} · Viendo como: {cliente}"
/// + cambiar / salir.
class _ImpersonationBanner extends ConsumerWidget {
  final String nombre;

  const _ImpersonationBanner({required this.nombre});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SozuTone.of(context);
    final admin = ref.watch(authProvider).profile;
    final adminNombre = admin?.nombre ?? admin?.email ?? '';
    return Material(
      color: tone.primarySoft,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 18,
                color: tone.primaryDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            'Super admin'
                            '${adminNombre.isEmpty ? '' : ' ($adminNombre)'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: '  ·  '),
                      TextSpan(text: 'Viendo como: $nombre'),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tone.primaryDark,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/seleccionar-cliente'),
                child: Text(
                  'Cambiar cliente',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tone.primaryDark,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(impersonationProvider).clear(),
                child: Text(
                  'Salir',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tone.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra lateral de escritorio: wordmark SOZU + navegación.
class _SideNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onSelect;

  const _SideNav({required this.currentIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Container(
      width: 248,
      color: tone.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sozu',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    color: tone.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PORTAL DEL CLIENTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                    color: tone.textMuted,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < _navItems.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: i == currentIndex ? tone.primarySoft : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _navItems[i].$1,
                        size: 20,
                        color: i == currentIndex
                            ? tone.primaryDark
                            : tone.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _navItems[i].$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: i == currentIndex
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: i == currentIndex
                              ? tone.primaryDark
                              : tone.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              appVersionLabel,
              style: TextStyle(fontSize: 11, color: tone.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// En modo portal devuelve el hijo tal cual (el shell ya limita el ancho a
/// 1280px); en cualquier otro caso aplica el WebFrame de 900px de siempre.
class _PortalAwareFrame extends StatelessWidget {
  final Widget child;

  const _PortalAwareFrame({required this.child});

  @override
  Widget build(BuildContext context) =>
      isPortalMode(context) ? child : WebFrame(child: child);
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: SozuColors.emerald500),
      ),
    );
  }
}
