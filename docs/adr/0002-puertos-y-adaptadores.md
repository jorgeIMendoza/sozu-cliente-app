# ADR 0002 - Puertos y adaptadores para aislar el backend

- **Estado:** propuesto · inventario medido, nada implementado
- **Fecha:** 2026-07-31
- **Autor:** Eduardo Araujo
- **Alcance:** `sozu-cliente-app`. Complementa la Fase 1 de
  `0001-arquitectura-modular.md` ("cerrar la puerta de datos"), que quedó
  pendiente. No toca tokens ni design system.

---

## 1. Contexto (medido, no estimado)

| Métrica | Valor |
|---|---|
| Archivos Dart en `lib/` · LOC | 122 · 51,313 |
| Archivos que importan `supabase_flutter` en `lib/` | **9** (+1 en `test/`) |
| Funciones públicas en `data/api_client.dart` | **43** (+ `_invoke` privado) |
| Call sites de esas 43 funciones | **67** en **13** archivos |
| Funciones con parámetro `impersonate` | **27 / 43** (63%) |
| Archivos que importan `data/api_client.dart` | **13** |
| Archivos que mencionan `ApiError` | **3** · lo **atrapan**: **2** |
| Providers en `data_providers.dart` | **16** (15 llaman a `api_client`) |
| Tests en el repo | **286** en 23 archivos |
| Tests que prueban un provider o `api_client` | **0** |
| `models.dart` | 1,639 líneas · **0 imports** |

El "44" del encargo cuenta `_invoke`, que es privado. La API pública son 43.

### 1.1 El número que decide el ADR: cero tests de datos

286 tests y **ninguno** toca un provider, `api_client` ni el flujo de auth.
No es descuido: hoy es **imposible**. `test/features/auth/login_form_test.dart`
lo documenta en su propio setUp (líneas 29-43):

> `AuthController` toma `Supabase.instance.client` en un inicializador de campo,
> así que ni siquiera un `overrideWith` con una subclase lo evita: el
> constructor base corre igual.

Para montar **un formulario** el test necesita `Supabase.initialize` real, un
`EmptyLocalStorage`, un `_InMemoryPkceStorage` y un mock del canal de
`flutter_secure_storage`. Eso es la prueba empírica de que el backend no está
aislado: se filtra hasta el andamio de un test de widget.

### 1.2 `impersonate`: el dato que decide la forma del puerto

Las 27 funciones con `impersonate` son **exactamente** las de
`ClientPortalPort` (16) + `ProfilePort` (11). Las 16 sin él son **exactamente**
`AdminPort` (11) + `PushPort` (4) + `AppVersionPort` (1). El corte es perfecto,
no hay casos mixtos.

> **Decisión:** `impersonate` va en la **construcción** del puerto, no en cada
> método. `ClientPortalPort` y `ProfilePort` se construyen con el target activo;
> los otros tres puertos simplemente no lo tienen en su interfaz. Así 27 firmas
> pierden un parámetro opcional y desaparece la clase de bug "olvidé pasar
> `impersonate` en un método nuevo", que hoy el compilador no detecta.

Coste: cambiar de cliente impersonado invalida la instancia del puerto. Es lo
que ya pasa hoy de facto (los 15 providers observan `impersonationProvider` y
se re-ejecutan enteros).

### 1.3 `ApiError`: el acoplamiento sutil

`ApiError` y `DocumentoInvalidoError` se definen en `data/api_client.dart`.
Resultado: `pago_final_screen.dart:202` y `credito_hipotecario_drawer.dart:298`
importan **el archivo del backend** solo para escribir `on ApiError catch (e)`.
`expediente_screen.dart:148` hace lo mismo con `DocumentoInvalidoError`.

Es poco volumen (3 archivos) pero es el acoplamiento que ningún puerto arregla
solo: si el tipo de error vive con el adaptador, la UI sigue importando el
adaptador.

**Hallazgo aparte:** `isNotClientError` (`api_client.dart:18`) está definido y
tiene **0 usos**. Es código muerto; se borra, no se migra.

### 1.4 Tipos de Supabase en firmas públicas

