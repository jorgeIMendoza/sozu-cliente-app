# Proyecto: SOZU - Portal del Cliente (app Flutter multiplataforma)

Port 1:1 del app RN (`../sozu-cliente-rn-app`). Misma funcionalidad, mismo
backend (Edge Functions en admin_sozu). Código compartido en `lib/`;
plataformas: `android/`, `ios/` (build requiere Mac), `web/` (target principal
de prueba: Chrome).

## Stack
- Flutter stable (SDK en ~/flutter dentro de WSL/Arch) + Dart. Material 3.
- Estado/datos: flutter_riverpod (FutureProvider por endpoint).
- Navegación: go_router (guards de sesión + cambio de contraseña forzado,
  StatefulShellRoute con 5 tabs).
- Backend: supabase_flutter (Auth + functions.invoke + RPC).
- Sesión/tokens: flutter_secure_storage vía `SecureSessionStorage`
  (lib/core/secure_session_storage.dart). NUNCA SharedPreferences para tokens.
  Caveat web: cae al storage del navegador (limitación de plataforma).
- Env: flutter_dotenv (.env gitignored; ver .env.example).
- Formato: intl (MXN 2 decimales, fechas DD/MM/YYYY).
- Versión (misma metodología que sozu-admin): `vX.Y.Z-YYMMDD.HHMM` en el footer
  del login, definida en lib/core/version.dart. En cada build/entrega actualizar
  `_buildTimestampDefault` (PowerShell: `Get-Date -Format "yyMMdd.HHmm"`) o
  compilar con `--dart-define=BUILD_TIMESTAMP=...`.
- **El `X.Y.Z` NO se sube a mano y el estado vive en los TAGS de git**, no en
  `pubspec.yaml`. Se publica desde `main`, que está protegida (`enforce_admins`,
  review de code owner), así que el CI no puede commitear ahí; los tags sí se
  pueden pushear. `bump_release_version` (codemagic.yaml) resuelve la versión
  desde el tag `vX.Y.Z` más alto, la escribe en pubspec/version.dart **solo en el
  workspace del build** y tagea HEAD. Si HEAD ya trae tag, es la segunda tienda
  de la misma tanda y reusa la versión: Android e iOS nunca divergen. El
  versionCode/CFBundleVersion va por separado, calculado desde cada tienda.
  Por eso `pubspec.yaml` en el repo se queda atrás: es solo el piso inicial.
- El aviso in-app lo enciende `app_cliente_config.latest_version`, que escribe el
  CI vía la edge function `app-version-publicar` al publicar **a producción**
  (no en Play interno ni TestFlight). Requiere el secret
  `APP_VERSION_PUBLISH_SECRET` en Supabase y en Codemagic; el setup y el fallback
  manual están en
  `Ejecuciones_manuales/2026-08-07_version_gate_latest_por_release.md`.
  `min_version` (forzar) sigue siendo manual a propósito: es decisión de negocio.

## Rama de trabajo
`dev-eddy` es la unica rama de trabajo. De ahi salen los PR hacia `dev`. NO se
reescribe el historial: los mensajes de commit son la documentacion de por que
cada decision se tomo, y esto va a produccion.

## Ejecuciones manuales (SQL / deploys de Edge Functions)
- PROHIBIDO ejecutar SQL o `supabase functions deploy` directo desde aquí.
- Todo cambio de BD/deploy va primero a un `.md` en `Ejecuciones_manuales/`
  (gitignored; patrón de admin-sozu/sozu-admin: secciones fechadas + comandos
  exactos). Jorge lo ejecuta a mano y reporta.

## Quien entra al Portal del Cliente
Dos caminos, no uno (`features/auth/services/portal_access.dart`):
**rol Cliente (`roles.id` 23) O comprador activo** (`compradores.activo`, que
llega como `es_comprador` en el RPC del perfil). El rol dice para que se
contrato a la persona, no si compro: hay 8 internos (agentes, etc.) que son
clientes de SOZU.

⚠️ **El gate esta DUPLICADO y los dos lados se cambian juntos.** El de verdad es
`_shared/cliente.ts` -> `authClient()` en `sozu-edge-functions`: si el frontend
deja pasar y el backend no, el usuario entra y recibe **403 en cada pantalla**.
`PortalAccess.allows` es el espejo del gate del backend, y `test/features/auth/
portal_access_test.dart` fija el contrato.

