# Estado de la migración

Última actualización: 2026-07-30. Rama `refactor/design-system-auth`, **sin push**.

Documento de traspaso: qué está hecho, qué sigue y qué decisiones esperan a
Eduardo. El "por qué" de cada cosa está en los mensajes de commit y en
`0001-arquitectura-modular.md`.

---

## Hecho

| | |
|---|---|
| Design system | `lib/ui/` con 5 ejes de token (color, tipografía, espaciado, radio, movimiento) y 11 primitivas |
| Temas | exactamente 2: `SozuColorRoles.light` / `.dark` |
| Feature cerrada | `auth` - 0 legacy, auditada. Es la plantilla |
| Tests | 0 → 199 |
| Alias eliminados | `SozuColors`, `SozuTone`, `AuthColors` - borrados, no deprecados |
| Duraciones cocidas de animación | 34 → 0 fuera de `lib/ui/` |
| Curvas `Curves.linear` implícitas | 20 → 0 |
| Reduced motion | respetado en todo el sistema (`MediaQuery.disableAnimations`) |
| Imports | 414 convertidos a `package:`, lint que lo obliga |
| Android en físico | funciona (Temurin 21 + SDK 36 + puente de adb) |

---

## Lo que sigue, en orden

### 1. `flutter test` en CI  (~15 min, alto valor)

Los 8 puntos de `codemagic.yaml` y `.github/workflows/deploy-web-firebase.yml`
corren **solo `flutter analyze`**. En esta sesión hubo tres casos donde `analyze`
pasó limpio y el build o los tests fallaron:

- un spread genérico que el analyzer aceptó y el compilador rechazó
- `context.s` dentro de una expresión `const`
- un asset usado sin declarar en `pubspec.yaml`

Es la red que falta antes de tocar 26 archivos en el paso 3.

### 2. Cerrar los tres cabos de `auth`  (chico)

Verificados, reales, menores:

- `SLogo.aspectRatio` es API pública que nadie consume.
- `s_search_field` y `s_autocomplete_field` usan el `InputDecoration` por defecto
  de Material, **con label flotante** - justo lo que `STextField` documenta como
  prohibido. Los tres campos de texto de la app no se ven iguales. **Este es el
  que importa**: es una fractura del design system.
- `lerpDouble` vive en `radii.dart` pero lo importan `motion.dart` y
  `spacing.dart` para matemática que no tiene que ver con radios.

Además: `SozuTypeScale.compact` es `static final` mientras `standard` es `const`,
así que no sirve en contexto `const`.

### 3. Fusionar los 6 pares móvil/web  (el trabajo grande)

Es la fractura que queda: **una misma pantalla tiene dos árboles de widgets**, y
el interruptor es `isPortalMode(context)` con **40 usos en 26 archivos**.

**Actualización 2026-07-31:** las mitades MÓVIL ya se fusionaron en `lib/ui/`
(`widgets/common.dart` eliminado, 264 sitios migrados). Lo que queda son las
mitades `Portal*`, cuyas primitivas ya existen y las contemplan por variantes.

| Móvil | Portal web | Usos | Riesgo |
|---|---|---|---|
| `SectionTitle` | `PortalSectionLabel` | 62 | bajo (solo texto) |
| `EmptyCard` | `PortalEmptyState` | 27 | bajo (ya existe `SEmptyState`) |
| `SozuProgressBar` | `PortalProgressBar` | 14 | bajo |
| `StatusBadge` | `PortalStatusChip` | 56 | medio (mapeo estado→color) |
| `AppCard` | `PortalCard` | 144 | medio-alto |
| `property_card` | `portal_property_card` | 5 | alto (1,129 líneas) |

Objetivo: un componente con variantes, y el responsive como **valor** en vez de
rama del árbol.

```dart
// hoy
if (isPortalMode(context)) PortalCard(...) else AppCard(...)

// objetivo
SCard(...)
final cols = context.responsive(mobile: 1, desktop: 3);
```

`isPortalMode` debe sobrevivir solo dentro de un `AdaptiveShell`, redefinido por
**ancho disponible** y no por `kIsWeb`. Eso arregla de paso su defecto actual: una
tablet Android en horizontal nunca recibe el layout ancho aunque le quede mejor.

Cada par fusionado borra ramas `isPortalMode`, así que el problema de
`PortalColors` (abajo) se encoge solo.

