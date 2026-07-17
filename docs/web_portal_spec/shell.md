# Shell del Portal del Cliente (sidebar + topbar + contenido)

> Fuentes: `src/components/admin/portal-cliente/PortalClienteLayout.tsx`, `Sidebar.tsx`,
> `TopBar.tsx`, `PortalSearchInput.tsx`, `ClienteImpersonationSelector.tsx`,
> `src/components/ui/SozuLogo.tsx`, `src/lib/portal-cliente/portal-nav-data.ts`.
> Colores hex resueltos en `tokens.md`. Todo verificado igual a `origin/dev`.

## Estructura general (PortalClienteLayout.tsx:91-207)

```
<div .inmob-portal min-h-screen flex bg-background (#F9FAFB)>
 ├─ <aside> Sidebar fija (solo ≥1024px)              ← 256px, izquierda
 ├─ (móvil) Sheet drawer izquierdo w-64 con el mismo SidebarContent
 └─ <div flex-1 lg:pl-64 flex-col min-h-screen>
     ├─ TopBar sticky (solo ≥1024px)                  ← 64px alto
     ├─ (móvil <1024px) header propio con hamburguesa + búsqueda + "Vista como"
     └─ <main flex-1 mx-auto pb-8 md:px-6 lg:px-8 xl:max-w-7xl>  ← contenido
```

- Fondo global del área de contenido: `bg-background` = **#F9FAFB**.
- El `main` está centrado con max-width **1280px** (`xl:max-w-7xl`); en la vista
  detalle de propiedad (`/propiedad/:id`) baja a **1024px** (`md:max-w-5xl`).
- `pb-8` (32px) al final del contenido. Sin padding horizontal en móvil (las páginas
  ponen su propio `px-5`).

## Sidebar (Sidebar.tsx)

Contenedor (`Sidebar`, línea 135):
`hidden lg:flex fixed top-0 left-0 bottom-0 w-64 z-30 flex-col bg-sidebar border-r border-border`
→ **256px de ancho, fondo #FFFFFF, borde derecho 1px #E5E7EB, fija a toda la altura, visible solo ≥1024px.**