`isBuyer` es aditivo: sin `es_comprador` en el RPC se lee `false` y el acceso
queda como antes (solo rol 23), asi que frontend y backend no necesitan
despliegue simultaneo. El orden seguro es backend primero.

El acceso administrador es OTRA COSA: va por `canManageClientApp`
(`roles.apps.administrar` incluye `clientes`), no por aqui.

## Reglas de SEGURIDAD (innegociables - mismas que el app RN)
- SOLO Supabase ANON KEY (pública) + JWT del usuario logueado.
- NUNCA service_role ni credenciales de BD en el código.
- CERO queries a tablas: todo dato sensible vía Edge Functions
  (cliente-resumen, cliente-pagos, cliente-propiedades,
  cliente-propiedad-detalle, cliente-perfil, cliente-documentos,
  cliente-notificaciones) + 2 RPC SECURITY DEFINER
  (get_current_user_profile, mark_password_changed).
- No loguear PII (RFC, CURP, CLABE, montos).
- Documentos/recibos/CEP: URLs firmadas temporales que entrega el backend.

## Design system - lib/ui/ (FUENTE DE VERDAD de la apariencia)
Este repo es la fuente de verdad del Portal del Cliente. `sozu-admin` YA NO se
trabaja para el portal cliente; su `src/components/portal/` es legacy.

- `lib/ui/` es el design system. Import único: `import '../ui/ui.dart';`
- Acceso a tokens: **`context.s`**
  - `context.s.color.<rol>` - 27 roles semánticos (`fg`, `fgMuted`, `fgSubtle`,
    `surface`, `surfaceAlt`, `background`, `muted`, `border`, `borderSoft`,
    `primary`, `primaryHover`, `primarySoft`, `positive`, `warning`,
    `warningFg`, `danger`, …)
  - `context.s.text.*` - escala tipográfica (respeta densidad; preferir sobre
    `SozuType.*`, que no la respeta)
  - `context.s.radius.*` / `.space.*` / `.shadow.*`
  - `context.responsive(mobile:, tablet:, desktop:)` y `context.bp`
- PROHIBIDO en pantallas: `Color(0x...)`, `circular(16)`, `fontSize: 14`,
  `EdgeInsets.all(14)`. Si el valor no existe, se agrega a `lib/ui/tokens/`.
- `lib/ui/` NO puede importar `supabase_flutter`, `flutter_riverpod` ni `data/`.
  Un componente que necesita datos los recibe por parámetro. Esta es la
  frontera UI ↔ lógica de negocio.
- **NADA DE ALIAS NI MAPEOS SILENCIOSOS.** Un token tiene UN nombre y ese nombre
  se usa en toda la app. `SozuColors`, `SozuTone`, `core/theme.dart` fueron
  ELIMINADOS (no deprecados: borrados). Si un renombre cabe en un commit, se hace
  en todos los usos en el mismo commit - una capa de compatibilidad muda es cómo
  nació la paleta bifurcada.
- **Puente `@Deprecated`, la ÚNICA excepción permitida:** cuando el renombre
  cruza tandas, el nombre viejo sobrevive como referencia `@Deprecated('Usar X')`
  que apunta al nuevo. Es distinto de un alias porque el analyzer marca cada uso:
  el legacy queda visible y medible. Condiciones: el nuevo es el canónico, nada
  nuevo usa el viejo, y **una feature NO se cierra con usos deprecados dentro**
  (la auditoría los cuenta como legacy); al llegar a 0 usos, el puente se borra.
- **ÚNICO pendiente de homogeneizar:** `core/portal_theme.dart` (`PortalColors`,
  `isPortalMode()`, `kPortalRadius*`, `kPortalFontFallback` que ya no hace nada).
  749 referencias, ~137 dentro de expresiones `const`: pasar a `context.s.color`
  rompe la const-ness y hay que quitar el `const` caso por caso. Requiere
  compilador, no se puede hacer a ciegas. Tabla de migración campo→rol en el
  docstring del archivo.
- `SozuTheme` (ThemeExtension): su campo tipográfico se llama `text`, NO `type`.
  `ThemeExtension.type` es la clave del mapa de extensiones de Material;
  pisarla compila pero rompe `extension<SozuTheme>()` en silencio.