Distinto de una llamada: una llamada se envuelve y se acabó; **un tipo en una
firma pública contamina a todo el que la consuma**.

`AuthController.session` es un `Session?` público (`auth_provider.dart:45`).
Hoy lo leen **7 archivos** fuera de `auth_provider`:

| Archivo | Qué usa | Rompe al cambiar el tipo |
|---|---|---|
| `router.dart:106,113` | `session == null` | no (solo nulidad) |
| `widgets/inactivity_watcher.dart:62,109` | `session != null` | no |
| `providers/data_providers.dart:25` | `.user.id` | **sí** |
| `features/auth/components/login_form.dart:191` | `.user.id` | **sí** |
| `widgets/push_registrar.dart:115` | `.user.email` | **sí** |
| `screens/inicio_screen.dart:53,880` | `.user.lastSignInAt` | **sí** |
| `providers/impersonation_provider.dart:24` | `.session?.user.id` (stream propio) | **sí** |

Ninguno de los 7 importa `supabase_flutter`: consumen el tipo
**estructuralmente**, vía inferencia. Es la peor variante, porque `grep import`
no los encuentra y el acoplamiento es invisible hasta que se cambia el tipo.

`BiometricService.persistirSesion(Session? session)` es la otra firma pública
con tipo de Supabase (2 llamadas, ambas en `auth_provider`).

**Lo que ya está bien hecho** y sirve de plantilla:
`AuthController.mensajeErrorAcceso(Object e)` acepta `Object`, no
`AuthException`, con el motivo escrito en su dartdoc (líneas 157-160). Y
`BiometricLoginResult` es un enum de dominio, no un tipo de gotrue. El patrón
existe; falta aplicarlo al resto.

---

## 2. Decisión

> **Arquitectura hexagonal parcial: 6 puertos en `lib/domain/`, adaptadores
> Supabase en `lib/data/adapters/`, inyección por Riverpod.** Sin UseCases, sin
> `Result`/`Either`, sin paquetes separados.

- `lib/domain/` define interfaces abstractas + los tipos de error. **No importa
  `supabase_flutter`, ni `flutter_riverpod`, ni `flutter/material`.**
- `lib/data/adapters/` implementa cada puerto contra Supabase. Es el **único**
  lugar (junto con `main.dart` y `secure_session_storage.dart`) donde
  `supabase_flutter` puede aparecer.
- Los providers dependen del puerto, nunca del adaptador. El wiring se hace en
  `main.dart` (composición) y se sustituye con `overrideWithValue` en tests.

Es la misma lógica que `lib/ui/` en el ADR 0001 §3: carpeta antes que paquete.
`lib/domain/` logra el aislamiento hoy; extraerlo a paquete después es un
`git mv` más reescritura de imports, y solo entonces el compilador verifica la
frontera. Hasta ese día la sostiene el lint.

### 2.1 Por qué puertos y no "mover todo a `api_client`"

La Fase 1 del ADR 0001 proponía justamente eso: centralizar los `invoke` en
`api_client`. Es necesario pero no suficiente: deja un `api_client` que sigue
importando `supabase_flutter` y siendo un módulo concreto. Con eso los tests de
§1.1 siguen siendo imposibles, que es el problema que hay que resolver.

### 2.2 Por qué 6 puertos y no 1

Un `BackendPort` de 43 métodos es `api_client` con `abstract` delante: para
fake-ear un test de pagos habría que implementar los avisos de admin. Los 6
grupos ya vienen dados por la edge function y, como muestra §1.2, coinciden con
el corte de `impersonate`.

---

## 3. Puntos de contacto

### 3.1 Los 9 archivos que importan `supabase_flutter`

Ordenados por gravedad.

