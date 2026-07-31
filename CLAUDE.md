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

## Ejecuciones manuales (SQL / deploys de Edge Functions)
- PROHIBIDO ejecutar SQL o `supabase functions deploy` directo desde aquí.
- Todo cambio de BD/deploy va primero a un `.md` en `Ejecuciones_manuales/`
  (gitignored; patrón de admin-sozu/sozu-admin: secciones fechadas + comandos
  exactos). Jorge lo ejecuta a mano y reporta.

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
- **NADA DE ALIAS NI MAPEOS.** Un token tiene UN nombre y ese nombre se usa en
  toda la app. `SozuColors`, `SozuTone`, `core/theme.dart`, `core/brand.dart` y
  `core/typography.dart` fueron ELIMINADOS (no deprecados: borrados). Si se
  renombra un token, se renombra en todos los usos en el mismo commit - una capa
  de compatibilidad "temporal" es cómo nació la paleta bifurcada.
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
```

Toda la biometría (huella / Face ID) vive en `auth`: es autenticación. El servicio,
la oferta post-login y el switch de Perfil son el mismo mecanismo.
`BiometricToggleCard` lo consume `screens/perfil_screen.dart` (legacy): es API
pública de la feature, no un motivo para duplicarlo ni dejar un alias.

**`features/admin/` está MIGRADA** (2ª feature, auditoría en 0). Detalle y deuda
pendiente en `lib/features/admin/README.md`.

```
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

⚠️ **El repo NO está formateado con el formatter actual** (Dart 3.7 cambió a
"tall style"). Por eso `check.sh` formatea solo los archivos modificados: un
`dart format .` reescribe medio archivo ajeno. Cuando se haga, que sea un commit
que **solo** sea formato.

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
  16 primitivas: SButton · STextField · SCard · SBadge · SAvatar · SProgressBar ·
  SSkeleton · SEmptyState · SErrorState · SSectionLabel · SPressable · SStagger ·
  SSearchField · SAutocompleteField · SLogo · SWebSelectable.
  `widgets/common.dart` fue ELIMINADO: sus 8 widgets viven aquí.
- features/: código nuevo, por feature. Hoy: `auth/` (cerrada), `admin/` (en curso).
- core/: format, secure_session_storage, open_document, version, push_service,
  portal_tracking, portal_theme (legacy). La biometría salió a `features/auth/`.
- data/: models (DTOs de las 7 functions), api_client (invoke + ApiError)
- providers/: auth (sesión+perfil+password flows), data (FutureProviders), theme
- router.dart: guards + shell 5 tabs + secundarias
- widgets/: theme_mode_button, inactivity_watcher,
  portal_*, level_map. La carpeta admin/ salio a features/admin/components/.
- screens/: LEGACY, pendiente de migrar a features/ - inicio, adquisicion,
  patrimonio, documentos, perfil, pagos, estado_cuenta, notificaciones,
  cambiar_password, propiedad_detalle, seleccionar_cliente, forgot,
  change_password_forced

## Sesión
- Cierre por inactividad: **5 min en teléfono, 15 min en escritorio**
  (`widgets/inactivity_watcher.dart`). El criterio es el FORMATO de pantalla, no
  `kIsWeb`: web en el navegador del celular usa el plazo corto.
- Selector de tema claro/oscuro/sistema: `widgets/theme_mode_button.dart`.

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