- Plan y decisiones: `docs/adr/0001-arquitectura-modular.md`.
  `docs/web_portal_spec/tokens.md` es documentación derivada, ya no contrato.

## Puertos y adaptadores (hexagonal)
- Contratos en `features/<f>/ports/` (o `shared/ports/` si los consumen 2+
  features). Implementaciones en `features/<f>/adapters/`.
- **PROHIBIDO el vendor en nombres**: ni archivos ni clases ni identificadores
  llevan "supabase". Se nombra por ROL: `AuthPort` / `AuthAdapter`. El vendor
  solo aparece dentro del adaptador (import + una línea de dartdoc). Si el
  backend cambia, se reescribe el interior y ningún nombre queda mintiendo.
- Los puertos importan SOLO `data/models.dart` y `shared/api_error.dart`.
  Ni flutter, ni riverpod, ni el SDK del backend. Verificable con grep.
- ADR: `docs/adr/0002-puertos-y-adaptadores.md`.

## Estructura de una feature (patrón obligatorio para código nuevo)

```
lib/features/<feature>/
├── layouts/       ← ESTRUCTURA que envuelve pantallas
├── screens/       ← las pantallas: SOLO composición
├── components/    ← piezas REUTILIZABLES
└── services/      ← lógica SIN UI (solo si la feature la tiene)
```

Criterio de cada carpeta:

- **`layouts/`** - envuelve pantallas y decide tema, scroll y breakpoints. No es
  un componente (no es una pieza de interfaz) ni una pantalla (no es un destino
  de ruta). Por eso tiene carpeta propia.
- **`components/`** - solo si es **reutilizable** (lo usan 2+ pantallas). NO
  partir algo en componentes por partirlo: si una pantalla tiene un formulario
  único, es **un** componente de formulario y ya. Fragmentarlo en sub-piezas de
  un solo uso agrega archivos sin quitar acoplamiento.
- **`services/`** - lógica de negocio propia de la feature: plugins de
  plataforma, almacenamiento, sesión. NO importa `material.dart`. Solo se crea si
  la feature tiene lógica que no es de UI (hoy: `auth/services/biometric_service`).
  No es `data/`: en este repo `lib/data/` son los DTOs de las Edge Functions.
- **`screens/`** - no tienen lógica ni estado propio: ensamblan layout +
  componentes. Si una pantalla tiene un `State` con lógica, esa lógica va a un
  componente.

Los componentes visuales son **tontos**: reciben datos por parámetro, no leen
providers ni navegan. Quien lee providers es la pantalla o el componente con
estado (p. ej. `login_form`).

**`features/auth/` está CERRADA** (0 legacy, auditada). Es la plantilla: ante
cualquier duda de "¿dónde va esto?", ver `lib/features/auth/README.md`.

```
layouts/auth_layout.dart        AuthLayout + AuthFormBody
screens/login_screen.dart       40 líneas: AuthLayout(brand:, child:)
screens/forgot_password_screen.dart · change_password_screen.dart
components/auth_brand_image.dart · auth_header.dart · auth_alert.dart
components/biometric_setup_sheet.dart · biometric_toggle_card.dart · login_form.dart
services/biometric_service.dart BiometricService · BiometricLoginResult
services/portal_access.dart     PortalAccess.allows (quien entra al portal)
```

Toda la biometría (huella / Face ID) vive en `auth`: es autenticación. El servicio,
la oferta post-login y el switch de Perfil son el mismo mecanismo.
`BiometricToggleCard` lo consume `screens/perfil_screen.dart` (legacy): es API
pública de la feature, no un motivo para duplicarlo ni dejar un alias.

**`features/admin/` está CERRADA** (design system + hexagonal). Detalle y deuda
pendiente en `lib/features/admin/README.md`.

```
ports/admin_port.dart           AdminPort (12 métodos)
adapters/admin_adapter.dart     AdminAdapter - único con supabase_flutter
providers/admin_providers.dart · impersonation_provider.dart
layouts/admin_layout.dart       AdminLayout + AdminScrollArea
screens/select_client_screen.dart · announcements_screen.dart
components/admin_header_bar.dart · client_filters.dart · client_row.dart
```

