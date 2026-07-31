# Feature `auth` - CERRADA

Estado: **migrada al design system global** · 2026-07-30 · 10 archivos

Primera feature en el patrón nuevo. Sirve de plantilla: cualquier duda de "¿dónde
va esto?" se resuelve mirando aquí.

## Estructura

```
layouts/
  auth_layout.dart          AuthLayout + AuthFormBody + kAuthAlignment/kAuthTextAlign
screens/
  login_screen.dart         AuthLayout(brand:, child:) - 40 líneas
  forgot_password_screen.dart
  change_password_screen.dart
components/
  auth_brand_image.dart     la imagen del panel izquierdo
  auth_header.dart          AuthLogo · AuthTitle · AuthSubtitle
  auth_alert.dart           AuthAlert · AuthAlertKind
  biometric_setup_sheet.dart  offerBiometricSetup() - login y cambio de password
  biometric_toggle_card.dart       BiometricToggleCard - el switch de la card de Perfil
  login_form.dart           el formulario completo del login
services/
  biometric_service.dart    BiometricService · BiometricLoginResult
```

### Toda la biometría vive aquí

Huella / Face ID es **autenticación**, así que es de esta feature: el servicio, la
oferta post-login y el switch de Perfil son tres piezas del mismo mecanismo y
están juntas. Antes el servicio vivía en `lib/core/` y la card de Perfil en
`lib/widgets/`; esos dos archivos ya no existen y **no** quedó ningún re-export.

| Pieza | Dónde | Quién la usa |
|---|---|---|
| `BiometricService` (singleton) · `BiometricLoginResult` | `services/` | `login_form` · `biometric_setup_sheet` · `biometric_toggle_card` · `providers/auth_provider.dart` |
| `offerBiometricSetup()` - el bottom sheet que la ofrece | `components/` | `login_form` · `change_password_screen` |
| `BiometricToggleCard` - la card de Perfil | `components/` | `screens/perfil_screen.dart` (legacy, fuera de la feature) |

`BiometricToggleCard` es **API pública de la feature**: lo consume una pantalla
que no es de auth. Eso es correcto - lo incorrecto sería duplicarlo o dejar un
alias en `widgets/`. Está anotado en su propio docstring.

### Campos y botones: del design system, no de auth

Auth **no tiene** widgets de campo ni de botón. Usa los globales de
`lib/ui/primitives/` (`import 'package:sozu_cliente_app/ui/ui.dart';`):

| Necesidad | Componente global |
|---|---|
| Campo con etiqueta arriba | `STextField(label:, hint:, …)` |
| Campo de contraseña | `STextField.password(...)` - el ojo lo maneja el campo |
| Acción principal del formulario | `SButton(size: SButtonSize.lg, …)` |
| Acción alterna (biometría) | `SButton.secondary(size: SButtonSize.lg, …)` |
| Enlace de texto | `SButton.link(...)` |

Lo específico de auth va por **props**, nunca por una copia del widget. Si algo
no se puede expresar con una prop, la prop se agrega al componente GLOBAL - no se
crea un componente de auth.

`SButtonSize.lg` (52 px) es explícito en los botones de formulario: empareja el
alto de `STextField` (que nace en `lg`). El default de `SButton` es `md` (44 px),
correcto para toolbars y filas de acciones, bajo al lado de un campo.

El error GLOBAL del formulario (`_formError`) se sigue mostrando con `AuthAlert`.
`STextField.errorText` es para el error POR CAMPO.

### Modo administrador: dos formas de activarlo

Viven las dos en `login_form.dart` y las dos llaman a `_toggleAdminMode()`:

| Cómo | Dónde funciona | Por qué |
|---|---|---|
| **Long-press de 1.5 s en el sello de versión** del pie | todas las plataformas | es el único camino desde un teléfono |
| **Ctrl+Shift+A** / **Ctrl+Alt+A** | solo web (`HardwareKeyboard`) | en escritorio es más rápido; ver `_onKeyEvent` |

El atajo de teclado era lo único que había, y su handler ni se instala en
Android/iOS: **desde el celular no existía manera de entrar como administrador.**

- El gesto **no es una frontera de seguridad** y no pretende ser secreto. El
  interruptor solo pinta la pastilla `_AdminModeBadge` y cambia el destino
  post-login; la autorización la da el backend (`administrar_app_clientes` del
  perfil). Encenderlo en una cuenta sin ese permiso no hace nada: el login cae al
  camino normal de cliente. El umbral de 1.5 s está para que **no se dispare por
  accidente**, no para esconderlo.
- El sello sigue siendo texto: sin cursor de mano, sin hover y sin ripple. De ahí
  que use `RawGestureDetector` con `LongPressGestureRecognizer(duration:)` -
  `GestureDetector.onLongPress` trae fijo `kLongPressTimeout` (500 ms) y no se
  puede subir- y **no** `SPressable`, que pinta las tres cosas. Un sello que se
  ve pulsable se toca por accidente.
- En móvil el toggle además vibra (`HapticFeedback.mediumImpact`): la pastilla es
  la señal, pero con el pulgar encima y sin estado intermedio, un long-press que
  sí funcionó se siente igual que un toque perdido.
- Tests: `test/features/auth/login_form_test.dart`. Ojo, `tester.longPress`
  presiona 500 ms, o sea un tercio del umbral: hay que sostener con
  `startGesture` + `pump(1600 ms)` + `up`.

### Por qué cuatro carpetas