| # | Archivo:línea | Qué llama | Capa | Puerto |
|---|---|---|---|---|
| 1 | `widgets/perfil_sheets.dart:81-92` | `Supabase.instance.client` · `auth.currentSession` · `auth.signInWithPassword` · `on AuthException` | **UI** (widget) | `AuthPort` |
| 2 | `widgets/push_registrar.dart:55-82` | `Supabase.instance.client` · `auth.currentSession.accessToken` · `realtime.setAuth` · `channel()` · `onPostgresChanges` sobre la tabla `notificaciones_cliente` · `subscribe` | **UI** (widget) | `PushPort` (ver §3.4) |
| 3 | `providers/auth_provider.dart:42,77,92,129,187,215,220,221,230,234,236,253` | `Supabase.instance.client` en inicializador de campo · `auth.currentSession` · `auth.onAuthStateChange` · `rpc('get_current_user_profile')` · `signInWithPassword` ×2 · `resetPasswordForEmail` · `updateUser(UserAttributes)` ×2 · `rpc('mark_password_changed')` ×2 · `auth.signOut` · tipos `SupabaseClient`, `Session`, `AuthState`, `AuthException` | provider | `AuthPort` |
| 4 | `features/auth/services/biometric_service.dart:112,204` | `auth.currentSession` (para `refreshToken` + `user.id`) · `auth.setSession(token)` · `on AuthRetryableFetchException` · `on AuthException` · `Session` en firma pública | servicio de feature | `AuthPort` |
| 5 | `core/portal_tracking.dart:28,37,55,69` | `Supabase.instance.client` · `rpc('register_portal_session')` · `rpc('touch_portal_session')` · `rpc('close_portal_session')` | **core** (acceso a red dentro de `core/`) | ninguno de los 6 (ver §3.4) |
| 6 | `data/api_client.dart:1,23,31,643` | `Supabase.instance.client` · `functions.invoke` ×2 (el genérico `_invoke` y uno a mano en `subirDocumentoExpediente`) · `on FunctionException` | data | los 5 puertos de datos |
| 7 | `providers/impersonation_provider.dart:22,23` | `auth.currentSession` · `auth.onAuthStateChange` (segundo listener del mismo stream) | provider | `AuthPort` (consumidor) |
| 8 | `main.dart:35-45` | `Supabase.initialize(url, anonKey, FlutterAuthClientOptions)` | bootstrap | **se queda** (raíz de composición) |
| 9 | `core/secure_session_storage.dart:10` | `extends LocalStorage` (implementa 5 overrides) | core | **se queda** (adaptador legítimo, §3.3) |

### 3.2 Detalle de las tres fugas que hay que caracterizar

**#1 `perfil_sheets.dart:81` es la peor.** `_PwGateSheetState._verify()` es el
gate de contraseña previo a un guardado sensible del Perfil (gracia de 90 s).
Desde el `State` de un widget hace: agarra el singleton de Supabase, lee el
email de la sesión actual, y **re-autentica con `signInWithPassword`** para
verificar que quien guarda es el dueño de la cuenta.

Lo que necesita para funcionar: el email de la sesión viva y una contraseña.
Devuelve un booleano.

Es un `AuthPort.verifyPassword(String password) -> bool` y nada más. Dos
agravantes:

- **Ya existe casi.** `AuthController.changePassword` (líneas 226-233) hace
  exactamente la misma re-autenticación y traduce el fallo a
  `WrongCurrentPasswordError`. El widget reimplementó a mano lógica que el
  provider ya tiene, con otro manejo de error.
- **`signInWithPassword` no es una consulta, es una transición de estado
  global.** Crea una sesión nueva, rota el refresh token e invalida el anterior,
  y dispara `onAuthStateChange` en los dos listeners (`auth_provider`,
  `impersonation_provider`), lo que a su vez re-persiste el token de biometría.
  Que un bottom sheet provoque todo eso es exactamente lo que los puertos
  existen para impedir. Hoy no rompe nada solo porque el `user.id` no cambia y
  el listener cae en la rama `notifyListeners()`.

**#3 `auth_provider.dart` filtra tipos, no solo llamadas.** Las 12 llamadas se
envuelven mecánicamente. El problema real es `Session? session` público: los **7
archivos** de §1.4, de los cuales **5 rompen** al cambiar el tipo porque leen
`.user.id`, `.user.email` o `.user.lastSignInAt`. El puerto tiene que exponer un
tipo de dominio con esos tres campos (más `refreshToken`, que necesita
`BiometricService`) y `AuthController.session` pasar a ser de ese tipo. Es el
único cambio del refactor que toca archivos que hoy no saben que existe Supabase.