`AdminScrollArea`: el scroll envuelve al limitador de ancho, NO al revés. Al
revés, la rueda del ratón solo mueve la columna de contenido y en los laterales
la página no responde. Por lo mismo las rutas de admin van `sinMarco: true` en el
router: el `WebFrame` volvía a meter el limitador por fuera.

Se migra de a una feature. `lib/screens/` y `lib/widgets/` son legacy: **siguen
funcionando y no se tocan salvo para migrarlos**, pero nada nuevo va ahí.

### Al cerrar una feature, auditar que no quede legacy
```bash
F=lib/features/auth
for p in "PortalColors" "isPortalMode" "SozuType\." "Color(0x" "fontSize:" \
         "circular([0-9]" "EdgeInsets.all([0-9]" "import '\.\./"; do
  # -H es obligatorio: sin el prefijo de archivo (p.ej. al auditar UN archivo)
  # la salida es "80:///..." y el filtro de dartdoc no coincide.
  printf "%-26s %s\n" "$p" "$(grep -rHn "$p" $F --include=*.dart | grep -vE ':[0-9]+: *///' | wc -l)"
done
```
Todo debe dar 0.

## Imports: SIEMPRE `package:`
```dart
import 'package:sozu_cliente_app/ui/ui.dart';   // ✅ el equivalente de @/ui en TS
import '../../../../ui/ui.dart';                 // ❌
```
Dart no permite alias arbitrarios (no existe `@/ui`), pero los imports `package:`
cumplen la misma función: la ruta no depende de dónde está el archivo, así que
mover un archivo no rompe nada. Lo obliga el lint `always_use_package_imports`.

Única excepción: los **imports/exports condicionales**
(`if (dart.library.js_interop)`) resuelven por ruta relativa. Van con
`// ignore: always_use_package_imports` y el motivo.

## Lint y formato desde consola (== lo que hace el IDE)
```bash
./tool/check.sh              # formatea lo MODIFICADO + analyze + tests
./tool/check.sh --fix        # + aplica los quick-fix automáticos
./tool/check.sh --all        # formatea TODO (ojo: churn, ver abajo)
./tool/check.sh --no-tests   # más rápido
```
Equivalencias con Cursor/VS Code:

| Consola | IDE |
|---|---|
| `dart format` | Format Document (Shift+Alt+F) |
| `flutter analyze` | panel de Problems |
| `dart fix --apply` | los Quick Fix (💡) en lote |

El IDE usa el Dart Analysis Server, que lee el **mismo** `analysis_options.yaml`;
por eso `flutter analyze` y el panel de Problems dan idéntico resultado.

`check.sh` y el CI corren `flutter analyze --no-fatal-infos`: **errores y warnings
son fatales, los infos no**. Hoy hay ~690 infos y todos son la deuda conocida de
`PortalColors` deprecado; con infos fatales el check salía siempre rojo y se
aprendía a ignorarlo. `check.sh` imprime el conteo para que una subida se note.
Al cerrar `PortalColors` hay que quitar el flag en los tres sitios (`check.sh`,
`.github/workflows/deploy-web-firebase.yml`, `codemagic.yaml`).

⚠️ **`--no-fatal-infos` YA NO cambia el código de salida en este Flutter**:
`flutter analyze --no-fatal-infos` devuelve **1** aunque solo haya infos
(comprobado el 2026-08-07 con el árbol limpio en `dev`). Por eso `check.sh`
marca `✗ analyze encontro errores o warnings` sin que haya ninguno. Es
preexistente, no lo introduce ningún cambio: para saber si de verdad hay algo
fatal, `flutter analyze 2>&1 | grep -E '^\s+(error|warning)'`. Arreglar
`check.sh` (contar errores/warnings en vez de mirar el exit code) es su propio
commit.

⚠️ **El repo NO está formateado con el formatter actual** (Dart 3.7 cambió a
"tall style"). Por eso `check.sh` formatea solo los archivos modificados: un
`dart format .` reescribe medio archivo ajeno. Cuando se haga, que sea un commit
que **solo** sea formato.

## Medir rendimiento: NUNCA en debug
`./tool/dev.sh` corre en modo debug y en web eso es DDC sin optimizar: varias
veces mas lento que release, y el coste escala con el numero de widgets. Una
pantalla densa se siente pesada aunque en produccion vaya bien.
- `PROFILE=1 ./tool/dev.sh` - tiempos reales (sin hot reload)
- `./tool/web.sh` - release servido en :5001, con fallback SPA
- `./tool/apk.sh` - APK release

