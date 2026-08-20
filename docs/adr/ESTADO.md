# Estado de la migración

Última actualización: 2026-08-20. Rama `dev-eddy`, sincronizada con `dev`.

Documento de traspaso: qué está hecho, qué sigue y qué decisiones esperan a
Eduardo. El "por qué" de cada cosa está en los mensajes de commit y en
`0001-arquitectura-modular.md`.

Las cifras de este documento se sacan con los greps de la sección
"Al cerrar una feature, auditar que no quede legacy" de `CLAUDE.md`. Si al
leerlo no cuadran, gana el grep.

---

## Hecho

| | |
|---|---|
| Design system | `lib/ui/` con 5 ejes de token (color, tipografía, espaciado, radio, movimiento) y 26 primitivas exportadas, más `SozuEmoji` |
| Reglas escritas | dartdoc conciso, cero emoji y nombres por alcance, las tres con su grep en `CLAUDE.md` |
| Temas | exactamente 2: `SozuColorRoles.light` / `.dark` |
| Features cerradas | `auth` y `admin` - 0 legacy, auditadas. `auth` es la plantilla |
| Shell del cliente | UNO solo (`ClientShell`), decide por ancho y no por plataforma |
| Pantallas de `auth` | las 5 son composición pura: 0 `setState`, ninguna pasa de 100 líneas |
| Puertos y adaptadores | 8 features con `ports/` + `adapters/`; 0 fugas de vendor fuera de un adaptador salvo `core/portal_tracking.dart` |
| Tests | 0 → 507, en 65 archivos. Las 5 pantallas de `auth` y las 2 de `admin` tienen cobertura |
| Alias eliminados | `SozuColors`, `SozuTone`, `AuthColors`, `widgets/common.dart` - borrados, no deprecados |
| Pares móvil/web | 5 de 6 fusionados (ver abajo). `AppCard`, `SectionTitle`, `EmptyCard`, `SozuProgressBar`, `StatusBadge`: 0 usos |
| Imports | 100% `package:` en `lib/`, lint que lo obliga |
| Guiones largos | 0 en lib, test, docs, yaml |
| `flutter analyze` | 0 errores, 0 warnings. 674 infos, **todos** `PortalColors` deprecado |
| Buscador de clientes | busca en el SERVIDOR e ignora acentos (`admin_clientes_buscar`); en produccion desde el 2026-08-19 |
| Botones de Material | 0 en `auth`; en `admin` solo `AdminHeaderAction` (ver abajo). Patron agregado al grep de cierre |
| Android en físico | funciona (Temurin 21 + SDK 36 + puente de adb) |

`lib/screens/` y `lib/providers/` ya no existen. `lib/widgets/` es lo que queda
de legacy declarado (7 archivos), más `lib/core/portal_theme.dart`.

---

## La deuda, medida

Conteo por feature de los 6 patrones legacy (`PortalColors`, `isPortalMode`,
`Color(0x`, `fontSize:`, `circular(N)`, `EdgeInsets.all(N)`):

| Carpeta | Legacy | Nota |
|---|---|---|
| `features/auth` | **0** | cerrada y re-auditada el 2026-08-20 contra el codigo |
| `features/admin` | **0** | cerrada y re-auditada el 2026-08-20 contra el codigo |
| `features/client/providers` | **0** | |
| `features/client/facturacion` | 1 | |
| `features/client/referral` | 1 | |
| `features/client/expediente` | 2 | lo más nuevo; nació con el patrón |
| `features/client/layouts` | 62 | el shell ya unificado; le quedan 26 `PortalColors` | |
| `features/client/products` | 91 | |
| `features/client/profile` | 104 | |
| `features/client/home` | 118 | |
| `features/client/properties` | **741** | el 60% de toda la deuda |
| `lib/widgets` (legacy) | 83 | |
| `lib/core` | 3 | `portal_theme` + `portal_tracking` |

Totales absolutos (medidos el 2026-08-20): **`PortalColors` 601 referencias**,
**`isPortalMode` 36 usos**, **`SozuBrand` 63 fuera de `tokens/`**. Subieron
respecto al 2026-08-18 porque entro codigo por `dev`; el grep manda sobre esta
tabla.

### Botones de Material, la deuda que nadie contaba

`(Filled|Text|Elevated|Outlined)Button` se salta `SButton` sin escribir un solo
numero crudo, asi que ningun otro patron del grep lo veia. Medido el 2026-08-20:

