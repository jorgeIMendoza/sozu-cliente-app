# ADR 0001 - Arquitectura modular, design system único y tokens semánticos

- **Estado:** aceptado · Fase 2 (tokens) implementada
- **Fecha:** 2026-07-28
- **Autor:** Eduardo Araujo
- **Alcance:** `sozu-cliente-app` (Flutter: web + Android + iOS). Este repo es la
  fuente de verdad del Portal del Cliente; `sozu-admin` ya no se trabaja para
  esta superficie - ver §8.

## Estado de implementación

| Fase | Estado |
|---|---|
| 0 - red de seguridad | AMBAR parcial: `test/ui/tokens_test.dart` (20 tests). Faltan lints estrictos y `flutter test` en CI |
| 1 - cerrar la capa de datos | [ ] pendiente |
| **2 - unificar tokens** | VERDE **hecho** (sin `tokens.json`: los tokens son Dart const, ver §5) |
| 3 - un solo design system | [ ] pendiente (primitivas) |
| 4 - features | [ ] pendiente |

Lo entregado en la Fase 2: `lib/ui/` con 27 roles semánticos, escalas de radio /
espaciado / tipografía / elevación, breakpoints con `context.responsive`,
densidad adaptativa, y `SozuColors` / `SozuTone` / `PortalColors` convertidos en
shims que reenvían ahí. **Cero archivos de pantalla tocados**: las ~1,700
referencias existentes siguen compilando y ya leen los tokens nuevos.
`flutter analyze` limpio, `flutter test` 20/20, `flutter build web --release` ok.

---

## 1. Contexto

`sozu-cliente-app` tiene hoy 85 archivos Dart / 44,075 LOC organizados por tipo
técnico (`core/ data/ providers/ screens/ widgets/`). El proyecto funciona y está
en producción, pero la base tiene cuatro fracturas que encarecen cada cambio:

### 1.1 Dos design systems paralelos que modelan lo mismo

| Concepto | Móvil (`widgets/common.dart`) | Portal web (`widgets/portal_widgets.dart`) |
|---|---|---|
| Contenedor | `AppCard` | `PortalCard` |
| Estado | `StatusBadge` (`BadgeTone`) | `PortalStatusChip` |
| Carga | `Skeleton` | `PortalSkeletonBox`, `PortalCardSkeleton`, `PortalKpiSkeleton` |
| Progreso | `SozuProgressBar` | `PortalProgressBar`, `PortalThinProgressBar` |
| Vacío | `EmptyCard` | `PortalEmptyState` |
| Título | `SectionTitle` | `PortalSectionLabel`, `PortalPageHeader` |
| Error | `ErrorCard` | - (no existe) |
| Botón | (tema global) | `PortalPrimaryButton`, `PortalOutlineButton`, `PortalBlockButton`, `PortalDashedButton` |

`portal_theme.dart:11` lo declara explícitamente: *"NO usa (ni modifica)
SozuTone/SozuColors: la paleta móvil (emerald/slate) es otra"*. Toda decisión
visual se paga dos veces y puede divergir en silencio.

### 1.2 Responsive resuelto con `if` esparcido

`isPortalMode(context)` aparece **39 veces en 25 archivos**. Cada pantalla nueva
reimplementa la decisión de layout. Además el predicado es
`kIsWeb && width >= 1024`: una tablet Android en horizontal nunca recibe el
layout ancho aunque le quede mejor, y Flutter web en un móvil chico entra al
branch equivocado si solo se mira `kIsWeb`.

### 1.3 Capa de datos perforada

`data/api_client.dart` debería ser la única puerta al backend. No lo es:

| Archivo | Fuga |
|---|---|
| `providers/auth_provider.dart` | 3 × `functions.invoke` propios |
| `core/portal_tracking.dart` | 3 × `functions.invoke` - acceso a red dentro de `core/` |
| `widgets/perfil_sheets.dart` | importa `supabase_flutter` + `Supabase.instance` **desde un widget** |
| `widgets/push_registrar.dart` | idem |
| `core/biometric_service.dart` | 2 × `Supabase.instance` |

