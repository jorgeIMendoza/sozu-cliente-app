# Feature `auth` — CERRADA

Estado: **migrada y auditada** · 2026-07-28 · 10 archivos, ~1,800 LOC

Primera feature en el patrón nuevo. Sirve de plantilla: cualquier duda de "¿dónde
va esto?" se resuelve mirando aquí.

## Estructura

```
layouts/
  auth_layout.dart          AuthLayout + AuthFormBody + kAuthAlignment/kAuthTextAlign
screens/
  login_screen.dart         AuthLayout(brand:, child:) — 40 líneas
  forgot_password_screen.dart
  change_password_screen.dart
components/
  auth_brand_image.dart     la imagen del panel izquierdo
  auth_header.dart          AuthLogo · AuthTitle · AuthSubtitle
  auth_text_field.dart      AuthTextField · AuthFieldLabel
  auth_buttons.dart         AuthPrimaryButton · AuthOutlineButton · AuthLink
  auth_alert.dart           AuthAlert · AuthAlertKind
  login_form.dart           el formulario completo del login
```

### Por qué tres carpetas

| Carpeta | Criterio | Contraejemplo |
|---|---|---|
| `layouts/` | envuelve pantallas; decide **tema, scroll, breakpoints** | un botón no elige el tema |
| `screens/` | solo ensamblan; sin estado ni providers | si tiene un `State` con lógica, esa lógica va a un componente |
| `components/` | **reutilizable** (2+ pantallas) | `login_form` es la excepción: único del login, pero partirlo en sub-piezas de un uso solo agrega archivos |

`AuthFormBody` vive en `layouts/` y no en `components/` porque solo apila hijos
con el aire correcto: eso es estructura, no una pieza de interfaz.

## Auditoría de cierre — todo en 0

```
PortalColors · isPortalMode · SozuTone · SozuColors · AuthColors
SozuType.*   · Color(0x…)   · fontSize: · circular(N)
EdgeInsets.all(N) · EdgeInsets.symmetric(N) · SizedBox(height: N)
import '../…' · kPortalFontFallback
```

Se reproduce con:
```bash
F=lib/features/auth
for p in "PortalColors" "isPortalMode" "SozuTone" "SozuColors" "AuthColors" \
         "SozuType\." "Color(0x" "fontSize:" "circular([0-9]" \
         "EdgeInsets.all([0-9]" "EdgeInsets.symmetric(horizontal: [0-9]" \
         "SizedBox(height: [0-9]" "import '\.\./" "kPortalFontFallback"; do
  printf "%-42s %s\n" "$p" \
    "$(grep -rn "$p" $F --include=*.dart | grep -vE ':[0-9]+: *///' | wc -l)"
done
```

**Excepción documentada:** `auth_buttons.dart` usa `height: 52` y `height: 50`
(alturas de control). No son espaciado sino destinos táctiles; no existe token de
altura de control todavía. Si se crea uno, migrar aquí.

## Qué se eliminó al cerrar

| Antes | Ahora |
|---|---|
| `auth_widgets.dart` — 766 líneas, un cajón con 13 clases | 6 componentes + 1 layout |
| `login_screen.dart` — 546 líneas con layout + estado + biometría + atajos | `login_screen` (40) + `login_form` |
| `AuthColors` — 20 constantes, 16 hex crudos | roles de `context.s.color` |
| `AuthCard` — tarjeta blanca solo en móvil | `AuthFormBody`, el formulario va directo sobre la página |
| `kAuthSplitBreakpoint` (1024) · `kAuthCompactBreakpoint` (480) | `context.bp` del DS. El primero era **exactamente** `kSozuDesktopMin` |
| `_LogoBlanco` + `ColorFiltered` a mano | `SozuLogo.onBrand` |

## Bugs encontrados y corregidos al migrar

1. **`AuthAlertKind.success` pintaba mal** — usaba el fondo ámbar de `warning`
   con texto verde.
2. **El logo era invisible en tema oscuro** — 4 de 5 usos pintaban el PNG negro
   crudo. `SozuLogo` lo recolorea con `srcIn`.
3. **Todo error de acceso decía "Correo o contraseña incorrectos"** — incluidos
   el 429 por demasiados intentos y la red caída. Ahora `AuthController.mensajeErrorAcceso`
   los distingue. El mapeo vive en el provider, no en la UI: interpretar un
   `AuthException` exige importar `supabase_flutter`.
4. **`¿Olvidaste tu contraseña?` tenía fondo de botón en hover** — ahora es
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
