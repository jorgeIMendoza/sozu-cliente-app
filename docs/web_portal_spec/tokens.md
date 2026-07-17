# Design tokens — Portal del Cliente (web React)

> Fuente de verdad: `admin-sozu/sozu-admin` (verificado idéntico a `origin/dev` el 2026-07-17).
> El layout raíz del portal cliente lleva la clase **`.inmob-portal`**
> (`src/components/admin/portal-cliente/PortalClienteLayout.tsx` línea 91:
> `<div className="inmob-portal min-h-screen flex bg-background ...">`), por lo que
> **los tokens efectivos son los del bloque `.inmob-portal` de `src/index.css` (líneas 584-646)**,
> no los de `:root`. Donde `.inmob-portal` no define una variable (p.ej. `--border-soft`),
> aplica el valor de `:root`.

## 1. Paleta (valores efectivos dentro del portal cliente)

| Token | CSS var (fuente) | HSL | HEX | Uso |
|---|---|---|---|---|
| primary | `.inmob-portal --primary` (index.css:586) | `156 64% 38%` | **#239F6D** | Botones, links, item activo, chips, barra de progreso |
| primary-hover | `--primary-hover` (index.css:588) | `156 64% 30%` | #1C7D56 | Hover de botones primarios (también se usa `bg-primary/90`) |
| success | `--success` (index.css:591) | `156 64% 38%` | #239F6D | Chip "Pagado" (mismo verde que primary) |
| warning | `--warning` (index.css:593) | `38 92% 50%` | #F59E0B | Chip "Pendiente"/"Parcial", montos pendientes |
| destructive | `--destructive` (index.css:595) | `0 84% 60%` | #EF4444 | "Cerrar sesión", badge de notificaciones |
| background | `--background` (index.css:599) | `210 20% 98%` | **#F9FAFB** | Fondo del área de contenido |
| foreground | `--foreground` (index.css:600) | `220 13% 9%` | #14161A | Texto principal (casi negro) |
| card | `--card` (index.css:601) | `0 0% 100%` | #FFFFFF | Fondo de cards, topbar |
| muted | `--muted` (index.css:605) | `220 14% 96%` | #F3F4F6 | Fondos de hover, pista de progress bar, input de búsqueda |
| muted-foreground | `--muted-foreground` (index.css:606) | `220 9% 46%` | **#6B7280** | Texto secundario, labels, iconos inactivos |
| border | `--border` (index.css:613) | `220 13% 91%` | **#E5E7EB** | Bordes de cards, tabla, separadores |
| border-soft | `:root --border-soft` (index.css:53, no la pisa `.inmob-portal`) | `214.3 31.8% 93.5%` | #E9EEF4 | Bordes más tenues: topbar, secciones del sidebar |
| border-light | tailwind default (tailwind.config.ts:25) | `220 14% 96%` | #F3F4F6 | Bordes muy tenues |
| sidebar-background | `--sidebar-background` (index.css:619) | `0 0% 100%` | #FFFFFF | Fondo del sidebar (`bg-sidebar`) |
| sidebar-foreground | `--sidebar-foreground` (index.css:620) | `220 9% 46%` | #6B7280 | (definido; los items usan muted-foreground) |
| inmob-green-light / sidebar-accent | index.css:623/639 | `156 64% 93%` | #E2F9EF | Verde claro de marca (definido; el estado activo real usa primary al 6%) |
| inmob-text-muted | `--inmob-text-muted` (index.css:642) | `220 9% 64%` | #9BA1AB | Texto terciario en utilidades inmob |

### 1.1 Colores derivados por opacidad (muy usados — Tailwind `color/NN`)

El portal casi nunca usa tonos sólidos claros: usa el color base con alpha sobre blanco.
Equivalentes ya "aplanados" sobre `#FFFFFF`:

| Clase | rgba | HEX aplanado | Uso |
|---|---|---|---|
| `bg-primary/[0.06]` | rgba(35,159,109,.06) | #F2F9F6 | Fondo del item activo del sidebar |
| `bg-primary/5` | rgba(35,159,109,.05) | #F4FAF8 | Header de card "Instrucciones de Pago" |
| `bg-primary/10` | rgba(35,159,109,.10) | #E9F5F0 | Badge "N pagos" |
| `bg-primary/15` | rgba(35,159,109,.15) | #DEF1E9 | Chips de estatus de propiedad (En Preventa, etc.) |
| `border-primary/30` | rgba(35,159,109,.30) | #BDE2D3 | Borde hover de pills de filtro |
| `bg-success/10` | rgba(35,159,109,.10) | #E9F5F0 | Chip "Pagado" (fondo) |
| `bg-success/15` | rgba(35,159,109,.15) | #DEF1E9 | Chip estado "Entregada/Completado" |
| `bg-warning/10` | rgba(245,158,11,.10) | #FEF5E7 | Chip "Pendiente"/"Parcial" (fondo) |
| `bg-warning/15` | rgba(245,158,11,.15) | #FEF1DA | Chip "Pago Pendiente" |
| `bg-destructive/10` | rgba(239,68,68,.10) | #FDECEC | Hover de "Cerrar sesión" |
| `bg-muted/60` | rgba(243,244,246,.60) | #F8F9FA | Hover de items de menú, fondo del buscador |
| `bg-muted/30` | rgba(243,244,246,.30) | #FBFCFC | Fondo del selector "Ver como", header de popover |
| `bg-muted/20` | rgba(243,244,246,.20) | #FCFDFD | Header de card Movimientos, hover de fila de tabla |
| `bg-muted/10` | rgba(243,244,246,.10) | #FDFEFE | Fondo de thead y de fila expandida |
| `text-muted-foreground/70` | rgba(107,114,128,.70) | — | Placeholder e icono del buscador |
| `text-muted-foreground/40` | rgba(107,114,128,.40) | — | Versión de la app en footer del sidebar |

## 2. Tipografía

**No hay Google Fonts.** No existe link a fuentes en `index.html` y `tailwind.config.ts:20-21`
define la familia como **system font stack**:

```
font-sans / .inmob-portal font-family (index.css:644):
system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif
font-display (tailwind.config.ts:21): system-ui, -apple-system, BlinkMacSystemFont, "SF UI Text", sans-serif
```

En la práctica `font-display` ≈ `font-sans` (misma fuente del SO: SF en macOS, Segoe UI en Windows).
`-webkit-font-smoothing: antialiased` (index.css:645).

### Roles tipográficos (portal cliente)

| Rol | Clases | px / peso / extras | Fuente (archivo) |
|---|---|---|---|
| H1 de página | `font-display font-bold text-[22px] md:text-[26px] tracking-tight` | 22px móvil / 26px desktop, w700, letter-spacing −0.025em | ClienteEstadoCuenta.tsx:88 |
| Subtítulo de página | `text-[12px]` o `text-[13px] text-muted-foreground` | 12-13px, w400, #6B7280 | ClienteEstadoCuenta.tsx:91,135 |
| Título de card/sección | `font-display font-semibold text-sm` | 14px, w600 | AccountStatementView.tsx:470 |
| Título de card pequeño | `font-semibold text-xs` | 12px, w600 | AccountStatementView.tsx:387,436 |
| Label uppercase (filtros, thead) | `text-[11px] font-semibold uppercase tracking-wider` | 11px, w600, UPPERCASE, letter-spacing +0.05em, #6B7280 | AccountStatementView.tsx:363,482 |
| Label uppercase micro | `text-[10px] uppercase tracking-wider` | 10px, +0.05em | AccountStatementView.tsx:541 |
| Subtítulo de marca sidebar | `text-[10px] font-semibold tracking-[0.18em] uppercase` | 10px, w600, letter-spacing +0.18em (≈1.8px) | Sidebar.tsx:45 |
| Item de menú | `text-[13px] font-medium` | 13px, w500 | Sidebar.tsx:60 |
| Body tabla | `text-[13px] font-medium` (concepto) / `text-[12px]` (fecha) | 13px w500 / 12px w400 | AccountStatementView.tsx:496-497 |
| Montos | `font-semibold tabular-nums` | 13-14px, w600, cifras tabulares | AccountStatementView.tsx:98,403 |
| Small / metadata | `text-[11px]`, `text-[10px]` | 11px/10px, w400-500 | ubicuo |
| Chip / pill | `text-[11px] font-medium` (filtros) o `font-semibold` (estatus) | 11px, w500/600 | AccountStatementView.tsx:365,509 |
| Datos bancarios | `font-mono font-semibold text-xs` | 12px monospace w600 | AccountStatementView.tsx:447 |
| Botón primario | `text-xs font-semibold` | 12px, w600 | ClienteEstadoCuenta.tsx:102 |