| Carpeta | | |
|---|---|---|
| `auth` | **0** | corregido el 2026-08-20 |
| `admin` | 3 | los tres de `AdminHeaderAction`, a proposito (ver abajo) |
| `client` | 35 | sin tocar |

`AdminHeaderAction` reimplementa lo que `SButton.ghost` y `.danger` ya hacen,
pero mide 36 px y el design system dice que por debajo de 44 solo en barras
densas de escritorio; estas pantallas tambien se usan en telefono. Consolidarlo
exige decidir antes ese alto: pasarlo a `SButtonSize.sm` solo mudaria la
violacion adentro de la primitiva.

### La deuda que la auditoría vieja no contaba

El grep de cierre se amplió el 2026-08-17 (ver `CLAUDE.md`). Tres patrones que
antes pasaban limpios:

| Patrón | Total en `lib/` | Qué es |
|---|---|---|
| `SizedBox(height/width: N)` | **801** | espaciado crudo; existe `context.s.space.gapMd` desde siempre |
| `EdgeInsets.symmetric/only/fromLTRB(N)` | **339** | el grep viejo solo miraba `.all` |
| `SozuBrand.*` fuera de `tokens/` | **48** | paleta cruda: no responde al tema |

Reparto (espaciado + paleta, sumados):

| Carpeta | | | Carpeta | |
|---|---|---|---|---|
| `admin` | **0** | | `home` | 83 |
| `auth` | 3 | (los 3 son correctos, ver su README) | `products` | 110 |
| `referral` | 1 | | `profile` | 139 |
| `facturacion` | 5 | | `properties` | **736** |
| `expediente` | 12 | | `widgets` (legacy) | 42 |
| `layouts` | 35 | | `ui` | 2 |

Los 48 `SozuBrand` importan más de lo que su número sugiere: parte de lo que
hoy se le achaca a `PortalColors` al probar el modo oscuro es esto. Un
`SozuBrand.green600` es un `Color(0xFF1D825D)` con nombre bonito y no cambia
entre `light` y `dark`.

Los 5 archivos más grandes son todos de `properties` o vecinos suyos, y explican
por qué esa columna manda:

| Archivo | Líneas |
|---|---|
| `properties/screens/propiedad_detalle_screen.dart` | 3,168 |
| `properties/screens/estado_cuenta_screen.dart` | 2,622 |
| `properties/screens/pagos_screen.dart` | 2,373 |
| `data/models.dart` | 1,949 |
| `profile/components/perfil_sheets.dart` | 1,687 |

---

## Lo que sigue, en orden

### 0. EMPEZAR AQUI: el color del shell del cliente  (acotado, alto impacto)

`features/client/layouts/client_shell.dart` tiene **26 `PortalColors`** y un
`Theme(data: sozuLightTheme())` en `_ConSidebar`. Al migrarlos y quitar ese
`Theme`, **todo el marco** -barra lateral, superior e inferior- responde al
tema del usuario.

Es el punto de entrada correcto porque el shell ya esta unificado: era codigo
repartido en tres widgets y ahora es uno solo, asi que se migra una vez.

Despues caen los otros tres `Theme` de deuda (ver 4b). Las pantallas van
detras, por feature, de menor a mayor.

### 1. Cerrar `features/client/expediente`, `facturacion` y `referral`  (chico)

Con el grep completo suman **22 hits**: 4 de `isPortalMode` y 18 de espaciado
crudo. Ninguna tiene `PortalColors`. Es la victoria más barata que queda y deja
tres features auditadas más, con lo que el patrón de `auth` pasa de ser una
excepción a ser la norma.

### 2. El sexto par móvil/web: `property_card` / `portal_property_card`

Los otros cinco ya se fusionaron. Queda este, que es el que ESTADO marcaba como
"alto riesgo": `portal_property_card.dart` lo consumen `propiedades_screen` e
`inicio_screen`. `PortalCard` sobrevive solo dentro de `lib/widgets/portal_widgets.dart`
(6 usos, todos internos al archivo), así que se muere junto con ese archivo.

### 3. `PortalColors` → `context.s.color`  (el trabajo grande)

**605 referencias, ~137 dentro de expresiones `const`.** Migrar rompe la
const-ness: hay que quitar el `const` caso por caso y solo el compilador los
localiza con fiabilidad. **No se puede hacer con sed.**

Ya NO es una paleta paralela: cada constante apunta a la rampa unificada y hay
tests que lo garantizan. Lo que queda es un segundo nombre para lo mismo.

Al llegar a 0:
- caen los cuatro `Theme(sozuLightTheme())` de deuda (ver 4b) y el oscuro queda
  global; `LightThemeLock` se queda, que es el candado legitimo del acceso;