Los dos ultimos compilan con `APP_ENV=prod`, asi que no sale la franja de PREVIEW:
`isPreviewBuild` es constante de compilacion y dart2js borra la rama completa.

## Tiempos de build (esperados, no un problema)
- `flutter build web --release`: ~110-150 s. dart2js optimiza el programa
  completo; no es incremental por diseño.
- `./tool/dev.sh`: primera compilación ~30-60 s, luego `r` (hot reload) < 1 s.
- Si dev se siente lento: revisar que no haya un **error de compilación**. Con un
  error, cada intento rehace el build completo y no hay incremental.
- Cambios en `pubspec.yaml` (assets, fuentes, dependencias) exigen **matar y
  relanzar** `dev.sh`. Ni `r` ni `R` los toman.

## Estructura lib/
- ui/: design system (tokens + tema + primitivas). Ver sección anterior.
  22 primitivas: SButton · STextField · SCard · SBadge · SAvatar · SProgressBar ·
  SSkeleton · SEmptyState · SErrorState · SSectionLabel · SPressable · SStagger ·
  SSearchField · SAutocompleteField · SLogo · SWebSelectable · SDropZone ·
  SPdfPreview · SDocUpload · SConfirm · SSelectField · SFieldLabel.
  `widgets/common.dart` fue ELIMINADO: sus 8 widgets viven aquí.
  `SDocUpload` es la modal global de carga: tipo, archivo, previsualización y
  los datos extraídos editables. La extracción y la subida las hace quien la
  abre; el componente no sabe de backend.
- features/: TODO el código de producto, por feature. `auth/` (cerrada),
  `admin/` (cerrada), `client/` (expediente, facturacion, home, layouts,
  products, profile, properties, referral, providers).
- core/: format, secure_session_storage, open_document, file_download,
  file_drop, version, push_service, portal_tracking, portal_theme (legacy). La
  biometría salió a `features/auth/`.
- data/: models (DTOs de las 7 functions)
- shared/: ports + adapters + providers que consumen 2+ features, api_error
- router.dart: guards + shell 5 tabs + secundarias
- widgets/: LEGACY - portal_widgets, fx, network_image, preview_banner,
  push_registrar, version_gate, whatsapp_icon. La carpeta admin/ salio a
  features/admin/components/.
- `lib/screens/` y `lib/providers/` YA NO EXISTEN: sus pantallas viven en
  `features/client/*/screens/` y sus providers en la feature que los usa.

## Sesión
- Cierre por inactividad: **5 min en teléfono, 15 min en escritorio**
  (`features/auth/components/inactivity_watcher.dart`). El criterio es el FORMATO
  de pantalla, no
  `kIsWeb`: web en el navegador del celular usa el plazo corto.

## Tema: claro/oscuro SÍ, pero el portal ancho va con candado a claro
El selector vive en Perfil (`features/client/profile/components/theme_selector.dart`)
y la preferencia se persiste en `shared/providers/theme_provider.dart`
(`shared_preferences`; no es dato sensible).

`main.dart` pasa el `themeMode` del provider Y envuelve el árbol en
**`PortalLightLock`**, que fuerza claro cuando `isPortalMode(context)` es true
(web con ancho ≥ `kPortalBreakpoint`). Motivo: el portal pinta con el shim
`PortalColors`, cuyas constantes son claras y no dependen del tema, así que en
oscuro solo cambiaría lo ya migrado a `context.s` y sale texto claro sobre
fondo claro. En móvil/angosto las pantallas sí leen los roles, así que ahí el
selector manda de verdad.

El candado usa `isPortalMode` **a propósito aunque esté deprecado**: tiene que
decidir con el mismo criterio que las 22 pantallas que ramifican por él
(incluido su `kIsWeb`). Si discrepan, salen temas mezclados. Migra cuando ellas
migren a `context.bp`.

Al terminar `PortalColors -> context.s.color`, borrar `PortalLightLock` y el
oscuro queda global. Tests: `test/theme_mode_test.dart`; la rama del portal solo
se verifica con `flutter test --platform chrome` (en la VM `kIsWeb` es false).

