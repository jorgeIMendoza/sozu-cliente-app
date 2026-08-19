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
- **El contador lo mueve SOLO quien publica a tiendas; la web lo LEE.** La web
  se despliega en cada merge a `main` y las tiendas una vez por semana: si la
  web también bumpeara, se adelantaría sin parar y las tiendas nunca la
  alcanzarían (pasó el 2026-08-13: web 1.0.5 contra Play 1.0.4). El `X.Y.Z`
  identifica el RELEASE; los builds web intermedios se distinguen por el
  `-YYMMDD.HHMM` del mismo footer.
  Para que la web no se quede atrás, `redesplegar_web` (codemagic.yaml) hace
  `repository_dispatch: tiendas-publicadas` al terminar de publicar a
  producción, y el deploy web se rehace con el tag recién creado. Es
  `repository_dispatch` y no `workflow_dispatch` porque al primero le basta el
  permiso `Contents: write` que el PAT ya tiene para los tags.
  WARN: Si algún día la web vuelve a tagear, se rompe además el fallback de
  `publicar_version_al_gate` en los workflows de promoción (no compilan, así que
  toman "el último tag" como la versión publicada) y el aviso in-app apuntaría a
  una versión que no existe en la tienda.
- El aviso in-app lo enciende `app_cliente_config.latest_version`, que escribe el
  CI vía la edge function `app-version-publicar` al publicar **a producción**
  (no en Play interno ni TestFlight). Requiere el secret
  `APP_VERSION_PUBLISH_SECRET` en Supabase y en Codemagic; el setup y el fallback
  manual están en
  `Ejecuciones_manuales/2026-08-07_version_gate_latest_por_release.md`.
  `min_version` (forzar) sigue siendo manual a propósito: es decisión de negocio.
- **Los dos niveles del aviso se comportan distinto a propósito** (`widgets/
  version_gate.dart`). El SUAVE (`latest_version`) sale una vez al abrir, se
  puede posponer con "Ahora no" y se calla hasta el día siguiente o hasta que
  salga una versión posterior; la memoria vive en `shared/providers/
  update_prompt_provider.dart` (`shared_preferences`, no es dato sensible). El
  FORZADO (`min_version` / `force_update`) es pantalla completa sin salida.
  Antes el suave era una franja fija en todas las pantallas sin manera de
  descartarla: molestaba siempre y aun así no obligaba a nada.
- **La palanca que mantiene al parque al día es `min_version`, no el aviso.**
  Dejarlo un par de versiones por detrás de la publicada saca a los muy
  rezagados sin bloquear a quien va al corriente; el aviso suave se encarga del
  resto. En WEB nada de esto aplica: se actualiza sola al recargar.

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

WARN: **El gate esta DUPLICADO y los dos lados se cambian juntos.** El de verdad es
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
  605 referencias de `PortalColors` y 34 usos de `isPortalMode` en 28 archivos;
  ~137 dentro de expresiones `const`: pasar a `context.s.color` rompe la
  const-ness y hay que quitar el `const` caso por caso. Requiere compilador, no
  se puede hacer a ciegas. Tabla de migración campo→rol en el docstring del
  archivo. El reparto por feature está en `docs/adr/ESTADO.md`: `properties`
  concentra el 60%.
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
`BiometricToggleCard` lo consume `features/client/profile/screens/perfil_screen.dart`:
es API pública de la feature, no un motivo para duplicarlo ni dejar un alias.

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
for p in "PortalColors" "isPortalMode" "SozuType\." "SozuBrand\." "Color\(0x" \
         "fontSize:" "circular\([0-9]" \
         "EdgeInsets\.(all|symmetric|only|fromLTRB)\([a-z]*:? ?[0-9]" \
         "SizedBox\((height|width): [0-9]" "^import '\.\./"; do
  # -H es obligatorio: sin el prefijo de archivo (p.ej. al auditar UN archivo)
  # la salida es "80:///..." y el filtro de dartdoc no coincide.
  # -E obliga a escapar los parentesis literales: `Color(0x` sin escapar es un
  # grupo sin cerrar y grep aborta con "mismatched ( )".
  printf "  %-56s %s\n" "$p" "$(grep -rHnE "$p" $F --include=*.dart | grep -vE ':[0-9]+: *///' | wc -l)"