Y hay llamadas de red directas dentro de la UI: `estado_cuenta_screen`(4),
`admin_avisos_screen`(4), `pagos_screen`(3), `perfil_sheets`(3).

### 1.4 Archivos-Dios y cero red de seguridad

```
3148  screens/propiedad_detalle_screen.dart
2617  screens/estado_cuenta_screen.dart
2359  screens/pagos_screen.dart
1849  screens/inicio_screen.dart
1844  screens/documentos_screen.dart
1686  widgets/perfil_sheets.dart
1583  data/models.dart          ← 56 clases, 95 `dynamic`
1557  widgets/credito_hipotecario_drawer.dart
```

- `test/` **no existe**. 0 tests.
- El único gate de CI es `flutter analyze` (8 puntos entre `codemagic.yaml` y
  `.github/workflows/`). Ningún `flutter test`.
- `analysis_options.yaml` = `flutter_lints` sin endurecer (sin `strict-casts`,
  sin `avoid_dynamic_calls`).
- 288 `setState` / 66 `State` classes: estado de negocio viviendo en widgets.
- 139 `Color(0x...)` hardcoded en 25 archivos: fuga de tokens.

---

## 2. Decisión de arquitectura

> **Feature-first modular + paquetes compartidos locales.**
> NO Clean Architecture / DDD por capas.

### 2.1 Por qué no DDD/Clean completo

El dominio real vive en el backend (Edge Functions + 2 RPC `SECURITY DEFINER`).
Esta app **presenta datos**; no custodia invariantes de negocio. Un `UseCase` por
endpoint que solo delega al repositorio son 4 archivos por pantalla sin valor
defensivo. Clean cobra su impuesto todos los días y solo paga si el dominio puede
cambiar independientemente del backend - no es el caso.

### 2.2 Por qué no "solo features" plano

Sin un paquete de UI extraído y con frontera verificable, el design system se
vuelve a bifurcar en cuanto entre otra superficie (portal agente, PWA, etc.).
La fractura §1.1 ya ocurrió una vez.

### 2.3 Sobre Screaming Architecture

No es una tercera opción a evaluar: es la *consecuencia* de nombrar las carpetas
por feature. `features/pagos/` ya grita. No requiere decisión aparte.

---

## 3. Layout objetivo

> **Nota de implementación:** el design system se creó como `lib/ui/`, NO como
> `packages/sozu_ui/`. Un paquete aparte exige `melos` y rompe todos los imports
> el primer día, a cambio de un beneficio -frontera verificada por el
> compilador- que solo se cobra cuando existe una segunda app. `lib/ui/` logra el
> aislamiento hoy y la extracción a paquete es un `git mv` + reescritura de
> imports cuando haga falta. Mientras tanto la frontera se sostiene por lint
> (§3.1). El layout de abajo es el destino, no el paso actual.

Monorepo con `melos`, dependencias por `path` (todo en este repo, nada publicado).

```
sozu-cliente-app/
├── melos.yaml
├── tokens/
│   └── tokens.json                  ← fuente de verdad de diseño (§5)
├── packages/
│   ├── sozu_tokens/                 ← GENERADO desde tokens.json. Cero lógica.
│   │   └── lib/tokens.g.dart
│   ├── sozu_ui/                     ← el "shadcn de Flutter"
│   │   ├── theme/       SozuTheme (ThemeExtension), Breakpoints, SozuDensity
│   │   ├── primitives/  SCard SButton SBadge SChip SSkeleton SProgress
│   │   │                SEmptyState SErrorState SField SSheet SDialog
│   │   ├── layout/      AdaptiveShell, ResponsiveValue, WebFrame, SGrid
│   │   └── (NO importa supabase, NO importa riverpod, NO importa sozu_api)
│   ├── sozu_core/       env, Result/Failure, format, SecureSessionStorage,
│   │                    adaptadores de plataforma (url_strategy, file_download, ua)
│   └── sozu_api/        DTOs + clientes de Edge Functions.
│                        (NO importa flutter/material)
└── apps/
    └── cliente/lib/
        ├── app/         bootstrap, router, main
        └── features/
            ├── auth/            {data, application, ui}
            ├── inicio/
            ├── patrimonio/      (propiedades, detalle, expediente, obra)
            ├── pagos/           (pagos, estado_cuenta, pagar, pago_final)
            ├── productos/
            ├── documentos/
            ├── perfil/
            ├── notificaciones/
            └── admin/           (impersonación, avisos, seleccionar_cliente)
```