## Correr
**Guía completa del flujo diario: `tool/README.md`** (web, móvil inalámbrico, las
dos a la vez, y las cosas que se olvidan).

- Web (principal): `./tool/dev.sh` → http://localhost:5000 (envuelve
  `flutter run -d web-server`, inyecta BUILD_TIMESTAMP y valida assets/env).
  Escucha en 0.0.0.0, así que también se abre desde el navegador de Windows y
  desde el celular en la misma red. En la terminal: `r` hot reload, `R` hot
  restart, `q` salir.
- Requiere `export PATH="$HOME/flutter/bin:$PATH"` (ya lo hace dev.sh) y el
  archivo `assets/env` (gitignored; copiar de .env.example).
- **Android en físico (funciona, probado en Oppo CPH2577 / Android 15):**
  1. En Windows, con `platform-tools` descomprimido, dejar corriendo:
     `.\adb.exe -a -P 5037 nodaemon server` (el flag `-a` es obligatorio: sin él
     escucha solo en 127.0.0.1 y WSL no lo alcanza).
  2. En WSL: `./tool/dev.sh <device-id>` - resuelve el puente solo (IP del host
     vía `ip route`, valida el puerto 5037 antes de arrancar).
  - Detalle y diagnóstico: `tool/android-usb.md`.
  - APK: `./tool/apk.sh [--debug|--fat|--install]` - lo copia a Descargas de
    Windows. En Oppo hace falta modo USB "Transferir archivos" (no "Solo carga")
    y "Desactivar monitoreo de permisos" en Opciones de desarrollador.
  - Toolchain: Temurin 21 en `~/jdk21`, SDK en `~/android-sdk` (compileSdk 36).
    Reinstalar con `./tool/install-temurin.sh` + `./tool/android-setup.sh`.
- iOS: requiere Mac/Xcode; la carpeta ios/ queda lista.

## Reglas de código
- **dartdoc CONCISO**, estilo javadoc/doxygen: 1-3 líneas por miembro. Frase de
  resumen primero, después SOLO lo que no es obvio del nombre y la firma.
  - El **por qué** de una decisión va en el mensaje de commit o en `docs/adr/`,
    NO encima de un campo. Ahí se pierde y envejece.
  - Excepción: una trampa que **muerde en silencio** se documenta en el sitio, en
    2-3 líneas. Hay tres hoy: `context.s` dentro de un `const`, el campo `type`
    de `ThemeExtension`, y `SPressable.detector` (sin capa de gesto no hay foco
    de teclado).
  - Un bloque `///` de más de 10 líneas es señal de que sobra. Los de clase
    pueden llegar a ~15 si documentan la API de un componente global.
  - Se aplica a código NUEVO. El legacy se poda al migrarlo, no antes.
- **NUNCA guiones medios largos.** Solo el guion normal `-`. Prohibidos `—` (em
  dash) y `–` (en dash) en código, comentarios, docs, strings de UI y mensajes de
  commit. Como separador en texto visible se usa `·` (punto medio) o `-`.
  Única excepción: estas dos líneas, que tienen que nombrar los caracteres.
  Verificar antes de commitear:
  ```bash
  grep -rP '[\x{2014}\x{2013}]' --include="*.dart" --include="*.md" \
       --include="*.yaml" --include="*.html" lib test docs *.md *.yaml \
    | grep -v '^CLAUDE.md'
  ```
  Debe salir vacío.
- La versión WEB debe ser RESPONSIVE (móvil/tablet/desktop): contenido con
  max-width centrado en pantallas anchas (WebFrame), FittedBox/Wrap para
  cifras. Probar en Chrome ancho + ventana angosta + iPhone Safari.
- Cada pantalla maneja carga (skeleton) / vacío / error+reintentar y
  pull-to-refresh.
- Fechas DD/MM/YYYY; moneda $9,324,282.24; compacto $2.46M.
- Este repo es SOLO FRONTEND. El backend vive en otros repos:
  - Edge Functions (incluidas las cliente-*): Escritorio/admin-sozu/sozu-edge-functions
    (CI: rama dev → deploy DEV; PR dev→main → deploy PRD a admin_sozu).
  - Migraciones SQL: Escritorio/admin-sozu/sozu-supabase-migrations.
  - ../sozu-cliente-rn-app/supabase/functions es copia legacy, NO fuente de verdad.