### 1. Brand (líneas 43-48)
- Contenedor: `px-5 py-4` (20/16px), `border-b border-border-soft` (1px #E9EEF4), columna con `gap-1` (4px).
- Logo SOZU: `<SozuLogo className="h-6" />` — **24px de alto**, ancho auto por aspect-ratio
  `932/268` (≈ 83px). Es una máscara CSS del PNG del logo pintada con `--foreground`
  (#14161A, casi negro) — ver SozuLogo.tsx. En Flutter: asset del logo teñido de #14161A.
- Subtítulo: texto exacto **"Portal del cliente"** renderizado en mayúsculas —
  `text-[10px] font-semibold tracking-[0.18em] uppercase text-gray-500`
  → 10px, w600, letter-spacing 1.8px, color #6B7280 (gray-500 Tailwind).

### 2. Navegación (líneas 51-79)
- Contenedor: `flex-1 px-3 py-2 space-y-0.5 overflow-y-auto` (padding 12/8px, 2px entre items).
- **Los items vienen de BD** (`submenus` con `menu_id=18`, orden por `orden`;
  portal-nav-data.ts:38-69). Mapa ruta→icono lucide (portal-nav-data.ts:25-36):

| Ruta | Icono lucide | Label típico (BD) |
|---|---|---|
| /inicio | Home | Inicio |
| /en-adquisicion | ShoppingBag | En adquisición |
| /patrimonio | Wallet | Patrimonio |
| /documentos | FileText | Documentos |
| /notificaciones | Bell | Notificaciones |
| /perfil | User | Perfil |
| /pagos, /historial-pagos | CreditCard | Pagos / Historial |
| /estado-de-cuenta | BarChart2 | Estado de cuenta |
| /productos | Package | Productos |

- Item (línea 60): `w-full flex items-center justify-between gap-3 pl-4 pr-3 py-2 rounded-md text-[13px] font-medium`
  → alto ≈ 36px, radio 6px, icono 16px (`size-4`) con gap 12px al label.
- **Estado activo**: `bg-primary/[0.06] text-primary` → fondo **#F2F9F6** (verde al 6% sobre
  blanco), texto e icono **#239F6D**; MÁS una barrita indicadora absoluta pegada al borde
  izquierdo del item: `w-[2px]` a toda la altura, `bg-primary`, esquinas derechas redondeadas
  (`rounded-r`) (línea 66).
- **Inactivo**: `text-muted-foreground` (#6B7280), icono al 60% de opacidad.
- **Hover inactivo**: `hover:bg-muted/60 hover:text-foreground` (fondo #F8F9FA, texto #14161A,
  icono a opacidad 100%), transición 150ms.
- Activo se determina por prefijo de ruta (`isNavItemActive`); "Inicio" solo con match exacto.
- Badge de notificaciones sin leer (solo item notificaciones, líneas 71-75):
  `min-w-[18px] h-[18px] px-1 rounded-full bg-destructive text-destructive-foreground
  text-[10px] font-bold` → círculo rojo #EF4444, texto blanco, "9+" si >9.

### 3. Footer (líneas 82-129)
- Contenedor: `px-3 pt-1 pb-4 border-t border-border-soft space-y-1`.
- **Botón perfil** (líneas 84-95): fila `gap-3 px-2 py-2 rounded-md hover:bg-muted/60` con:
  - Avatar: círculo `w-8 h-8` (32px) `bg-primary` (#239F6D) con **iniciales** (2 primeras
    palabras del nombre) en blanco `text-[11px] font-semibold`.
  - Nombre: `text-[13px] font-medium text-foreground truncate` (nombre truncado a 2 palabras,
    máx 22 chars con "…"; PortalClienteLayout.tsx:20-24).
  - Rol debajo: `text-[11px] text-muted-foreground` (p.ej. "Cliente").
  - ChevronRight 16px a la derecha, visible solo en hover.
- **Acciones** — dos variantes según `isClient` (rol "Cliente" vs admin impersonando):
  - **Cliente final** (líneas 97-104): un solo botón centrado
    `py-1.5 rounded-md text-[12px] text-destructive hover:bg-destructive/10` con icono
    LogOut 16px + texto **"Cerrar sesión"** (rojo #EF4444, hover fondo #FDECEC).
  - **Admin (solo impersonación)** (líneas 105-124): dos botones lado a lado (`flex gap-2`,
    cada uno `flex-1`): **"Regresar"** (ArrowLeft, `text-muted-foreground`,
    hover `text-foreground bg-muted/60`; navega a /admin — solo si `canReturnToAdmin`) y
    **"Cerrar sesión"** (idéntico al de cliente). Mismo tamaño `text-[12px] py-1.5`.
- **Versión** (línea 127): `text-[10px] text-muted-foreground/40 font-mono text-center`
  — número de versión de la app (APP_VERSION), gris muy tenue, monospace, centrado.

## TopBar de escritorio (TopBar.tsx:46-103)

`hidden lg:flex sticky top-0 z-20 h-16 items-center gap-4 px-6 lg:px-8 bg-card border-b border-border-soft`
→ **64px de alto, fondo #FFFFFF, borde inferior 1px #E9EEF4, sticky, padding horizontal 32px, gap 16px. Solo ≥1024px.**

Orden de elementos (izquierda → derecha):

### 1. Buscador global (PortalSearchInput.tsx)
- `w-full max-w-[260px]`, input `h-8` (32px) `pl-9 pr-3 rounded-md bg-muted/60
  border border-transparent text-[13px]`.
- Icono Search 16px absoluto a la izquierda (left 12px), color `muted-foreground/70`.
- Placeholder exacto: **"Buscar propiedades, documentos, pagos…"** color muted-foreground/70.
- Focus: `bg-muted/80`, sin ring.
- Dropdown de resultados (≥2 caracteres, debounce 200ms): panel absoluto
  `mt-1 bg-card border border-border rounded-xl shadow-lg`; filas `px-4 py-2.5 text-[13px]
  hover:bg-muted/60` con nombre de proyecto (medium) + `· unidad` (muted). Hasta 4 propiedades;
  atajos "Mi expediente" si el query contiene "doc/exped" y "Historial de pagos" si contiene
  "pago/historial".

### 2. Selector de impersonación "Ver como" (ClienteImpersonationSelector.tsx:174-314) — **SOLO ADMIN**
- Se auto-oculta si `profile.puede_impersonar !== true` (línea 24, 171). **El cliente final NUNCA lo ve.**
- Contenedor: `flex items-center gap-1.5 rounded-xl border border-border-soft bg-muted/30
  pl-2.5 pr-1.5 h-9` → pastilla de 36px de alto, radio 16px, fondo #FBFCFC, borde #E9EEF4.
- Icono Eye 14px muted + label **"Ver como"** `text-[11px] font-medium uppercase tracking-wide
  text-muted-foreground` (visible solo ≥1280px, `hidden xl:inline`).
- Tres controles separados por divisores verticales (`h-5 w-px bg-border`):
  1. **Proyecto**: combobox (icono Building2 14px + nombre truncado max-w 170px + ChevronsUpDown 12px);
     abre popover 260px con Command/búsqueda "Buscar proyecto...".
  2. **No. de propiedad**: input de texto transparente de 72px, placeholder "No. prop", icono Home 14px.
  3. **Cliente**: combobox (UserSearch 14px, max-w 200px); popover 280px, lista de dueños
     resueltos por proyecto+propiedad (con contador de copropietarios en badge
     `bg-primary/15 text-primary text-[10px] rounded-full`) + "Todos los clientes".
- Al impersonar aparece botón X (24×24, hover `bg-destructive/10 text-destructive`) para limpiar.

### 3. Derecha (`ml-auto`, gap 8px)
- **Campana**: botón `w-9 h-9 rounded-lg hover:bg-muted text-muted-foreground`, icono Bell 18px.
  Badge de no leídos: `min-w-[15px] h-[15px] text-[9px] font-bold rounded-full bg-destructive`
  texto blanco, posicionado arriba-derecha. Abre popover de notificaciones.
- **Avatar**: círculo `w-8 h-8 bg-primary` con iniciales blancas `text-[11px] font-semibold`,
  `hover:opacity-90`. Abre popover de 240px (`w-60 p-0 rounded`): header `px-4 py-3
  bg-muted/30 border-b border-border-soft` con avatar 36px + nombre `text-[13px] semibold` +
  rol `text-[11px] muted` + teléfono opcional; cuerpo `p-1.5` con items `px-3 py-2 rounded-md
  text-[13px]`: **"Ver perfil"** (icono User, hover bg-muted/60) y **"Cerrar sesión"**
  (icono LogOut, `text-destructive`, hover `bg-destructive/10`).

## Header móvil (<1024px) (PortalClienteLayout.tsx:110-195)

Sticky, `bg-card border-b border-border`, tres franjas:
1. Fila principal `px-4 pt-3 pb-2 gap-3`: botón hamburguesa (Menu 20px) que abre el drawer,
   título de la sección actual `text-[15px] font-semibold tracking-tight`, campana 36px con
   punto rojo 7px, avatar 32px con popover idéntico al de escritorio.
2. Búsqueda: `px-4 pb-2`, mismo PortalSearchInput a ancho completo con `h-9`.
3. Solo admin: fila "Vista como:" (`text-[11px] muted`) + ClienteImpersonationSelector.

## Qué aplica al cliente final vs admin

| Elemento | Cliente final | Admin impersonando |
|---|---|---|
| Sidebar completa + nav | ✔ | ✔ |
| Footer: "Cerrar sesión" solo | ✔ | — |
| Footer: "Regresar" + "Cerrar sesión" | — | ✔ |
| Buscador global | ✔ | ✔ |
| Selector "Ver como" | ✖ (oculto por `puede_impersonar`) | ✔ |
| Campana + avatar/popover | ✔ | ✔ |

Para la app Flutter del cliente: **replicar todo excepto el selector "Ver como" y el botón
"Regresar"** (son exclusivos del admin en sozu-admin).
