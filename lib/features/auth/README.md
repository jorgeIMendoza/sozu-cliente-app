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
- Sin paleta cruda (`SozuBrand.*`) ni espaciados literales: van los roles
  (`context.s.color.*`) y la escala (`context.s.space.*`, `gapMd`...).

Las DOS únicas excepciones de `SozuBrand` en toda la app viven aquí y son
deliberadas; la auditoría las cuenta y no hay que "arreglarlas":

- `auth_brand_image.dart` - el panel de marca es verde en los dos temas a
  propósito: es superficie de marca, no una superficie temada.
- `auth_layout.dart` (`_kPrimarySoft`) - está dentro de un `const BoxDecoration`
  y `context.s` no cabe en una expresión `const`.

## Estructura

```text
ports/       auth_port.dart          contrato: AuthPort, AuthSession, UserProfile
adapters/    auth_adapter.dart       implementación actual (único con supabase_flutter)
providers/   auth_provider.dart      AuthController (estado vivo) + authPortProvider
services/    biometric_service.dart  huella/Face ID sobre secure storage
screens/     login, forgot_password, change_password (forzado),
             confirmacion_email (aterrizaje del enlace), email_not_confirmed
components/  login_form, biometric_*, password_rules, inactivity_watcher, auth_*
layouts/     auth_layout.dart        arma solo el panel de marca (con QR en
                                     web de escritorio); no recibe `brand`
```

Las llamadas SIN sesión (recuperar contraseña, reenviar confirmación, gate de
versión) van por `shared/adapters/anon_function.dart` y NO por
`functions.invoke`: ese cliente manda la llave anónima en `apikey` Y en
`Authorization`, y el gateway nuevo responde 401 antes de ejecutar nada.

## Funcionamiento

- `AuthController` escucha `AuthPort.sessionChanges` y mantiene sesión,
  perfil, candado biométrico y `authFlowInProgress`; el router y las
  pantallas reaccionan con `ref.watch(authProvider)`.
- La biometría guarda el refresh token en Keystore atado al `userId`
  enrolado y es SOLO para usuarios del portal; el acceso administrador
  siempre pide correo y contraseña (`shouldOfferBiometrics` exige
  `hasPortalAccess`, y `disableIfOwnedBy` apaga un enrolamiento viejo de una
  cuenta no-cliente al entrar).
- **Quién entra sale del PERFIL, no de la plataforma ni de un gesto.** El
  orden del gate es: cuenta desactivada → correo sin confirmar → acceso al
  portal (`PortalAccess.allows`: rol Cliente o comprador activo) →
  `debe_cambiar_password`. `canManageClientApp` manda al selector de clientes.
  Mismo flujo en web y en móvil.
- El modo administrador tiene DOS activaciones: long-press de 1.5 s sobre el
  sello de versión (toda plataforma) y Ctrl+Alt+A (solo web de escritorio).
  Encenderlo NO concede nada: el acceso lo decide `canManageClientApp` del
  perfil. El gesto solo revela la opción.
- El correo de recuperación NO usa el `/recover` de GoTrue (sin SMTP en este
  proyecto): va por la Edge Function `reset-user-password`, que envía por
  Postmark. Su enlace aterriza en `/auth/confirmacion-email`, ruta que fija el
  correo y que esta feature atiende: canjea el token, cierra el alta y deja
  que el guard lleve a cambiar contraseña.
- El cambio forzado de contraseña (temporal) es pantalla de esta feature; al
  terminar CIERRA la sesión y devuelve al login con el aviso, para que el
  usuario confirme que su contraseña nueva sirve. La biometría se ofrece en
  ese login siguiente, ya atada a la credencial definitiva.
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