## 3. Radios de borde

`--radius: 0.5rem` (index.css:616) + overrides de `tailwind.config.ts:130-137`:

| Clase | px | Uso en el portal |
|---|---|---|
| `rounded-md` | 6px | Items de menú, buscador, botones de popover |
| `rounded-lg` | 8px | Botón campana, icon-buttons de tabla (`p-1.5 rounded-lg`) |
| `rounded-xl` | **16px** (override `1rem`) | Botón "Descargar PDF", contenedor "Ver como", dropdown búsqueda |
| `rounded-2xl` | **24px** (override `1.5rem`) | **Todas las cards** (filtros, movimientos, resumen, instrucciones) |
| `rounded-full` | 9999px | Pills, chips, avatares, badges, progress bar |

## 4. Sombras

Las cards del estado de cuenta **no llevan sombra** — solo `border 1px #E5E7EB` sobre fondo #F9FAFB.

| Uso | Valor exacto | Fuente |
|---|---|---|
| Botón "Descargar PDF" | `shadow-sm` (Tailwind): `0 1px 2px 0 rgb(0 0 0 / 0.05)` | ClienteEstadoCuenta.tsx:102 |
| Dropdown de búsqueda | `shadow-lg` (Tailwind): `0 10px 15px -3px rgb(0 0 0 / .1), 0 4px 6px -4px rgb(0 0 0 / .1)` | PortalSearchInput.tsx:68 |
| Card genérica inmob (referencia) | `.inmob-card`: `0 1px 2px hsl(0 0% 0% / 0.04)` | index.css:649-654 |
| `.sozu-card` (otras vistas) | `0 1px 6px -1px hsl(0 0% 0% / .06), 0 1px 2px hsl(0 0% 0% / .04)` | index.css:396-401 |

## 5. Espaciados típicos (escala Tailwind: 1 = 4px)

| Patrón | Clases | px |
|---|---|---|
| Padding de card (densa) | `p-4` | 16px |
| Padding de card (resumen) | `p-5` | 20px |
| Header de card | `px-5 py-3` | 20px / 12px |
| Celdas de tabla | th `px-5/px-3 py-2.5`, td `px-5/px-3 py-3` | 20-12px / 10-12px |
| Gap entre cards | `space-y-4`, `gap-6` (grid) | 16px / 24px |
| Separadores internos de card | `border-t` + `pt-3` | 12px |
| Pills de filtro | `px-2.5 py-1` + `gap-1.5` | 10px/4px + 6px |
| Chips de estatus | `px-2.5 py-1` (tabla) / `px-2 py-0.5` (resumen) | 10px/4px, 8px/2px |
| Header de página | `pt-6 pb-4`, móvil `px-5` | 24px/16px, 20px |
| Nav del sidebar | contenedor `px-3 py-2`, item `pl-4 pr-3 py-2`, `space-y-0.5` | 12px/8px; 16-12px/8px; 2px |

## 6. Anchos y medidas de layout

| Medida | Clase (fuente) | px |
|---|---|---|
| Ancho sidebar | `w-64` (Sidebar.tsx:135, `lg:pl-64` en PortalClienteLayout.tsx:105) | **256px** |
| Alto topbar | `h-16` (TopBar.tsx:46) | 64px |
| Max-width contenido | `xl:max-w-7xl` (PortalClienteLayout.tsx:202) | **1280px**, centrado (`mx-auto`) |
| Max-width vista detalle propiedad | `md:max-w-5xl` (PortalClienteLayout.tsx:201) | 1024px |
| Gutters de contenido | `md:px-6 lg:px-8` | 24px (≥768) / 32px (≥1024); móvil: las páginas usan `px-5` = 20px |
| Buscador topbar | `max-w-[260px] h-8` (TopBar.tsx:48, PortalSearchInput.tsx:11) | 260×32px |
| Columna derecha estado de cuenta | `md:grid-cols-[minmax(0,1fr)_300px]` (AccountStatementView.tsx:633) | **300px fija**, gap 24px |
| Sticky offset col. derecha | `top-20` | 80px |
| Breakpoints Tailwind | sm 640 / md 768 / lg 1024 / xl 1280 / 2xl 1536 | sidebar visible ≥ **lg (1024px)** |
