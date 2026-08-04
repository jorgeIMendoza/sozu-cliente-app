# Feature `auth`

Acceso a la app: login, recuperación y cambio de contraseña, biometría y
cierre de sesión por inactividad. Es la puerta de entrada de todos los
actores (cliente, comprador interno y administrador de la app).

## Reglas

Qué sí:

- Todo lo de autenticación vive aquí: pantallas, estado, servicio,
  contrato y adaptador. Si es de sesión o credenciales, es de esta
  feature.
- El backend se consume SOLO vía `AuthPort`. La UI y los tests dependen
  del contrato, nunca del adaptador.
- Campos y botones son del design system (`ui/ui.dart`). Lo específico de
  auth entra por props del componente global, no por copias.
- Componentes que otras features consumen (`BiometricToggleCard`,
  `password_rules`, `inactivity_watcher`) son API pública de la feature.
- dartdoc conciso: 1-3 líneas por miembro.

Qué no:

- Nada de `supabase_flutter` fuera de `adapters/auth_adapter.dart`.
- Nada de vendor en nombres: `AuthAdapter`, no `SupabaseAuthAdapter`.
- Ningún tipo del SDK en firmas públicas: la sesión es `AuthSession`, los
  fallos son `AuthError`/`AuthFailure` (`shared/api_error.dart`).
- Sin pantallas de otras features: el cambio VOLUNTARIO de contraseña es
  una modal de Perfil que llama al servicio de aquí. Lo visual vive donde
  se usa; auth es dueño del servicio y de la política (`password_rules`).
- Sin alias ni re-exports de compatibilidad.

## Estructura

```text
ports/       auth_port.dart          contrato: AuthPort, AuthSession, UserProfile
adapters/    auth_adapter.dart       implementación actual (único con supabase_flutter)
providers/   auth_provider.dart      AuthController (estado vivo) + authPortProvider
services/    biometric_service.dart  huella/Face ID sobre secure storage
screens/     login, forgot_password, change_password (forzado)
components/  login_form, biometric_*, password_rules, inactivity_watcher, auth_*
layouts/     auth_layout.dart
```

## Funcionamiento

- `AuthController` escucha `AuthPort.sessionChanges` y mantiene sesión,
  perfil, candado biométrico y `authFlowInProgress`; el router y las
  pantallas reaccionan con `ref.watch(authProvider)`.
- La biometría guarda el refresh token en Keystore atado al `userId`
  enrolado y es SOLO para usuarios del portal; el acceso administrador
  siempre pide correo y contraseña (`shouldOfferBiometrics` exige
  `hasPortalAccess`, y `disableIfOwnedBy` apaga un enrolamiento viejo de una
  cuenta no-cliente al entrar).
- **Quién entra y a dónde sale del PERFIL, no de la plataforma ni de un
  gesto.** `PortalAccess.allows` (rol Cliente o comprador activo) decide el
  acceso; `canManageClientApp` manda al selector de clientes. Mismo flujo en
  web y en móvil. Los dos interruptores manuales que existían (Ctrl+Shift+A y
  el long-press del sello de versión) se BORRARON al conceder el acceso por
  rol: dejaban a móvil y escritorio con caminos distintos.
- El cambio forzado de contraseña (temporal) es pantalla de esta feature;
  al terminar ofrece activar la biometría.
- Inactividad: 5 min en teléfono, 15 en escritorio, decidido por formato
  de pantalla (no por `kIsWeb`).

## Cómo agregar funcionalidad

1. Método nuevo de backend: firma en `AuthPort` (documentando qué lanza),
   implementación en `AuthAdapter` y doble en
   `test/features/auth/fake_auth_port.dart`.
2. Estado nuevo: campo en `AuthController` más `notifyListeners()`.
3. Pantalla nueva: `screens/` solo compone; la lógica va a un componente
   con estado o al controller. La ruta se registra en `router.dart`.
4. Tests: `authPortProvider.overrideWithValue(FakeAuthPort())`; nunca
   inicializar el SDK real en tests.