- se quita `--no-fatal-infos` de los tres sitios (`tool/check.sh`,
  `.github/workflows/deploy-web-firebase.yml`, `codemagic.yaml`);
- `core/portal_theme.dart` desaparece.

Orden recomendado: por feature, de menor a mayor, cerrando cada una con la
auditoría. `properties` al final.

### 4. Cabos sueltos de `lib/ui/`  (chicos, verificados)

- `SLogo.aspectRatio` (`s_logo.dart:62`) es API pública que nadie consume.
- `lerpDouble` vive en `radii.dart` pero lo importan `motion.dart` y
  `spacing.dart` para matemática que no tiene que ver con radios.
- `SozuTypeScale.compact` es `static final` mientras `standard` es `const`, así
  que no sirve en contexto `const` (`typography.dart:213`).

Cerrado desde la revisión anterior: `s_search_field` y `s_autocomplete_field` ya
componen sobre `STextField`, no sobre un `TextField` con `InputDecoration`. Los
tres campos de texto de la app se ven iguales.

### 4b. El modo oscuro NO se desbloquea solo migrando `PortalColors`

Hay **cuatro `Theme(data: sozuLightTheme())` explícitos** que lo pisan aunque
los tokens estén migrados:

| Archivo | Veredicto |
|---|---|
| `features/client/layouts/client_shell.dart` | deuda: cae al migrar los 34 `PortalColors` del shell |
| `client/properties/screens/pagar_screen.dart` | deuda |
| `client/properties/screens/pago_final_screen.dart` | deuda |
| `client/properties/components/credito_hipotecario_drawer.dart` | deuda |
| `features/auth/layouts/auth_layout.dart` | CORRECTO: el acceso va claro a propósito |

`LightThemeLock` (antes `AuthAreaLightLock`, en `shared/components/`) es el
único candado legítimo: fuerza claro mientras el usuario no ha entrado.

### 5. `core/portal_tracking.dart` usa el vendor fuera de un adaptador

`SupabaseClient` directo en `core/` (línea 28). Es la única grieta del hexagonal
en todo el repo. No es un agujero de seguridad (son los 3 RPC `SECURITY DEFINER`
que usan los demás portales), pero incumple la regla del ADR 0002: se resuelve
con un `TrackingPort` + adaptador.

### 6. Plugins que aplican KGP  (deuda con fecha abierta)

`flutter run` en Android avisa: `device_info_plus`, `package_info_plus`, `pdfx` y
`share_plus` aplican el Kotlin Gradle Plugin por su cuenta. Hoy es solo un
WARNING y compila; versiones futuras de Flutter fallarán.

| Plugin | Actual | Última | Usado en |
|---|---|---|---|
| `pdfx` | 2.9.2 | **2.9.2 - ya al día** | visor de documentos |
| `share_plus` | 10.1.4 | 13.3.0 | `properties/components/recibo_pago_sheet.dart` |
| `device_info_plus` | 12.4.0 | 13.2.0 | `core/portal_tracking.dart` |
| `package_info_plus` | 9.0.1 | 10.2.1 | transitivo, vía `geolocator_linux` |

**`pdfx` no tiene arreglo upstream**: está en su última versión, así que subir los
otros tres NO quita el warning. El camino real es reportarlo al plugin o cambiar
de lector de PDF.

Cuando toque: subir los tres `_plus` es un commit aparte con prueba en físico.
`share_plus` 10 → 13 son tres majors y cambia la API del único sitio de uso
(`Share.share(texto, subject:)`). Los constraints en `pubspec.yaml` fijan el
major, así que hay que ensancharlos a mano; `pub upgrade` solo no los mueve.

No está verificado si esas versiones nuevas ya migraron a Built-in Kotlin - hay
que leer sus changelogs antes de invertir el rato.

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

Resueltas desde la revisión anterior: `flutter test` ya corre en CI, y
`refactor/design-system-auth` se mergeó hace tiempo (el trabajo va por `dev-eddy`
→ `dev` → `main`).

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
5. **`analyze` limpio no prueba que compile.** Pasó tres veces.
6. **Cambios en `pubspec.yaml` exigen matar y relanzar `dev.sh`.** Ni `r` ni `R`
   los toman.
7. **El grep de lo fatal es `(error|warning) •`, no `^\s+(error|warning)`.** El
   analyzer sangra los infos y NO los warnings, así que el patrón con `^\s+`
   cuenta cero warnings y deja pasar un build roto. Costó un deploy.