Dentro de cada feature, tres carpetas y solo las que se ganen:

- `data/` - DTOs propios de la feature + llamadas (delegan a `sozu_api`).
- `application/` - providers Riverpod, estado, derivaciones. **Aquí va lo que hoy
  está en `setState` y los cálculos que hoy viven en `build()`.**
- `ui/` - pantallas y widgets de la feature. Sin `await` de red, sin `Supabase`.

### 3.1 Regla de dependencias (única, y verificada por el compilador)

```
apps/cliente/features  →  sozu_ui, sozu_core, sozu_api        OK
sozu_ui                →  sozu_tokens, sozu_core              OK
sozu_api               →  sozu_core                           OK
sozu_ui                →  sozu_api | riverpod | supabase      MAL - ROMPE EL BUILD
sozu_core              →  flutter/material                     MAL (solo dart:*/foundation)
features/X             →  features/Y                           MAL (via lint)
```

Esta es la separación UI ↔ lógica de negocio de la que hablamos. No es una
convención de code review: `sozu_ui/pubspec.yaml` simplemente no declara
`supabase_flutter` ni `flutter_riverpod`, así que el import no compila. La regla
`features/X → features/Y` sí necesita lint (`import_lint` o
`dart_code_metrics`), porque dentro del mismo paquete el compilador no ayuda.

---

## 4. Design system estilo shadcn en Flutter

shadcn/ui = tokens como CSS vars + variantes (CVA) + componentes que el consumidor
posee. Traducción honesta a Flutter:

### 4.1 Tokens semánticos, un solo set

Se elimina la dualidad `SozuTone` / `PortalColors`. Un `ThemeExtension`:

```dart
// packages/sozu_ui/lib/theme/sozu_theme.dart
@immutable
class SozuTheme extends ThemeExtension<SozuTheme> {
  final SozuColorRoles color;   // roles de §6
  final SozuRadii      radius;  // sm 6 · md 8 · lg 16 · card 24
  final SozuSpacing    space;   // 4 · 8 · 12 · 16 · 24 · 32 · 48
  final SozuTypeScale  type;    // = SozuType actual (ya es SoT, se conserva)
  final SozuElevation  shadow;
}

extension SozuThemeX on BuildContext {
  SozuTheme get s => Theme.of(this).extension<SozuTheme>()!;
}
// uso: context.s.color.fgMuted, context.s.radius.card, context.s.space.md
```