### 4. `PortalColors`  (último legacy vivo)

**748 referencias, ~137 dentro de expresiones `const`.** Migrar a
`context.s.color` rompe la const-ness: hay que quitar el `const` caso por caso y
solo el compilador los localiza con fiabilidad. **No se puede hacer con sed.**

Ya NO es una paleta paralela: cada constante apunta a la rampa unificada y hay
tests que lo garantizan. Lo que queda es un segundo nombre para lo mismo.

### 5. Plugins que aplican KGP  (deuda con fecha abierta)

`flutter run` en Android avisa: `device_info_plus`, `package_info_plus`, `pdfx` y
`share_plus` aplican el Kotlin Gradle Plugin por su cuenta. Hoy es solo un
WARNING y compila; versiones futuras de Flutter fallaran.

| Plugin | Actual | Ultima | Usado en |
|---|---|---|---|
| `pdfx` | 2.9.2 | **2.9.2 - ya al dia** | `screens/doc_viewer_screen.dart` |
| `share_plus` | 10.1.4 | 13.3.0 | `widgets/recibo_pago_sheet.dart:234` |
| `device_info_plus` | 12.4.0 | 13.2.0 | `core/portal_tracking.dart:81` |
| `package_info_plus` | 9.0.1 | 10.2.1 | transitivo, via `geolocator_linux` |

**`pdfx` no tiene arreglo upstream**: esta en su ultima version, asi que subir los
otros tres NO quita el warning. El camino real es reportarlo al plugin o cambiar
de lector de PDF.

Cuando toque: subir los tres `_plus` es un commit aparte con prueba en fisico.
`share_plus` 10 -> 13 son tres majors y cambia la API del unico sitio de uso
(`Share.share(texto, subject:)`). Los constraints en `pubspec.yaml` fijan el
major, asi que hay que ensancharlos a mano; `pub upgrade` solo no los mueve.

No esta verificado si esas versiones nuevas ya migraron a Built-in Kotlin - hay
que leer sus changelogs antes de invertir el rato.

### 6. Siguiente feature: `admin`

Después de `auth`. Tiene la mitad de los componentes hechos
(`features/admin/components/{admin_header_bar,client_filters,client_row}.dart`) y
`seleccionar_cliente_screen` ya está compuesto, no monolítico.
`admin_avisos_screen.dart` son 1,126 líneas con 31 `setState`.

---

## Decisiones que esperan a Eduardo

1. **Catálogo de proyectos del selector.** Trae entradas que no son proyectos
   inmobiliarios ("Productos", "Mutuo Vive") porque reusa el catálogo de avisos.
   Solicitud de cambio con dos opciones en `Ejecuciones_manuales/`. Falta decidir
   opción A o B, y el criterio de "proyecto inmobiliario" en BD.
2. **`dart format .` completo**, como commit aislado. El repo no está formateado
   con el formatter de Dart 3.7 (tall style), así que formatear cualquier archivo
   legacy genera ruido enorme en el diff. Hoy `check.sh` formatea solo lo
   modificado para evitarlo.
3. **`avoid_dynamic_calls`**: `models.dart` tiene 95 `dynamic`. Si el lint
   estorba, quitarlo hasta que toque migrar `data/`.
4. **Push y PR** de `refactor/design-system-auth`.

---

## Trampas documentadas en el código

Compilan, no dan warning, y el síntoma aparece lejos de la causa:

1. **`context.s` no cabe en una expresión `const`.** Leer un campo de un objeto
   const no es constante en Dart.
2. **El campo tipográfico de `SozuTheme` se llama `text`, no `type`.**
   `ThemeExtension.type` es la clave del mapa de extensiones de Material; pisarla
   deja `extension<SozuTheme>()` devolviendo `null` para siempre, sin error.
3. **`SPressable.detector` no va en código nuevo**: sin capa de gesto no hay foco
   de teclado.
4. **`SizedBox` no puede medir menos que un padre tight.** Por eso
   `SSkeleton.text(width:)` necesita un `Align`.
5. **`analyze` limpio no prueba que compile.** Pasó tres veces en esta sesión.
6. **Cambios en `pubspec.yaml` exigen matar y relanzar `dev.sh`.** Ni `r` ni `R`
   los toman.
