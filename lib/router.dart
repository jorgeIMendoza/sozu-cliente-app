import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/admin/screens/announcements_screen.dart';
import 'package:sozu_cliente_app/features/auth/screens/change_password_screen.dart';
import 'package:sozu_cliente_app/features/client/facturacion/screens/facturas_screen.dart';
import 'package:sozu_cliente_app/features/client/properties/screens/estado_cuenta_screen.dart';
import 'package:sozu_cliente_app/features/client/expediente/screens/expediente_screen.dart';
import 'package:sozu_cliente_app/features/auth/screens/confirmacion_email_screen.dart';
import 'package:sozu_cliente_app/features/auth/screens/email_not_confirmed_screen.dart';
import 'package:sozu_cliente_app/features/auth/screens/forgot_password_screen.dart';
import 'package:sozu_cliente_app/features/client/home/screens/inicio_screen.dart';
import 'package:sozu_cliente_app/features/auth/screens/login_screen.dart';
import 'package:sozu_cliente_app/features/client/home/screens/notificaciones_screen.dart';
import 'package:sozu_cliente_app/features/client/properties/screens/pagar_screen.dart';
import 'package:sozu_cliente_app/features/client/properties/screens/mantenimientos_screen.dart';
import 'package:sozu_cliente_app/features/client/properties/screens/pagos_screen.dart';
import 'package:sozu_cliente_app/features/client/profile/screens/perfil_detalle_screens.dart';
import 'package:sozu_cliente_app/features/client/profile/screens/perfil_screen.dart';
import 'package:sozu_cliente_app/features/client/products/screens/producto_detalle_screen.dart';
import 'package:sozu_cliente_app/features/client/products/screens/productos_screen.dart';
import 'package:sozu_cliente_app/features/client/properties/screens/propiedad_detalle_screen.dart';
import 'package:sozu_cliente_app/features/client/properties/screens/propiedades_screen.dart';
import 'package:sozu_cliente_app/features/admin/screens/select_client_screen.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/features/client/home/components/notificaciones_fx.dart';
import 'package:sozu_cliente_app/features/client/layouts/portal_shell.dart';

/// Página secundaria con la transición del design system
/// ([sozuPageTransition]: fade + escala en escritorio, fade + deslizamiento en
/// móvil) y contenido responsive (WebFrame) para web/desktop.
///
/// Recibe el [context] del `pageBuilder` porque duración y curva salen de
/// `context.s.motion` y la forma de la transición del breakpoint: sin contexto no
/// hay tokens y volveríamos a los milisegundos cocidos.
///
/// [portalFullWidth]: pantallas con layout de portal propio (p.ej. estado de
/// cuenta) no se limitan a los 900px del WebFrame en modo portal - el shell
/// ya acota el contenido a 1280px; fuera del portal se comportan igual que
/// siempre.
///
/// [sinMarco]: pantallas que ocupan el viewport completo y traen su propio
/// layout responsive (las de acceso). El WebFrame les hacía daño: las metía en
/// una caja de 900 px pintada con `scaffoldBackgroundColor`, que en tema
/// oscuro es `slate900` - de ahí el marco navy alrededor del login.
CustomTransitionPage<void> _slidePage(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  bool portalFullWidth = false,
  bool sinMarco = false,
}) {
  final duracion = sozuPageTransitionDuration(context);
  return CustomTransitionPage(
    key: state.pageKey,
    child: sinMarco
        ? child
        : portalFullWidth
        ? _PortalAwareFrame(child: child)
        : WebFrame(child: child),
    transitionDuration: duracion,
    // También la de regreso: su valor por defecto son 300 ms cocidos, así que
    // sin esto el "atrás" seguiría animando con "reducir animaciones" activo.
    reverseTransitionDuration: duracion,
    transitionsBuilder: sozuPageTransition,
  );
}

