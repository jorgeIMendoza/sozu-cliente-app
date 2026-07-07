import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'core/version.dart';
import 'providers/auth_provider.dart';
import 'providers/impersonation_provider.dart';
import 'screens/adquisicion_screen.dart';
import 'screens/cambiar_password_screen.dart';
import 'screens/change_password_forced_screen.dart';
import 'screens/documentos_screen.dart';
import 'screens/estado_cuenta_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/inicio_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notificaciones_screen.dart';
import 'screens/pagar_screen.dart';
import 'screens/pagos_screen.dart';
import 'screens/patrimonio_screen.dart';
import 'screens/perfil_screen.dart';
import 'screens/propiedad_detalle_screen.dart';
import 'screens/seleccionar_cliente_screen.dart';
import 'widgets/fx.dart';

/// Página secundaria con transición sutil (fade + deslizamiento) y contenido
/// responsive (WebFrame) para web/desktop.
CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: WebFrame(child: child),
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
  final auth = ref.watch(authProvider);
  // read: Listenable.merge escucha los notify; watch reconstruiría el router.
  final imp = ref.read(impersonationProvider);

  return GoRouter(
    initialLocation: '/inicio',
    refreshListenable: Listenable.merge([auth, imp]),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final inAuthArea = loc == '/login' || loc == '/forgot-password';

      if (auth.isLoading) return loc == '/splash' ? null : '/splash';
      if (loc == '/splash') {
        // Sesión resuelta: salir del splash.
        if (auth.session == null) return '/login';
        if (auth.mustChangePassword) return '/change-password';
        if (auth.isSuperAdmin && !imp.active) return '/seleccionar-cliente';
        return '/inicio';
      }
      if (auth.session == null) return inAuthArea ? null : '/login';
      if (auth.mustChangePassword) {
        return loc == '/change-password' ? null : '/change-password';
      }
      // Super admin: sin cliente seleccionado solo puede estar en el selector.
      if (auth.isSuperAdmin) {
        if (!imp.active) {
          return loc == '/seleccionar-cliente' ? null : '/seleccionar-cliente';
        }
        if (loc == '/seleccionar-cliente') return null; // cambiar de cliente
        if (inAuthArea || loc == '/change-password') return '/inicio';
        return null;
      }
      if (loc == '/seleccionar-cliente') return '/inicio';
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
      // Secundarias (fuera del shell, con back).
      GoRoute(
        path: '/pagos',
        pageBuilder: (context, state) => _slidePage(state, const PagosScreen()),
      ),
      GoRoute(
        path: '/estado-cuenta',
        pageBuilder: (context, state) =>
            _slidePage(state, const EstadoCuentaScreen()),
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
        path: '/cambiar-password',
        pageBuilder: (context, state) =>
            _slidePage(state, const CambiarPasswordScreen()),
      ),
      GoRoute(
        path: '/seleccionar-cliente',
        pageBuilder: (context, state) =>
            _slidePage(state, const SeleccionarClienteScreen()),
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
  );
});

const _navItems = [
  (Icons.home_outlined, 'Inicio'),
  (Icons.shopping_bag_outlined, 'En adquisición'),
  (Icons.account_balance_wallet_outlined, 'Patrimonio'),
  (Icons.description_outlined, 'Documentos'),
  (Icons.person_outline, 'Perfil'),
];

/// Shell responsive: sidebar en desktop (como el portal web), bottom nav en
/// móvil/tablet angosta. Si un super admin impersona a un cliente, muestra la
/// franja "Viendo como" sobre todo el layout.
class _TabsShell extends ConsumerWidget {
  final StatefulNavigationShell shell;

  const _TabsShell({required this.shell});

  void _go(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final imp = ref.watch(impersonationProvider);
    final banner = auth.isSuperAdmin && imp.active
        ? _ImpersonationBanner(nombre: imp.nombre ?? 'Cliente')
        : null;

    final Widget layout;
    if (isDesktop(context)) {
      layout = Row(
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
    return Scaffold(
      body: banner == null
          ? shell
          : Column(
              children: [
                banner,
                Expanded(child: shell),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: shell.currentIndex,
        onTap: _go,
        items: [
          for (final (icon, label) in _navItems)
            BottomNavigationBarItem(
              icon: Icon(icon),
              label: label == 'En adquisición' ? 'Adquisición' : label,
            ),
        ],
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