Además, `AuthController` tiene `final SupabaseClient _sb = Supabase.instance.client`
como **inicializador de campo** (línea 42). Mientras eso siga ahí, ningún
`overrideWith` puede evitar que el constructor toque el singleton: el puerto
tiene que entrar por constructor o el refactor no compra nada (§6, riesgo 3).

**#4 `biometric_service.dart` usa `setSession` con un refresh token guardado.**
`loginBiometrico()` lee el refresh token de `FlutterSecureStorage`, pide la
huella, y llama `auth.setSession(token)` para **restaurar una sesión sin
contraseña**. Distingue tres fallos (`AuthRetryableFetchException` = red, token
sigue sirviendo; `AuthException` = token revocado, se borra; el resto =
expirado) y los mapea a `BiometricLoginResult`, que ya es un enum de dominio.

Necesita del puerto tres cosas: `setSession(refreshToken)` devolviendo la sesión
nueva o null, y los dos errores distinguibles como tipos de dominio
(`NetworkFailure` vs `AuthFailure`) porque el enum depende de esa diferencia.
`persistirSesion(Session?)` cambia a la sesión de dominio.

El `FlutterSecureStorage` de este archivo **no** es fuga: es almacenamiento
local del dispositivo, no el backend. Se queda.

**#6 `impersonation_provider.dart:23`** abre un **segundo** listener de
`onAuthStateChange` sobre el mismo stream, solo para detectar cambio de usuario
y limpiar el target. No necesita Supabase: necesita "avísame cuando cambie el
id de usuario". Consume `AuthPort.sessionChanges` (o incluso podría observar
`authProvider`). Ambos listeners tienen que migrar en la misma tanda: el stream
es uno.

### 3.3 Por qué `secure_session_storage.dart` NO es una fuga

Es la distinción que define el patrón. Los otros 8 archivos **llaman** a
Supabase: la dependencia va de nuestro código hacia la librería, y por eso la
librería aparece en medio de nuestra lógica.

`SecureSessionStorage extends LocalStorage` hace lo contrario: **implementa un
puerto que Supabase declara**. La dependencia va de Supabase hacia nosotros
(inversión de control); `Supabase.initialize` lo recibe por parámetro
(`main.dart:42`). En vocabulario hexagonal es un adaptador secundario, y está
del lado correcto de la frontera por definición: un adaptador *debe* conocer las
dos orillas. Ese es su trabajo.

Prueba de olfato: si mañana se cambia de backend, los 8 archivos de §3.1 hay que
reescribirlos; este se borra completo y su reemplazo se escribe una vez. No
contamina nada porque nadie más lo consume: **0 referencias** fuera de
`main.dart`.

Se queda donde está, con el nombre que tiene.

### 3.4 Dos contactos que NO encajan en los 6 puertos

Hay que decidirlo antes de empezar, no a mitad.

| Contacto | Por qué no encaja | Propuesta |
|---|---|---|
| `core/portal_tracking.dart` · 3 RPC `register/touch/close_portal_session` | Es telemetría ("Uso por portal" de Alta Dirección), no un dato del cliente. Pero está atada al ciclo de vida de la sesión: `cerrar()` **debe** correr antes de `signOut` porque necesita el JWT (`auth_provider.dart:252,268`) | Menos malo: `AuthPort`, porque es ciclo de vida de sesión y comparte el orden de operaciones. Más honesto: un 7º `SessionTrackingPort`. **Decisión de Eduardo.** En cualquier caso el archivo sale de `core/`: no es infraestructura neutral |
| `widgets/push_registrar.dart` · canal Realtime a la tabla `notificaciones_cliente` | `PushPort` son los 4 métodos de tokens FCM. Esto es una suscripción Postgres, y además es el **único acceso directo a una tabla** del repo. Alimenta la misma campana que los push | Extender `PushPort` con `Stream<void> notificacionesEntrantes({required String email})`. El widget pasa de 28 líneas de Supabase a un `ref.listen`. La policy RLS y `setAuth(jwt)` quedan dentro del adaptador |