/// Navegación (espejo de Expo Router del app RN):
/// - Guards: sin sesión → /login; contraseña temporal → /change-password.
/// - Shell con 4 tabs: Inicio · Propiedades · Facturas · Perfil.
/// - Secundarias: pagos, estado-cuenta, pagar, notificaciones, propiedad/:id.
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
      final inAuthArea =
          loc == '/login' ||
          loc == '/forgot-password' ||
          loc == _rutaConfirmacion ||
          loc == emailNotConfirmedPath;

      // Las dos pestañas viejas son ahora un filtro de /propiedades. Se
      // redirigen y no se borran: el menú de la BD todavía puede mandar a
      // cualquiera, y hay avisos ya enviados que apuntan ahí.
      if (loc == '/adquisicion') return '/propiedades?filtro=adquisicion';
      if (loc == '/patrimonio') return '/propiedades?filtro=entregadas';
      // La pantalla dejo de ser "Documentos": ahora solo muestra facturas.
      if (loc == '/documentos') return '/facturas';

      // Pantalla de autenticación aún trabajando: no sacarla (ni a /splash)
      // hasta que ella decida. En /login evita que el signOut por rol inválido
      // desmonte la pantalla y pierda el mensaje de error; en /change-password,
      // que el perfil ya sin `debe_cambiar_password` se lleve el sheet de
      // biometría antes de que el usuario conteste.
      if (auth.authFlowInProgress &&
          (loc == '/login' ||
              loc == '/change-password' ||
              loc == _rutaConfirmacion)) {
        return null;
      }
      if (auth.isLoading) return loc == '/splash' ? null : '/splash';
      // Gate de correo sin confirmar (roles de portal): pantalla dedicada. Va
      // antes que todo lo demás para atrapar también la rehidratación de una
      // sesión guardada al abrir la app, no solo el login. El gate ya cerró la
      // sesión, así que sin esta regla el usuario caería en /login sin
      // explicación.
      if (auth.blockedAccess == AccessBlock.emailNotConfirmed) {
        return loc == emailNotConfirmedPath ? null : emailNotConfirmedPath;
      }
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
        // Bloqueo ya limpiado ("Volver al inicio de sesión"): la pantalla de
        // confirmación deja de tener sentido.
        if (loc == emailNotConfirmedPath) return '/login';
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
      // Las pantallas de acceso van a sangre: su propio AuthScaffold
      // resuelve el responsive y fuerza el tema claro.
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _slidePage(context, state, const LoginScreen(), sinMarco: true),
      ),
      // La fija la Edge Function en el correo: cambiarla deja muertos los
      // enlaces ya enviados. Este host servia el portal legacy y ahora sirve
      // Flutter, asi que sin esta ruta el enlace caia en el fallback SPA y
      // terminaba en /login sin confirmar nada.
      GoRoute(
        path: _rutaConfirmacion,
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters;
          return _slidePage(
            context,
            state,
            ConfirmacionEmailScreen(
              tokenHash: q['token_hash'],
              type: q['type'],
              email: q['email'],
              nombre: q['nombre'],
            ),
            sinMarco: true,
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          const ForgotPasswordScreen(),
          sinMarco: true,
        ),
      ),
      GoRoute(
        path: emailNotConfirmedPath,
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          const EmailNotConfirmedScreen(),
          sinMarco: true,
        ),
      ),
      GoRoute(
        path: '/change-password',
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          const ChangePasswordScreen(),
          sinMarco: true,
        ),
      ),
      // Admin sin cliente seleccionado (fuera del shell del portal).
      // `sinMarco` como las de acceso: AdminLayout ya trae su propio Scaffold,
      // ancho maximo y scroll de viewport completo. Con el WebFrame, fuera de sus
      // 900 px solo quedaba un ColoredBox y la rueda del raton no hacia nada en
      // los laterales.
      GoRoute(
        path: '/seleccionar-cliente',
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          const SelectClientScreen(),
          sinMarco: true,
        ),
      ),
      GoRoute(
        path: '/admin-avisos',
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          const AnnouncementsScreen(),
          sinMarco: true,
        ),
      ),
      // `ClientShell` envuelve TODAS las pantallas del cliente -pestanas y
      // secundarias- y decide sidebar o barra inferior por ANCHO disponible.
      ShellRoute(
        builder: (context, state, child) {
          final path = state.uri.path;
          // NotificacionesFx envuelve TODAS las pantallas del cliente (móvil,
          // portal y escritorio): observa la campana a nivel app y dispara la
          // animación de llegada hacia el destino visible de cada pantalla, sin
          // depender de que una campana concreta esté montada/visible.
          // WebSelectable habilita seleccionar/copiar texto con el mouse en web.
          // Va AQUÍ y no en el builder de MaterialApp porque SelectionArea
          // necesita un Overlay ancestro (lo crea el Navigator) y el builder de
          // MaterialApp está por encima de él. Un solo montaje cubre todas las
          // pantallas del cliente: tabs y secundarias.
          return WebSelectable(
            child: NotificacionesFx(
              child: ClientShell(currentPath: path, child: child),
            ),
          );
        },
        routes: [
          // Secundarias (con back; en modo portal se muestran dentro del shell).
          GoRoute(
            path: '/pagos',
            pageBuilder: (context, state) =>
                _slidePage(context, state, const PagosScreen()),
          ),
          GoRoute(
            path: '/estado-cuenta',
            // Con layout de portal propio (grid 1fr+300 y tabla con min-width
            // 680): sin el tope de 900px del WebFrame en modo portal.
            pageBuilder: (context, state) => _slidePage(
              context,
              state,
              const EstadoCuentaScreen(),
              portalFullWidth: true,
            ),
          ),
          GoRoute(
            path: '/pagar',
            pageBuilder: (context, state) => _slidePage(
              context,
              state,
              PagarScreen(referencia: state.uri.queryParameters['id']),
            ),
          ),
          GoRoute(
            path: '/notificaciones',
            pageBuilder: (context, state) =>
                _slidePage(context, state, const NotificacionesScreen()),
          ),
          GoRoute(
            path: '/expediente',
            pageBuilder: (context, state) =>
                _slidePage(context, state, const ExpedienteScreen()),
          ),
          // Los datos fiscales viven en Perfil, pero se llega desde Facturación:
          // ahí es donde el cliente descubre que su RFC está mal.
          GoRoute(
            path: '/datos-fiscales',
            pageBuilder: (context, state) =>
                _slidePage(context, state, const PerfilFiscalScreen()),
          ),
          GoRoute(
            path: '/mantenimientos',
            pageBuilder: (context, state) =>
                _slidePage(context, state, const MantenimientosScreen()),
          ),
          GoRoute(
            path: '/productos',
            pageBuilder: (context, state) =>
                _slidePage(context, state, const ProductosScreen()),
          ),
          GoRoute(
            path: '/productos/:id',
            pageBuilder: (context, state) => _slidePage(
              context,
              state,
              ProductoDetalleScreen(
                cuentaId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              ),
            ),
          ),
          GoRoute(
            path: '/propiedad/:id',
            pageBuilder: (context, state) => _slidePage(
              context,
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
                    path: '/propiedades',
                    builder: (context, state) => PropiedadesScreen(
                      filtroInicial: _filtroDesdeQuery(
                        state.uri.queryParameters['filtro'],
                      ),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/facturas',
                    builder: (context, state) => const FacturasScreen(),
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

/// Aterrizaje del enlace de confirmacion de correo. La ruta la fija
/// `reset-user-password` en el correo; aqui solo se atiende.
const _rutaConfirmacion = '/auth/confirmacion-email';

/// `?filtro=` de /propiedades -> valor del enum. Un valor desconocido abre la
/// pantalla en "todas" en vez de fallar.
PropiedadesFiltro _filtroDesdeQuery(String? valor) => switch (valor) {
  'adquisicion' => PropiedadesFiltro.adquisicion,
  'entregadas' => PropiedadesFiltro.entregadas,
  _ => PropiedadesFiltro.todas,
};

/// Contenido de las ramas del `StatefulShellRoute`. El chrome -navegacion,
/// franja de impersonacion y andamio- lo pone [ClientShell] a nivel del
/// ShellRoute, para que persista tambien en las secundarias.
class _TabsShell extends StatelessWidget {
  const _TabsShell({required this.shell});

  final StatefulNavigationShell shell;

  // Solo el contenido: `ClientShell` ya pone navegacion, franja de
  // impersonacion y andamio.
  @override
  Widget build(BuildContext context) => shell;
}

/// Pantallas con layout propio: dentro del shell ancho van tal cual, porque el
/// shell ya acota el contenido; fuera se aplica el `WebFrame`.
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
      body: Center(child: CircularProgressIndicator(color: SozuBrand.green500)),
    );
  }
}