| Carpeta | Criterio | Contraejemplo |
|---|---|---|
| `layouts/` | envuelve pantallas; decide **tema, scroll, breakpoints** | un botón no elige el tema |
| `screens/` | solo ensamblan; sin estado ni providers | si tiene un `State` con lógica, esa lógica va a un componente |
| `components/` | **reutilizable** (2+ pantallas) | `login_form` es la excepción: único del login, pero partirlo en sub-piezas de un uso solo agrega archivos |
| `services/` | lógica **sin UI**: plugins de plataforma, secure storage, sesión de Supabase. No importa `flutter/material.dart` ni construye widgets | un bottom sheet no es un servicio aunque haga I/O: `biometric_setup_sheet` es `components/` |

`AuthFormBody` vive en `layouts/` y no en `components/` porque solo apila hijos
con el aire correcto: eso es estructura, no una pieza de interfaz.

`services/` es la cuarta carpeta y no estaba en el patrón original de tres, que
solo cubre UI. `BiometricService` no cabía en ninguna: no es una pantalla, no
envuelve nada y **no es un widget** - habla con `local_auth`, con
`FlutterSecureStorage` y con `Supabase.auth`. Tampoco es `data/`: en este repo
`lib/data/` significa DTOs de las Edge Functions + `api_client`, y aquí no hay ni
DTO ni endpoint. Un servicio de feature es un singleton de proceso con estado
persistido; por eso carpeta propia. Nombre `*_service.dart`, igual que los
globales de `core/` (`push_service`, `media_cache`).

## Auditoría de cierre - todo en 0

```
PortalColors · isPortalMode · SozuTone · SozuColors · AuthColors
SozuType.*   · Color(0x…)   · fontSize: · circular(N)
EdgeInsets.all(N) · EdgeInsets.symmetric(N) · SizedBox(height: N)
import '../…' · kPortalFontFallback
AuthPrimaryButton · AuthOutlineButton · AuthLink · AuthTextField · AuthFieldLabel
```

Se reproduce con:
```bash
F=lib/features/auth
for p in "PortalColors" "isPortalMode" "SozuTone" "SozuColors" "AuthColors" \
         "SozuType\." "Color(0x" "fontSize:" "circular([0-9]" \
         "EdgeInsets.all([0-9]" "EdgeInsets.symmetric(horizontal: [0-9]" \
         "SizedBox(height: [0-9]" "import '\.\./" "kPortalFontFallback" \
         "AuthPrimaryButton" "AuthOutlineButton" "AuthLink" "AuthTextField" \
         "AuthFieldLabel"; do
  printf "%-42s %s\n" "$p" \
    "$(grep -rn "$p" $F --include=*.dart | grep -vE ':[0-9]+: *///' | wc -l)"
done
```

Ya **no hay excepciones documentadas**: los `height: 52` / `height: 50` de
`auth_buttons.dart` desaparecieron con el archivo. Las alturas de control ahora
las decide `SButtonSize` / `STextFieldSize` en `lib/ui/primitives/`.

## Qué se eliminó al cerrar

| Antes | Ahora |
|---|---|
| `auth_widgets.dart` - 766 líneas, un cajón con 13 clases | 6 componentes + 1 layout |
| `login_screen.dart` - 546 líneas con layout + estado + biometría + atajos | `login_screen` (40) + `login_form` |
| `AuthColors` - 20 constantes, 16 hex crudos | roles de `context.s.color` |
| `AuthCard` - tarjeta blanca solo en móvil | `AuthFormBody`, el formulario va directo sobre la página |
| `kAuthSplitBreakpoint` (1024) · `kAuthCompactBreakpoint` (480) | `context.bp` del DS. El primero era **exactamente** `kSozuDesktopMin` |
| `_LogoBlanco` + `ColorFiltered` a mano | `SLogo.onBrand` |
| `auth_buttons.dart` (292) - `AuthPrimaryButton` · `AuthOutlineButton` · `AuthLink` · `_HoverUnderline` | `SButton` · `SButton.secondary` · `SButton.link` del DS global |
| `auth_text_field.dart` (137) - `AuthTextField` · `AuthFieldLabel` | `STextField` (la etiqueta es la prop `label:`) |
| `bool _isPasswordHidden` / `_showPwd` / `_showConfirm` + 3 `IconButton` del ojo | `STextField.password`: la visibilidad es estado del campo |
| `CircularProgressIndicator` pasado como `icon:` al botón de biometría | `loading: true` - el spinner lo pone el botón |

## Bugs encontrados y corregidos al migrar

1. **`AuthAlertKind.success` pintaba mal** - usaba el fondo ámbar de `warning`
   con texto verde.
2. **El logo era invisible en tema oscuro** - 4 de 5 usos pintaban el PNG negro
   crudo. `SLogo` lo recolorea con `srcIn`.
3. **Todo error de acceso decía "Correo o contraseña incorrectos"** - incluidos
   el 429 por demasiados intentos y la red caída. Ahora `AuthController.mensajeErrorAcceso`
   los distingue. El mapeo vive en el provider, no en la UI: interpretar un
   `AuthException` exige importar `supabase_flutter`.
4. **`¿Olvidaste tu contraseña?` tenía fondo de botón en hover** - ahora es
   subrayado, conservando los 44 px de destino táctil.

## Trampas a recordar

- **`context.s` NO puede ir dentro de una expresión `const`.** Leer un campo de
  un objeto const no es constante en Dart. El degradado del `AuthLayout` usa
  constantes de la paleta (`SozuNeutral.n0`, `SozuBrand.soft06`) justo por eso, con
  las equivalencias anotadas en el archivo.
- **`AuthLayout` fuerza tema claro** con `Theme(data: sozuLightTheme())`. Por eso
  todos los componentes de auth pueden usar `context.s.color` sin saber que están
  en una pantalla light-only.
- Cambios en `pubspec.yaml` (la imagen del panel) exigen **matar y relanzar**
  `dev.sh`; ni `r` ni `R` los toman.