El acceso a tabla es lectura del propio dueño vía RLS, así que no viola la regla
de seguridad de CLAUDE.md en la letra, pero sí en el espíritu ("CERO queries a
tablas"). Vale la pena que quede documentado dentro de un adaptador y no dentro
de un `build()`.

### 3.5 Las 43 funciones de `api_client`, por puerto

| Puerto | Funciones | Call sites | Archivos | `impersonate` | Providers a reconectar |
|---|---|---|---|---|---|
| `ClientPortalPort` | 16 | 29 | 8 | 16/16 | 9 |
| `ProfilePort` | 11 | 17 | 3 | 11/11 | 2 |
| `AdminPort` | 11 | 15 | 2 | 0/11 | 3 |
| `PushPort` | 4 | 5 | 2 | 0/4 | 0 |
| `AppVersionPort` | 1 | 1 | 1 | 0/1 | 1 |
| **Total** | **43** | **67** | **13** | **27** | **15** |

Reparto por edge function:

- `ClientPortalPort`: `cliente-resumen`, `cliente-menu`, `cliente-pagos`,
  `cliente-propiedades`, `cliente-propiedad-detalle`, `cliente-productos`,
  `cliente-documentos`, `cliente-notificaciones`, `cliente-estado-cuenta`,
  `cliente-estado-cuenta-pdf`, `cliente-datos-pago`, `cliente-recibo-pago`,
  `cliente-pago-final`.
- `ProfilePort`: `cliente-perfil` (9 acciones) + `cliente-expediente` (2).
- `AdminPort`: `admin-clientes` (2) + `admin-avisos-app` (9).
- `PushPort`: `cliente-push-token` (4 acciones) + el canal Realtime de §3.4.
- `AppVersionPort`: `cliente-app-version`.

Concentración de consumidores (los archivos que más cambian):
`data_providers.dart` 15 · `announcements_screen.dart` 12 ·
`perfil_sheets.dart` 10 · `expediente_screen.dart` 5.

---

## 4. Orden de migración

Camino crítico **secuencial**: puerto → adaptador → wiring → providers → UI. No
se puede paralelizar dentro de una tanda. Entre tandas sí, cuando no comparten
archivos.

**Criterio de "hecho" de cada tanda**, verificable con un comando:

```bash
# las edge functions / RPC de la tanda no se invocan fuera de su adaptador
grep -rn "supabase_flutter" lib/ --include=*.dart \
  | grep -vE 'lib/data/adapters/|lib/main\.dart|lib/core/secure_session_storage\.dart'
```

Ese grep arranca en 7 archivos (los 9 de §3.1 menos los 2 que se quedan) y cada
tanda lo baja. Al final: 0. Más: **al menos un test nuevo por tanda que fake-ee
el puerto**. Sin ese test la tanda no demostró nada.

### Tanda 0 - errores de dominio y `flutter test` en CI

Precondición, no opcional. El ADR 0001 §9-bis ya documenta que `analyze` limpio
no prueba que compile, y aquí se van a tocar 67 call sites.

1. `flutter test` en los 8 gates de CI (`codemagic.yaml` +
   `.github/workflows/`). Es lo que ya pide `ESTADO.md` §1.
2. Mover `ApiError`, `DocumentoInvalidoError` y `WrongCurrentPasswordError` a
   `lib/domain/errors.dart`. Borrar `isNotClientError` (0 usos).
3. Tras esto, los 3 archivos de UI de §1.3 importan `domain/errors.dart`, no
   `data/api_client.dart`.

Barato, sin riesgo, y desacopla el error del transporte antes de mover una sola
llamada.

### Tanda 1 - `AppVersionPort` (1 función, 1 provider)

La más chica del repo, extremo a extremo, con degradación ya incorporada
(`appVersionGateProvider` devuelve `null` ante cualquier error). Sirve para
fijar el patrón completo -interfaz, adaptador, provider del puerto, override en
test- con riesgo casi nulo. **Primer test que fake-ea un puerto: la prueba de
que el patrón funciona.**

### Tanda 2 - `PushPort` (4 funciones + Realtime)

Consumidores aislados: `core/push_service.dart` (3), `perfil_screen.dart` (2),
0 providers. Incluye sacar el canal Realtime de `push_registrar.dart` (§3.4).
**Cierra la primera fuga de UI** y no toca `auth`.

### Tanda 3 - `AuthPort` (camino crítico, la tanda grande)

Todo junto porque no se puede partir: el stream de `onAuthStateChange` es uno y
lo escuchan dos archivos; el tipo de sesión lo consumen 7.

Contenido: `auth_provider.dart` (12 llamadas + el tipo `Session`),
`biometric_service.dart` (`setSession` + `persistirSesion`),
`impersonation_provider.dart` (2), `perfil_sheets.dart:81-92` (el
`verifyPassword`), `portal_tracking.dart` (3 RPC, sujeto a la decisión de §3.4),
y los 5 archivos de §1.4 que rompen al cambiar el tipo.

Sub-orden dentro de la tanda:

1. Definir la sesión de dominio (`userId`, `email`, `lastSignInAt`,
   `refreshToken`) y los errores (`AuthFailure`, `NetworkFailure`).
2. Adaptador + inyección **por constructor** en `AuthController` (quitar el
   inicializador de campo de la línea 42).
3. Cambiar `AuthController.session` al tipo de dominio → arreglar los 5
   consumidores.
4. `verifyPassword` y borrar el Supabase de `perfil_sheets`.
5. Migrar `impersonation_provider` al stream del puerto.

Verificable al final: `login_form_test.dart` pierde su `setUpAll` de 25 líneas.
Ese es el criterio de éxito de la tanda, y de paso el retorno de todo el ADR.

**Se hace antes que los puertos de datos** aunque tenga menos volumen: es la que
elimina las 2 fugas graves (UI y tipos), y los puertos de datos son mecánicos y
no urgentes.

### Tanda 4 - `AdminPort` (11 funciones) · paralelizable con la 3

No comparte ni un archivo con la Tanda 3: solo `announcements_screen.dart` (12)
y 3 providers admin. Sin `impersonate`. Si hay dos manos, va en paralelo.

### Tanda 5 - `ClientPortalPort` (16 funciones, 29 sitios, 8 archivos)

El volumen. Aquí entra `impersonate` como dependencia de construcción (§1.2) y
se reconectan 9 providers. Toca `estado_cuenta_screen`, `pago_final_screen`,
`pagos_screen`, `pagar_screen`, `notificaciones_screen`,
`credito_hipotecario_drawer`, `recibo_pago_sheet`: mecánico, pero son los
archivos-Dios del ADR 0001 §1.4. **No se parten en esta tanda**: eso es el
refactor de features y mezclarlo hace el diff irrevisable.

### Tanda 6 - `ProfilePort` (11 funciones)

Última porque su consumidor principal es `perfil_sheets.dart` (10 sitios), el
archivo con más fugas del repo, y conviene que ya salga limpio de auth por la
Tanda 3. Más `expediente_screen.dart` (5) y 2 providers.

---

## 5. Lo que NO se hace

| No se hace | Por qué |
|---|---|
| **Duplicar o mapear los modelos de `models.dart`** | 1,639 líneas, 56 clases, **0 imports**: el archivo ya es agnóstico del backend. Los puertos devuelven esos mismos tipos. Un DTO por modelo más un mapper serían ~112 archivos nuevos y ~1,600 líneas de traducción de un tipo a un tipo idéntico. Decisión ya tomada por el owner |
| Partir `models.dart` por feature | Es la Fase 1 del ADR 0001, trabajo aparte. Mezclarlo hace el diff irrevisable |
| UseCases / capa de aplicación | ADR 0001 §2.1: el dominio vive en el backend, la app presenta datos. Un UseCase que solo delega es ceremonia |
| `Result` / `Either` | Los puertos siguen lanzando excepciones tipadas. Cambiar el modelo de error **y** el de transporte a la vez es un solo refactor con dos formas de fallar |
| Tocar `core/secure_session_storage.dart` | Es un adaptador legítimo (§3.3) |
| Paquetes separados con `melos` | Mismo criterio que `lib/ui/` (ADR 0001 §3): carpeta hoy, paquete cuando exista una segunda app |
| Mocks generados (`mockito` + `build_runner`) | Con 6 interfaces chicas, fakes escritos a mano se leen mejor y no agregan paso de build |
| Sacar `Supabase.initialize` de `main.dart` | Es la raíz de composición. Ahí es donde debe estar |
| Migrar `screens/` a `features/` de paso | Cambio de estructura **y** de dependencias en el mismo PR: nadie puede revisar eso |

---

## 6. Consecuencias

**A favor**

- Los tests de provider y de flujo de auth pasan de imposibles a triviales. Hoy
  son 0 de 286.
- `login_form_test.dart` pierde 25 líneas de andamio; el próximo test de widget
  no las escribe.
- 27 firmas pierden el parámetro `impersonate`, y con él la clase de bug
  "olvidé pasarlo".
- La UI deja de importar el archivo del backend para atrapar un error.
- Cambiar de backend, o mockear uno para desarrollo offline, pasa a ser tocar
  `lib/data/adapters/`.
- El grep de §4 es un invariante verificable, no una convención de code review.

**En contra / costos**

- ~15 archivos nuevos (6 interfaces, 6 adaptadores, errores, sesión de dominio,
  providers de wiring) por cero funcionalidad nueva.
- Un salto de indirección: leer "de dónde sale este dato" pasa de 1 a 2 hops.
- Durante el refactor conviven llamadas directas y llamadas por puerto. Estado
  intermedio inevitable, igual que en la Fase 4 del ADR 0001.
- La Tanda 3 no se puede partir en PRs chicos sin dejar el árbol roto a medias.

**Riesgos y mitigación**

| Riesgo | Mitigación |
|---|---|
| **Alcance:** 43 funciones, 67 call sites, ~30 archivos entre los 13 de `api_client`, los 9 de `supabase_flutter` y los 7 que leen `.session` | Las 6 tandas de §4, cada una con su grep y su test. No se abre una sin cerrar la anterior |
| **Camino crítico secuencial:** adaptadores necesitan puertos, providers necesitan adaptadores | Tandas 1 y 2 son chicas y prueban el patrón antes de la grande. La 4 va en paralelo a la 3 |
| **El refactor se hace y no compra nada:** puertos definidos pero `AuthController` sigue con `Supabase.instance.client` en un inicializador de campo | Criterio de aceptación de la Tanda 3: `login_form_test.dart` **sin** `Supabase.initialize`. Si el test no adelgaza, la tanda no está hecha |
| **Verificación solo con `analyze`** sobre 67 call sites | Tanda 0: `flutter test` en CI. ADR 0001 §9-bis: analyze limpio no prueba que compile |
| Regresión en el orden de operaciones de auth (`PortalTracking.cerrar()` antes de `signOut`, rotación del refresh token de biometría) | Es la parte con más comentarios de "por qué" del repo. Test de secuencia sobre el `AuthPort` fake, en la misma tanda |
| Cambiar de cliente impersonado ya no invalida el puerto y queda una instancia con el target viejo | El puerto se construye desde un provider que observa `impersonationProvider`, igual que hoy los 15 providers |
| §3.4 se decide a mitad del refactor | Se decide antes de la Tanda 2 (Realtime) y de la 3 (tracking) |
| La Tanda 5 tienta a partir los archivos-Dios "ya que estoy" | Prohibido en este ADR (§5) |

---

## 7. Decisiones pendientes (bloquean tandas concretas)

1. **`portal_tracking` (3 RPC): `AuthPort` o un 7º `SessionTrackingPort`.**
   Bloquea la Tanda 3. Ver §3.4.
2. **El canal Realtime de `notificaciones_cliente` dentro de `PushPort`,** o
   puerto propio. Bloquea la Tanda 2. Ver §3.4.
3. **Nombre y forma del tipo de sesión de dominio.** Necesita 4 campos
   (`userId`, `email`, `lastSignInAt`, `refreshToken`). Bloquea la Tanda 3 y es
   lo único que toca archivos que hoy no saben que Supabase existe.