**Punto clave:** `PortalColors.background` (#F9FAFB) y `SozuColors.slate50`
(#F8FAFC) son **el mismo rol semántico con dos hex**. No son dos paletas: son
una paleta duplicada con drift. Igual `mutedForeground` (#6B7280) vs
`slate600` (#475569), `border` (#E5E7EB) vs `slate200` (#E2E8F0).

Si de verdad web debe *verse* distinto de móvil, la diferencia legítima es de
**densidad** (padding, radios, escala tipográfica), no de color:

```dart
enum SozuDensity { compact, comfortable }  // móvil / desktop
```

Resuelto una vez en el shell, no 39 veces en pantallas.

### 4.2 Variantes tipo CVA

```dart
SButton(variant: SVariant.primary, size: SSize.lg, onPressed: ...)
SCard(tone: STone.neutral, elevation: SElev.flat, child: ...)
SBadge.forStatus(PaymentStatus.pending)   // mapeo status→color: UNA vez, aquí
```

Hoy ese mapeo status→color está repetido en `PortalStatusChip`, `StatusBadge`,
`payment_method_badge.dart` y suelto en pantallas.

### 4.3 Responsive como valor, no como branch

```dart
// muere isPortalMode en las 25 pantallas
final cols = context.responsive(mobile: 1, tablet: 2, desktop: 3);

AdaptiveShell(          // bottom-nav ≤ md · sidebar 256 + topbar 64 ≥ lg
  body: child,          // decidido UNA vez, en un archivo
);
```

`isPortalMode` sobrevive únicamente dentro de `AdaptiveShell`, y se redefine por
**ancho disponible**, no por `kIsWeb` - así la tablet Android hereda el layout
ancho gratis.

### 4.4 Tipografía: una sola decisión

`typography.dart` (`SozuType`) ya es fuente de verdad correcta: escala ~1.25,
Poppins en títulos/botones, Inter en texto. Se conserva tal cual y se mueve a
`sozu_ui/theme/`.

Se **elimina** `kPortalFontFallback` (20 usos). Contradice a `SozuType` y en web
no hace nada: CanvasKit rasteriza el texto y solo reconoce las fuentes
declaradas en `pubspec.yaml` - lo dice el propio comentario de `theme.dart:141-149`.
Los 20 usos piden `-apple-system/Segoe UI` que nunca se resuelven.

---

## 5. Fuente de verdad de los tokens

**Decisión revisada al implementar:** no hay `tokens.json` ni codegen. Los tokens
son constantes Dart en `lib/ui/tokens/`.

El `tokens.json` + generador tenía un único propósito: emitir también CSS vars
para `sozu-admin`. Al dejar de trabajar el portal cliente en React (§8), ese
consumidor desaparece y el generador se queda siendo pura ceremonia: un paso de
build, un artefacto commiteado y un archivo que puede quedar desincronizado, a
cambio de nada. Dart const ya da lo que se quería -un solo lugar que editar- con
verificación del compilador encima.

Si algún día vuelve a haber un consumidor no-Dart, `lib/ui/tokens/palette.dart`
es plano y regular a propósito: extraer un JSON de ahí es mecánico.

Jerarquía dentro de `tokens/`:

```
palette.dart      rampas crudas (SozuBrand, SozuNeutral, SozuAmber, SozuRed)
    ↓             ← las pantallas NO tocan esto
color_roles.dart  27 roles semánticos × {light, dark}
    ↓             ← las pantallas usan esto, vía context.s.color
```

`docs/web_portal_spec/tokens.md` deja de ser el contrato y pasa a ser
documentación derivada.

---

## 6. Tabla de colisiones: `SozuTone` + `PortalColors` → roles semánticos

Esta es la decisión más espinosa del ADR y por eso va resuelta en papel.

### 6.1 Dirección de la migración

Se **conserva la API de roles de `SozuTone`** y se **reemplazan sus hex por los
valores de `PortalColors`**. Razones:

1. `SozuTone` ya es indirección por rol (`tone.textSecondary`), con ~987 accesos.
   Cambiar el hex detrás del rol es una línea.
2. Los accesos a la rampa cruda `SozuColors.slateX` son **27** en total, y solo
   **13** fuera de `core/theme.dart` - repartidos en 5 archivos (`common.dart`×5,
   `level_map.dart`×3, `expediente_card.dart`×3, `property_card.dart`×1,
   `patrimonio_card.dart`×1). El costo real de tirar `slate` es casi nulo.
3. `PortalColors` (749 refs) es la paleta que hoy define el look de producción en
   web y la que empata con el portal React. Su rampa neutra es Tailwind **gray**
   (neutral); la de móvil es **slate** (azulada). Unificar en gray acerca las dos
   superficies; unificar en slate las aleja.
4. `SozuTone` sí aporta algo que `PortalColors` no tiene: **variante dark**.
   `portal_theme.dart:12` dice *"El portal es siempre claro"*. Se conserva la
   capacidad dark y se inventan los valores dark faltantes.

Neta: **rampa neutra = gray (portal gana) · estructura de roles + dark = SozuTone gana.**

### 6.2 Tabla

Leyenda: VERDE sin colisión · AMBAR colisión cosmética (hex casi igual) · ROJO colisión
real (decisión de diseño) · + rol nuevo que solo existía en un lado.

| Rol nuevo | `SozuTone.light` | `PortalColors` | **Elegido (light)** | **dark** | |
|---|---|---|---|---|---|
| `surface` | `Colors.white` | `surface` #FFFFFF | **#FFFFFF** | `slate800`→`#1A1D21` | VERDE |
| `surfaceAlt` | `slate50` #F8FAFC | `mutedHover` #F8F9FA | **#F8F9FA** | `#22262B` | AMBAR |
| `background` | `slate50` #F8FAFC | `background` #F9FAFB | **#F9FAFB** | `#101215` | AMBAR |
| `muted` | - | `muted` #F3F4F6 | **#F3F4F6** | `#2A2F35` | + hovers, pista de progress |
| `border` | `slate200` #E2E8F0 | `border` #E5E7EB | **#E5E7EB** | `#2E343B` | AMBAR |
| `borderSoft` | - | `borderSoft` #E9EEF4 | **#E9EEF4** | `#272C32` | + topbar, secciones sidebar |
| `fg` | `slate900` #0F172A | `foreground` #14161A | **#14161A** | `#F3F4F6` | ROJO: azulado vs neutro → neutro |
| `fgMuted` | `slate600` #475569 | `mutedForeground` #6B7280 | **#6B7280** | `#9BA1AB` | ROJO: **230 usos**, el rol más usado |
| `fgSubtle` | `slate400` #94A3B8 | `textMuted` #9BA1AB | **#9BA1AB** | `#6B7280` | AMBAR |
| `primary` | `emerald500` #239F71 | `primary` #239F71 | **#239F71** | #239F71 | VERDE: ya unificado en `brand.dart` |
| `primaryHover` | `primaryDark` #1D825D | `primaryHover` #1D825D | **#1D825D** | `green400` #2ED195 | VERDE |
| `primaryPressed` | `emerald700` #166448 | - | **#166448** | #1D825D | + |
| `primarySoft` | `emerald50` #EEFBF7 | `primarySoft6` #F2F9F7 | **escalera ↓** | `#0B3B30` | ROJO: ver §6.3 |
| `primaryBorder` | - | `primaryBorder30` #BDE2D4 | **#BDE2D4** | `#2A5A48` | + 16 usos |
| `positive` | `emerald600` #1D825D | *(usa `primary`)* | **#1D825D** | `#2ED195` | ROJO: ver §6.4 |
| `warning` | `amber500` #F59E0B | `warning` #F59E0B | **#F59E0B** | #F59E0B | VERDE: idéntico |
| `warningSoft` | `amber50` #FFFBEB | `warningSoft10` #FEF5E7 | **#FEF5E7** | `#3B2F0B` | AMBAR |
| `warningSoftStrong` | - | `warningSoft15` #FEF1DA | **#FEF1DA** | `#4A3A0D` | + |
| `danger` | `rose600` #E11D48 | `destructive` #EF4444 | **#EF4444** | `#F87171` | ROJO: rose vs red → **red** |
| `dangerSoft` | - | `destructiveSoft10` #FDECEC | **#FDECEC** | `#3A1F1F` | + |
| `dangerSoftStrong` | - | `destructiveSoft15` #FDE3E3 | **#FDE3E3** | `#4A2626` | + |

> **Los hex de la columna `dark` son propuesta, no decisión.** Los valores light
> salen de código existente (uno de los dos sistemas); los dark hay que
> inventarlos, porque `PortalColors` es light-only. Lo que este ADR fija es que
> **el rol existe** en dark; el hex exacto se afina con diseño (o se difiere -
> ver §10.3).

**Se eliminan** tras la migración: `SozuColors` (rampa slate/emerald/amber/rose
cruda), `SozuTone`, `PortalColors`, `PortalColors.mutedSoft20/30`
(#FCFDFD/#FBFCFC - indistinguibles de `surface` a ojo; 16 usos colapsan a
`surface` o `surfaceAlt`).

### 6.3 Escalera de tintes de primary

`PortalColors` tiene 4 niveles (`soft5/6/10/15`) porque el CSS original usaba
`bg-primary/5`, `/6`, `/10`, `/15`. Cuatro niveles con 3% de diferencia entre sí
no son distinguibles y generan decisiones arbitrarias. Se colapsan a **dos**:

| Nuevo | Valor | Sustituye a | Uso |
|---|---|---|---|
| `primarySoft` | #F2F9F7 | `soft05` (4 usos) + `soft06` (6 usos) | fondo de item activo, headers |
| `primarySoftStrong` | #E9F5F1 | `soft10` (25 usos) + `soft15` (12 usos) | chips de estado, badges |

Mismo criterio para `warningSoft`/`dangerSoft`: máximo dos niveles por color.

### 6.4 `positive` ≠ `primary`

El tema móvil distingue `positive` (#1D825D) de `primary` (#239F71); el portal
usa `primary` para ambas cosas. Se **conserva la distinción**: "pagado/completo"
y "acción principal de marca" son semánticas distintas y en algún momento van a
querer divergir (p. ej. un verde de éxito más saturado). Costo de conservarla: 0.

### 6.5 Radios y espaciado

Radios: se adopta la escala del portal, ya coherente con el tema móvil
(`theme.dart` usa `circular(16)` en inputs y botones = `lg`).

```
sm 6   → items de menú, buscador
md 8   → icon-buttons, campana
lg 16  → botones grandes, inputs, dropdowns
card 24 → todas las cards
```

Espaciado: **hoy no existe escala** - los paddings son literales sueltos en las
pantallas. Se define `SozuSpacing` = `4 · 8 · 12 · 16 · 24 · 32 · 48`
(`xxs·xs·sm·md·lg·xl·xxl`) y se migra oportunistamente: cada archivo que se toque
por otra razón cambia sus literales. No se hace un barrido dedicado.

---

## 7. Plan de migración

Incremental. Cada fase es mergeable por separado y deja la app funcionando.

### Fase 0 - red de seguridad (antes de mover nada)

1. Crear `test/`. Golden tests de las primitivas de `sozu_ui` (light + dark ×
   compact + comfortable). Tests unitarios de `format.dart` y de los parsers de
   `models.dart`.
2. Agregar `flutter test` a los 8 puntos de CI que hoy solo corren
   `flutter analyze` (`codemagic.yaml` ×7, `deploy-web-firebase.yml` ×1).
3. Endurecer `analysis_options.yaml`:
   ```yaml
   analyzer:
     language:
       strict-casts: true
       strict-raw-types: true
     errors:
       invalid_use_of_protected_member: error
   linter:
     rules:
       - avoid_dynamic_calls
       - always_declare_return_types
       - prefer_final_locals
       - unawaited_futures
   ```
4. Lint de fronteras (`import_lint`) con las reglas de §3.1.

> Sin la Fase 0, las fases 2 y 3 son refactors de color a ciegas sobre 44k LOC.

### Fase 1 - cerrar la puerta de datos

5. Mover todo `functions.invoke` a `api_client`: `auth_provider.dart`(3),
   `portal_tracking.dart`(3).
6. Sacar `Supabase.instance` de la capa de UI: `perfil_sheets.dart`,
   `push_registrar.dart`. `biometric_service.dart` y `portal_tracking.dart` salen
   de `core/` (no son infraestructura neutral: hablan con el backend).
7. Partir `models.dart` (1583 / 56 clases) por feature. Eliminar los 95 `dynamic`
   - con `strict-casts` de Fase 0 ya duelen.

### Fase 2 - unificar tokens

8. `tokens/tokens.json` + `tool/gen_tokens.dart` → `sozu_tokens`.
9. Implementar `SozuTheme` con los roles de §6.2. `SozuTone` y `PortalColors`
   quedan como `@Deprecated` reenviando a los roles nuevos → un solo PR mecánico
   los borra.
10. Barrer los 139 `Color(0x...)` de los 23 archivos que no son de tokens.

### Fase 3 - un solo design system

11. Fusionar los pares de §1.1, en orden de riesgo creciente:
    `Skeleton` → `Badge/Chip` → `Card` → `EmptyState` → `Progress` → `Button`.
12. `AdaptiveShell` + `context.responsive`. Borrar `isPortalMode` de las 25
    pantallas; queda solo dentro del shell, redefinido por ancho disponible.
13. Borrar `kPortalFontFallback` (§4.4).

### Fase 4 - features

14. Mover feature por feature, de menor a mayor riesgo:
    `notificaciones` → `perfil` → `documentos` → `productos` → `pagos` →
    `patrimonio` → `auth` → `admin`.
15. Al mover, partir los archivos-Dios y subir el estado a `application/`:
    - `propiedad_detalle_screen.dart` (3148) → `features/patrimonio/ui/detalle/`
      en ~10 secciones.
    - `estado_cuenta_screen.dart` (2617, 28 `setState`, 4 llamadas de red) →
      providers en `features/pagos/application/`.
    - `pagos_screen.dart` (2359, 27 `setState`), `perfil_sheets.dart` (1686),
      `credito_hipotecario_drawer.dart` (1557), `admin_avisos_screen.dart`
      (1126, 31 `setState`).

**Criterio de "hecho" por fase:** F0-F1 bajan riesgo de inmediato. F2-F3 es donde
"cambio un token → cambia todo" se vuelve real. F4 es lo que evita los conflictos
de merge recurrentes en los mismos 8 archivos.

---

## 8. Fuera de alcance: `sozu-admin` (React)

Se documenta porque es el costo oculto más grande, pero **no** se aborda en este ADR.

`sozu-admin` (Vite + React 18 + Tailwind + shadcn/ui) contiene **80 componentes**
en `src/components/portal/` - `AccountStatementView`, `FinancialSummary`,
`PaymentHistoryView`, `DocumentListItem`, `NextInstallmentCard`, `BottomNav`… Es
el **mismo portal del cliente**, en otro stack. Esta app Flutter lo reimplementa
copiando el CSS a mano vía `docs/web_portal_spec/tokens.md`.

Dos codebases del mismo producto. Ningún refactor interno lo arregla.

Cuando se aborde, dos verdades a tener presentes:

1. Lo único compartible entre Dart y TSX son **tokens**, no componentes:
   `tokens.json → tokens.css` (CSS vars → `tailwind.config.ts`). El contrato
   visual se comparte; el código no.
2. La pregunta de fondo es de producto, no técnica: **qué portal cliente
   sobrevive**. Mantener los dos indefinidamente cuesta el doble en cada feature.

`tokens.json` (§5) se diseña desde ya con esa salida en mente, para que
habilitarla después sea agregar un generador, no rediseñar el formato.

---

## 9. Consecuencias

**A favor**

- La frontera UI ↔ negocio la verifica el compilador, no el code review.
- Un cambio de token toca 1 archivo y sale en web + Android + iOS.
- Un solo componente por concepto: se elimina el drift silencioso entre móvil y
  portal.
- Archivos de tamaño revisable → menos conflictos de merge en trabajo paralelo.
- Existe red de seguridad (tests + lints estrictos) donde hoy no hay ninguna.
- El paquete `sozu_ui` queda listo para una segunda app sin re-bifurcar.

**En contra / costos**

- `melos` + monorepo agregan ceremonia al setup local y al CI.
- Fases 2-3 tocan muchísimos archivos: PRs grandes y mecánicos, difíciles de
  revisar línea por línea. De ahí que la Fase 0 sea obligatoria antes.
- Cambio visual real y visible para el usuario: la rampa neutra pasa de slate
  (azulada) a gray, y `danger` de rose a red. **Requiere aprobación de diseño
  antes de la Fase 2.**
- Durante Fase 4 conviven la estructura vieja (`screens/`, `widgets/`) y la nueva
  (`features/`). Hay que aceptar el estado intermedio y no dejarlo a medias.

**Riesgos y mitigación**

| Riesgo | Mitigación |
|---|---|
| Regresión visual en el barrido de color | Golden tests de Fase 0 antes de tocar tokens |
| Fase 4 se queda a medio camino | Una feature por PR; no abrir la siguiente sin cerrar la anterior |
| El cambio slate→gray no le gusta a diseño | Decidir §6.2 con diseño **antes** de Fase 2; es reversible en 1 archivo, pero solo antes de borrar los deprecated |
| `melos` estorba más de lo que ayuda | Fases 0-1 no lo necesitan; introducirlo al empezar Fase 2 |

---

## 9-bis. Trampas encontradas al implementar

Se documentan porque las tres son silenciosas: compilan, no dan warning, y el
síntoma aparece lejos de la causa.

**1. `SozuTheme.type` pisa `ThemeExtension.type`.**
`ThemeExtension` declara `Object get type` y Material la usa como CLAVE del mapa
`ThemeData.extensions`. Nombrar el campo tipográfico `type` compila (una
`SozuTypeScale` es un `Object`) y el analyzer solo pide un `@override`. Pero
entonces el mapa queda indexado por la escala tipográfica y
`Theme.of(context).extension<SozuTheme>()` devuelve `null` **para siempre**:
`context.s` cae al tema por defecto en toda la app sin un solo mensaje de error.
Por eso el campo se llama `text`. Hay un test que fija esto
(`la clave del mapa de extensiones es el Type`).

**2. El analyzer es más permisivo que el compilador con spreads genéricos.**
`extensions: <ThemeExtension<dynamic>>[...base.extensions.values, tokens]` pasa
`flutter analyze` y falla en `flutter test` / `flutter build`:
`Can't assign spread elements of type 'ThemeExtension<dynamic>' to collection
elements of type 'ThemeExtension<ThemeExtension<dynamic>>'`. Corolario: **analyze
limpio no es prueba de que compile.** El gate de CI necesita `flutter test`, no
solo `analyze` - que es justo lo que pide la Fase 0.

**3. Los shims deben apuntar a las constantes de la paleta, no a campos de rol.**
`static const x = SozuColorRoles.light.primary` no es válido en Dart (leer un
campo de instancia no es expresión constante). Y `PortalColors` tiene 20 usos
dentro de expresiones `const`, así que volverlo `static final` habría roto la
compilación. Por eso los shims reenvían a `SozuBrand.*` / `SozuNeutral.*`
-constantes top-level- y no a `SozuColorRoles.light.*`.

## 9-ter. Sobre el error de hot reload

```
Const class cannot remove fields: Class: AuthBrandPanel
Hot reload rejected due to unsupported changes.
```

No es un defecto de la app ni de esta arquitectura. Es una limitación del hot
reload de Dart: al quitar o renombrar un campo de una clase con constructor
`const`, la VM no puede re-canonicalizar las instancias constantes ya creadas.
Solución: hot restart (`R`). Aparece más seguido al trabajar en tokens y widgets
`const`, así que conviene reflejo de `R` en vez de `r` durante estas fases.

## 10. Decisiones pendientes (bloquean fases concretas)

1. **Rampa neutra gray vs slate y `danger` red vs rose** → bloquea Fase 2.
   Requiere sí/no de diseño.
2. **`SozuDensity`: ¿web y móvil deben verse distintos más allá del layout?**
   → bloquea Fase 3. Si la respuesta es "no", `SozuDensity` se cae y el DS se
   simplifica.
3. **Dark mode: ¿es requisito de producto?** Hoy `theme_provider.dart` existe y
   el portal web es light-only. Si dark no se va a soportar en web, los valores
   dark de §6.2 se pueden diferir (no eliminar el rol, solo no pulir los hex).