done
```
Todo debe dar 0.

WARN: **Tres de esos patrones se agregaron el 2026-08-17 porque el grep viejo
declaraba features "cerradas" que no lo estaban.** No son adorno:

- **`SizedBox\((height|width): [0-9]`** - `SizedBox(height: 24)` es un espaciado
  crudo igual que `EdgeInsets.all(24)`, y es la forma MÁS común de meter uno en
  Flutter. El grep viejo no lo veía: 771 en `client`. Los atajos existen desde
  siempre (`context.s.space.gapMd`, `gapLg`).
- **`EdgeInsets\.(symmetric|only|fromLTRB)`** - el grep viejo solo miraba
  `EdgeInsets.all`, así que `EdgeInsets.symmetric(vertical: 12)` pasaba limpio.
- **`SozuBrand\.`** - es la PALETA CRUDA (`lib/ui/tokens/palette.dart`), la capa
  de debajo de los roles. Usarla en una pantalla es lo mismo que escribir
  `Color(0xFF239F71)` pero con nombre bonito, **y no responde al tema**: los
  roles cambian entre `light` y `dark`, la constante no. 48 sitios fuera de
  `tokens/`, todos clavados a la paleta clara.

Fuera de `lib/ui/tokens/`, `SozuBrand` solo se justifica en dos sitios y ambos
están en `auth`: el panel de marca del acceso (`auth_brand_image.dart`, es una
superficie de marca, verde en los dos temas a propósito) y `_kPrimarySoft` en
`auth_layout.dart`, que vive dentro de un `const BoxDecoration` y por la trampa
del `const` no puede leer `context.s`. Cualquier otro uso es deuda.

## Nombres: el alcance manda
Un nombre dice QUE es y DONDE vive. Si el archivo esta fuera de una feature, su
nombre no puede llevar el prefijo de una.

| Capa | Puede llevar prefijo de feature | Convencion |
|---|---|---|
| `ui/` | NO | primitivas `s_*.dart` / `S*`; tokens `Sozu*` |
| `core/` | NO | por su funcion: `format`, `version`, `push_service` |
| `shared/` | NO | por su rol: `LightThemeLock`, `ThemeModeButton` |
| `features/<f>/` | SI | `ClientShell`, `AdminLayout`, `AuthPort` |
| `tool/`, raiz | NO | por lo que hacen: `check.sh`, `dev.sh`, `apk.sh` |

- **El nombre del archivo y su clase principal se corresponden.** Si el archivo
  se llama `portal_shell.dart` y dentro vive `ClientShell`, uno de los dos
  miente. Al renombrar una clase se renombra el archivo en el mismo commit.
- **PROHIBIDO el vendor** (ver seccion de puertos): ni `supabase` ni ningun
  proveedor en archivos, clases ni identificadores.
- **Un nombre global no se ata a quien lo usa hoy.** `LightThemeLock` se llamo
  `AuthAreaLightLock` y vivia en `main.dart`: el prefijo hacia pensar que era de
  `auth` y no lo es, y el nombre no decia que cambia el TEMA, que es lo unico
  que hace.

WARN: **"Portal" significa DOS cosas y solo una es correcta.**
- El PRODUCTO ("Portal del Cliente"): `PortalAccess`, `PortalTracking`, el
  titulo del `MaterialApp`. Correcto, se queda.
- El MODO legacy de web ancha: `isPortalMode`, `_PortalAwareFrame`,
  `PortalColors`. Es deuda y cae con la migracion; **nada nuevo se llama asi**.

En `features/client/` el prefijo correcto es `Client*` (`ClientShell`,
`ClientBottomNav`, `ClientTopBar`), no `Portal*`.

## Imports: SIEMPRE `package:`
```dart
import 'package:sozu_cliente_app/ui/ui.dart';   // OK: el equivalente de @/ui en TS
import '../../../../ui/ui.dart';                 // MAL
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
| `dart fix --apply` | los Quick Fix en lote |

El IDE usa el Dart Analysis Server, que lee el **mismo** `analysis_options.yaml`;
por eso `flutter analyze` y el panel de Problems dan idéntico resultado.

`check.sh` y el CI corren `flutter analyze --no-fatal-infos`: **errores y warnings
son fatales, los infos no**. Hoy hay 684 infos y **todos** son la deuda conocida
de `PortalColors` deprecado; con infos fatales el check salía siempre rojo y se
aprendía a ignorarlo. `check.sh` imprime el conteo para que una subida se note.
Al cerrar `PortalColors` hay que quitar el flag en los tres sitios (`check.sh`,
`.github/workflows/deploy-web-firebase.yml`, `codemagic.yaml`).

WARN: **El grep para contar lo fatal es `(error|warning) •`, NO `^\s+(error|warning)`.**
El analyzer imprime los **infos con sangría y los warnings sin ella**, así que el
patrón con `^\s+` los cuenta como cero y deja pasar un build roto. Costó un
deploy a producción: el CI (`flutter analyze --no-fatal-infos`) falló por dos
warnings que en local salían como "0 errores/warnings".

```bash
flutter analyze 2>&1 | grep -E "(error|warning) •"   # lo que de verdad rompe
```

`--no-fatal-infos` **sí** devuelve 0 cuando solo hay infos (comprobado el
2026-08-15 reproduciendo el comando del CI). La nota anterior decía lo contrario
y llevaba a ignorar el exit code, que es justo la señal buena.

WARN: **El repo NO está formateado con el formatter actual** (Dart 3.7 cambió a
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
  26 primitivas: SButton · STextField · SCard · SBadge · SAvatar · SProgressBar ·
  SSkeleton · SEmptyState · SErrorState · SSectionLabel · SPressable · SStagger ·
  SSearchField · SAutocompleteField · SLogo · SWebSelectable · SDropZone ·
  SPdfPreview · SPdfFrame · SDocUpload · SConfirm · SSelectField · SFieldLabel ·
  SFormSheet · SChoiceChip · STabs.
  `STabs` sustituye al `TabBar` de Material y, sobre todo, **no trae
  `TabBarView`**: pinta solo la fila de etiquetas y el cuerpo lo pone quien la
  usa. Un `TabBarView` no tiene alto intrínseco, así que obliga a meter un
  scroll dentro de cada pestaña, y ahí se pierde el scroll de página completa.
  `SFormSheet` es el chasis de toda modal de captura (encabezado, cuerpo y pie
  con Cancelar/Guardar); `SDocUploadLayout` es ese chasis con las dos columnas
  de carga dentro.
  `widgets/common.dart` fue ELIMINADO: sus 8 widgets viven aquí.
  `SDocUpload` es la modal global de carga: tipo, archivo, previsualización y
  los datos extraídos editables. La extracción y la subida las hace quien la
  abre; el componente no sabe de backend.
- features/: TODO el código de producto, por feature. `auth/` (cerrada),
  `admin/` (cerrada), `client/` (expediente, facturacion, home, layouts,
  products, profile, properties, referral, providers), `app_download/` (la
  landing de descarga del APK, un solo componente).
- core/: backend_env, format, secure_session_storage, open_document, open_media,
  media_cache, file_download, file_drop, url_strategy, user_agent/, version,
  push_service, portal_tracking, portal_theme (legacy). La biometría salió a
  `features/auth/`. Los pares `*_stub.dart` / `*_web.dart` son los imports
  condicionales por plataforma.
- data/: models (DTOs de las 7 functions)
- shared/: ports + adapters + providers **y components** que consumen 2+
  features, api_error. `shared/components/` es para un widget que necesita un
  provider (por eso no cabe en `ui/`, que no importa riverpod) y que usan dos
  features o más: hoy `theme_mode_button.dart`.
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

## Tema: claro/oscuro SÍ; el candado es el ÁREA DE ACCESO, no el ancho
La preferencia se persiste en `shared/providers/theme_provider.dart`
(`shared_preferences`; no es dato sensible) y se cambia desde dos sitios:

- **`shared/components/theme_mode_button.dart`** (`ThemeModeButton`) - menú
  compacto Claro · Oscuro · Sistema. Va en los encabezados; hoy en las dos
  pantallas de admin. Con "Sistema" activo dice además qué resolvió, porque si
  no la etiqueta no informa de lo que estás viendo.
- `features/client/profile/components/theme_selector.dart` - la tarjeta de tres
  opciones de Perfil.

`main.dart` pasa el `themeMode` del provider Y envuelve el árbol en
**`AuthAreaLightLock`**, que fuerza claro mientras el usuario **todavía no
entró** (sin sesión, con candado biométrico, resolviendo, con la cuenta
bloqueada o con el cambio de contraseña pendiente). Es el mismo criterio que el
guard del router.

WARN: **El criterio NO es el ancho.** Antes lo era (`PortalLightLock` +
`isPortalMode`) y tenía dos defectos: cruzar el breakpoint saltaba de claro a
oscuro de golpe, y como la condición leía `MediaQuery` en la raíz, cada pixel de
resize reconstruía el árbol completo con un `ThemeData` nuevo. **Consecuencia
práctica: dentro de la app el tema del usuario manda también en escritorio.**

Dónde funciona de verdad hoy: donde no quede `PortalColors`, que es un shim de
constantes claras. `auth` y `admin` están en 0, así que ahí el oscuro es real.
`client` todavía no. Por eso el `ThemeModeButton` se quitó en su momento
(`e90c9cd`, "quedaban inertes") y por eso ya se pudo devolver a admin.

Al terminar `PortalColors -> context.s.color` el oscuro queda bien en toda la
app. Tests: `test/theme_mode_test.dart`.

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
- **Android en físico por CABLE (camino probado, Oppo CPH2577 / Android 15):**
  1. En Windows, PowerShell admin (una vez: `winget install usbipd`). Son TRES
     pasos: sin `bind`, el `attach` falla con `the device is not shared`.
     ```powershell
     usbipd list                            # busca el telefono, copia el BUSID
     usbipd bind   --busid <BUSID>          # persistente, una vez por BUSID
     usbipd attach --wsl --busid <BUSID>    # cada vez que conectas el cable
     ```
  2. En WSL: `./tool/dev.sh DYLRPNJNIRKNZPRG` (el serial NO cambia nunca; el
     BUSID sí cambia de puerto USB, y al cambiar hay que hacer `bind` otra vez).
     Para saber si llegó: `ls /dev/bus/usb`. Si no existe, el `attach` no surtió
     efecto y `adb devices` sale vacío aunque el cable esté puesto.
  - `usbipd` pasa el USB al kernel de WSL, así que **`adb` corre local** y los
    `adb forward` quedan en WSL. Eso es lo que da hot reload.
  - WARN: **El otro camino (`.\adb.exe -a -P 5037 nodaemon server` en Windows y
    puente desde WSL) instala y lanza la app pero `r`/`R` NO hacen nada**: el
    `adb forward` al Dart VM service se crea en el host, no en WSL. `dev.sh` lo
    intenta solo como respaldo. Si vas a iterar diseño, tiene que ser `usbipd`.
  - Detalle, diagnóstico y la alternativa inalámbrica: `tool/android-usb.md` y
    `tool/README.md`.
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

  **El filtro, para decidir en el momento:** si el comentario explica lo que el
  código YA dice, sobra. Si explica por qué se eligió esto en vez de aquello, va
  al commit. Solo se queda si alguien que edite esa línea rompería algo sin
  saberlo. Un comentario que narra la historia del archivo ("antes eran 480
  líneas con...") es deuda: envejece, nadie lo actualiza y estorba al leer.

  Al cerrar una feature se audita igual que el legacy visual:

  ```bash
  F=lib/features/auth
  # Densidad. Un componente por encima de ~15% casi siempre esta narrando.
  # OJO: en un `port` el contrato ES la documentacion y 40% es correcto.
  for f in $(find $F -name '*.dart'); do
    t=$(wc -l < $f); c=$(grep -cE '^\s*(///|//)' $f)
    printf "%-46s %4s lin  %3s%%\n" "$(basename $f)" "$t" "$((c*100/t))"
  done
  # Bloques largos: >10 en un miembro, >15 en una clase de `ui/`.
  for f in $(find $F -name '*.dart'); do
    awk -v F="$f" '/^\s*(\/\/\/|\/\/)/{n++; if(n==1)s=NR; next}
                   {if(n>10) print F":"s"  ("n" lineas)"; n=0}' $f
  done
  ```
- **CERO emoji en el repo**, salvo los del diccionario. Ni en comentarios, ni en
  dartdoc, ni en READMEs, ni en la salida de `tool/*.sh`, ni en los workflows.
  En su lugar, etiqueta en MAYUSCULAS al principio: `WARN:`, `ERROR:`, `INFO:`,
  `OK:`, `FAIL:`. Se buscan con grep, no dependen de la fuente del terminal y no
  se rompen al copiar y pegar; un icono no cumple ninguna de las tres.
  - La ÚNICA excepción es el emoji que la app **pinta** como contenido, y vive
    centralizado en **`lib/ui/tokens/emoji.dart`** (`SozuEmoji`). Se usa desde
    ahí, nunca en literal: así cambiarlo en un sitio lo cambia en todos. Hoy
    lo consumen `animacion_llegada`, `como_llegar_screen` y
    `pago_final_screen`, los tres vía `SozuEmoji.*`. En el propio diccionario
    van como escapes (`'\u{1F680}'`), así que el repo entero queda en ASCII.
  - En tablas de estado usar la palabra (`OK`, `MAL`, `VERDE`, `AMBAR`, `ROJO`),
    sin dos puntos: ahí es una celda, no el prefijo de una frase.
  - Verificar antes de commitear:
  ```bash
  grep -rlP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}\x{2B00}-\x{2BFF}]' . \
       --exclude-dir=.git --exclude-dir=build --exclude-dir=.dart_tool
  ```
  Debe salir VACIO, sin excepciones.
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
