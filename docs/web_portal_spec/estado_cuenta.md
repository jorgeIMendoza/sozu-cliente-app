# Spec — Pantalla "Estado de cuenta"

> Fuentes: `src/pages/admin/portal-cliente/ClienteEstadoCuenta.tsx` (página) y
> `src/components/admin/portal-cliente/AccountStatementView.tsx` (vista principal).
> Verificado idéntico a `origin/dev`. Hex resueltos en `tokens.md`.
> Formato de moneda: `fmtMXNDecimals` → `$1,234,567.00` (MXN con 2 decimales).

## Dos estados de la página

1. **Sin propiedad seleccionada** (sin query param `?p=`): selector de propiedad.
2. **Con propiedad** (`?p=<idCuenta>`): header + `AccountStatementView`.

---

## A. Selector de propiedad (ClienteEstadoCuenta.tsx:129-198)

- Header: `pt-6 pb-4` — H1 **"Estado de cuenta"** (`font-display font-bold text-[22px]
  md:text-[26px] tracking-tight`) + subtítulo **"Selecciona una propiedad."**
  (`text-[13px] text-muted-foreground mt-1`).
- Buscador: input `h-10 pl-9 pr-4 rounded-xl border border-border bg-card text-sm`,
  icono Search 16px, placeholder **"Buscar propiedad…"**, focus `ring-2 ring-ring`.
- Lista (`space-y-2`, máx alto `min(380px,60dvh)` con scroll): cada propiedad es un botón-card
  `bg-card rounded-2xl border border-border p-4 gap-3.5`, hover `border-primary/30`,
  active `scale-[0.98]`:
  - Cuadro 40×40 `rounded-xl` con el número de unidad en bold 14px; fondo/texto según estatus
    (statusStyles, líneas 11-18): "Pago Pendiente" → `bg-warning/15 text-warning`;
    "En Preventa"/"En Escrituración"/"Por Entregar" → `bg-primary/15 text-primary`;
    "Entregada"/"Completado" → `bg-success/15 text-success`.
  - Título: `{projectName}` semibold 14px + ` · U{unitNumber}` normal muted.
  - Segunda línea 11px: label de estatus (color del estatus) `•` "{n}% pagado · $X".
  - ChevronRight 16px muted a la derecha.
- Vacíos: "No tienes propiedades activas." / "Sin resultados" (`text-sm muted`, centrado).

---

## B. Header con propiedad seleccionada (ClienteEstadoCuenta.tsx:85-111)

- `px-5 md:px-0 pt-6 pb-4`, fila con gap 12px:
  - H1 **"Estado de cuenta"** — `font-display font-bold text-[22px] md:text-[26px]
    tracking-tight text-foreground`.
  - Subtítulo debajo: **"{projectName} - U-{unitNumber}"** — `text-[12px] text-muted-foreground truncate`.
  - Botón a la derecha (línea 95-109): **"Descargar PDF"**
    - `flex gap-2 px-3.5 py-2.5 rounded-xl bg-primary text-primary-foreground text-xs
      font-semibold shadow-sm` → fondo #239F6D, texto blanco 12px w600, radio 16px,
      padding 14/10px, sombra `0 1px 2px rgba(0,0,0,.05)`.
    - Icono Download 14px (`w-3.5`). Hover `bg-primary/90`; active `scale-[0.97]`;
      disabled `opacity-60`.
    - Estado generando: spinner Loader2 14px girando + texto **"Generando…"**.
    - En <640px el label es solo **"PDF"** (o "…" generando).
- Comportamiento: POST a edge function `generar-estado-cuenta` con `{ id_cuenta }`;
  al resolver abre `DocViewerPortal` (modal visor de PDF) con título "Estado de Cuenta",
  subtítulo "{proyecto} - U{unidad}" y descarga como `SOZU-EstadoCuenta-{titulo}.pdf`.
  Escape cierra el modal.

---

## C. Layout de AccountStatementView

- **Desktop (≥768px)** (líneas 633-642): grid de 2 columnas
  `md:grid-cols-[minmax(0,1fr)_300px] gap-6 items-start`:
  - **Izquierda (flexible)**, `space-y-4` (16px): card de filtros → card Movimientos (tabla).
  - **Derecha (300px fija)**, `sticky top-20` (pegada a 80px del top), `space-y-4`:
    card resumen → card Instrucciones de Pago.
- **Móvil (<768px)** (líneas 625-630), `space-y-4`: filtros → resumen → movimientos
  (agrupados por mes) → instrucciones.
- Todas las cards: `bg-card` #FFFFFF, `rounded-2xl` **24px**, `border border-border`
  1px #E5E7EB, **sin sombra**.

---

## D. Card de filtros (filterBar, líneas 360-380)

`bg-card rounded-2xl border p-4 space-y-3`. Dos filas (la 2ª con `border-t border-border pt-3`):

| Fila | Label (izq.) | Pills (der.) |
|---|---|---|
| 1 | **"Período"** | **"Todos"** + un pill por año disponible (desc., extraídos de las fechas de movimientos) |
| 2 | **"Estatus"** | **"Todos"**, **"Pagados"**, **"Pendientes"** |

- Label: `text-[11px] font-semibold text-muted-foreground uppercase tracking-wider`
  (se renderiza "PERÍODO"/"ESTATUS").
- Pills: `text-[11px] font-medium px-2.5 py-1 rounded-full border`, gap 6px, wrap.
  - **Activo**: `bg-primary text-primary-foreground border-primary` (fondo #239F6D, texto blanco).
  - **Inactivo**: `bg-card text-muted-foreground border-border`; hover `border-primary/30` (#BDE2D3).
- Comportamiento (líneas 258-264): filtro en cliente. Año filtra por substring del año en la
  fecha; "Pagados" = status pagado; **"Pendientes" incluye pendiente Y parcial**.

---

## E. Card "Movimientos" — tabla desktop (líneas 467-561)

`bg-card rounded-2xl border overflow-hidden`.

### Header (469-472)
`flex justify-between px-5 py-3 border-b border-border bg-muted/20`:
- Título **"Movimientos"** — `font-display font-semibold text-sm`.
- Contador **"{n} registros"** (singular "1 registro") — `text-[11px] text-muted-foreground`.

### Tabla (479-554)
- Filas ordenadas por fecha **descendente**. Scroll horizontal si no cabe (`overflow-x-auto`).
- **thead** (481-487): fila `border-b border-border bg-muted/10 text-left`; th
  `text-[11px] font-semibold text-muted-foreground uppercase tracking-wider py-2.5`:

| Columna | Padding | Alineación |
|---|---|---|
| FECHA | px-5 | izquierda, nowrap |
| CONCEPTO | px-3 | izquierda |
| MONTO | px-3 | derecha, nowrap |
| ESTATUS | px-3 | centro |
| COMPROBANTE | px-5 | centro |

- **Filas** (495-537): `border-b border-border` (última sin borde), hover `bg-muted/20`,
  transición de color.
  - **FECHA**: `px-5 py-3 text-[12px] text-muted-foreground` — formato es-MX
    "d MMM yyyy" (p.ej. "15 jul 2026") vía `toLocaleDateString("es-MX", {day:"numeric",
    month:"short", year:"numeric"})`.
  - **CONCEPTO**: `px-3 py-3 text-[13px] font-medium text-foreground`. Si el concepto tiene
    **más de 1 pago aplicado**, badge junto al texto: icono Layers 12px + **"{n} pagos"** —
    `text-[10px] font-medium px-1.5 py-0.5 rounded-full bg-primary/10 text-primary` (#E9F5F0/#239F6D).
  - **MONTO** (`MontoCell`, líneas 94-106): alineado a la derecha, `tabular-nums`.
    - Pagado/pendiente: `$X.XX` `font-semibold` 13px (pagado muestra lo aplicado, pendiente el plan).
    - **Parcial** (columna apilada, alineada a la derecha, leading-tight):
      1. Monto aplicado — `text-[13px] font-semibold text-foreground`
      2. **"de $TOTAL"** — `text-[10px] text-muted-foreground`
      3. **"Faltan $X"** — `text-[10px] font-medium text-warning` (#F59E0B)
  - **ESTATUS** (508-515): chip `inline-flex gap-1 text-[11px] font-semibold px-2.5 py-1
    rounded-full` con icono 12px:
    - **"Pagado"**: `bg-success/10 text-success` (#E9F5F0 / #239F6D) + icono CheckCircle2.
    - **"Pendiente"** y **"Parcial"**: `bg-warning/10 text-warning` (#FEF5E7 / #F59E0B) + icono Clock.
  - **COMPROBANTE** (516-536): centro, hasta 3 icon-buttons (`IconBtn`: `p-1.5 rounded-lg`,
    habilitado `text-muted-foreground hover:bg-muted hover:text-primary`, deshabilitado
    `text-muted-foreground/25 cursor-not-allowed`), iconos 16px:
    1. **FileText** — "Ver recibo" (modal de recibo in-app). Deshabilitado si no está pagado
       (tooltip "Pago pendiente").
    2. **Eye** — "Generar recibo PDF": POST a `generar-recibo-pago` con `{pagoId}`; muestra
       Loader2 girando mientras genera; abre visor PDF. Deshabilitado sin pagoId o no pagado.
    3. **Receipt** — abre `cepUrl` (tooltip "CEP electrónico") o `evidenceUrl`
       ("Comprobante de pago") en el visor; deshabilitado si no hay ("Sin comprobante").
    - Si la fila tiene **varios pagos**: en lugar de los 3 botones hay UN toggle
      ChevronDown/ChevronUp ("Ver pagos aplicados").

### Fila expandida de pagos aplicados (538-549)
- `<tr>` extra `bg-muted/10`, celda colSpan=5 `px-5 py-2`:
  - Caption: **"{n} pagos aplicados a {concepto}"** — `text-[10px] uppercase tracking-wider
    text-muted-foreground`.
  - Sub-filas (`AppRow`, 332-356): `py-2 pl-3 border-l-2 border-primary/20` (regla verde al 20%):
    - Línea 1: `{método} · $monto` — `text-[11px] font-medium` (monto tabular).
    - Línea 2: `{fecha} · Clave {trackingKey}` — `text-[10px] text-muted-foreground`.
    - Botones Eye + Receipt (mismos estilos IconBtn).

### Footer de la card (557-559)
**"Estado de cuenta generado automáticamente por SOZU."** —
`text-[10px] text-muted-foreground text-center py-3 border-t border-border`.

### Estado vacío (473-476)
"Sin movimientos con ese filtro" — `p-8 text-center text-sm text-muted-foreground`.

### Móvil (mobileMovementsBlock, 564-620)
Sin tabla: título "Movimientos" + contador fuera de card; grupos por mes en cards
`rounded-xl` con header colapsable (`px-4 py-2.5 bg-muted/30`, label del mes 12px semibold +
"$X pagado" 11px muted + chevron). Primer mes expandido por defecto. Filas `MovementRow`:
icono cuadrado 28px `rounded-lg` (`bg-success/10` CheckCircle2 / `bg-warning/10` Clock 14px),
concepto 12px medium + badge "N pagos", fecha corta 11px, monto a la derecha + label de
estatus 10px (verde/ámbar), mismos 3 icon-buttons o toggle.

---

## F. Card resumen (summaryBlock, líneas 382-431) — columna derecha, 300px

`bg-card rounded-2xl border p-5 space-y-4`. Secciones separadas con `border-t border-border pt-3`.

### 1. Encabezado de marca (384-389)
Fila `gap-2`: logo **SOZU** (img `/sozu-logo.png`, alto 14px = `h-3.5`) + separador "-"
(`text-xs muted`) + **"Estado de Cuenta"** (`text-xs font-semibold`) + chip de estatus a la
derecha (`ml-auto`): `text-[10px] font-semibold px-2 py-0.5 rounded-full`; color según estatus
de la propiedad (línea 276-279): warning → `bg-warning/15 text-warning` (p.ej.
**"Pago Pendiente"**), success → `bg-success/15 text-success`, resto → `bg-primary/15 text-primary`.

### 2. Propiedad / Periodo (390-399)
`text-[11px] text-muted-foreground space-y-1`; filas `justify-between`:
- **"Propiedad"** → `{projectName} - U-{unitNumber}` (`font-semibold text-foreground`)
- **"Periodo"** → mes y año actuales, p.ej. "Julio 2026" (`font-semibold text-foreground`)

### 3. Financieros (400-419), `space-y-2.5`
| Label (`text-xs muted`) | Valor |
|---|---|
| **"Valor del Activo"** | `font-display font-bold text-sm tabular-nums` foreground |
| **"Total Pagado"** | `font-semibold text-sm tabular-nums` **text-primary** (#239F6D, verde) |
| **"Saldo Pendiente"** | `font-semibold text-sm tabular-nums` foreground |

Si hay próxima cuota (primer installment no pagado; 413-419), sub-bloque `pt-2 border-t`:
- **"Próxima Parcialidad"** — `text-[10px] muted`
- Monto — `text-sm font-semibold tabular-nums`
- **"Vence {fecha}"** — `text-[11px] muted`

### 4. Progreso (421-429)
- Fila `text-[11px] mb-1.5`: **"Progreso"** (muted) ↔ **"{n}%"** (`font-semibold tabular-nums`).
- Barra: `h-2 bg-muted rounded-full` (pista #F3F4F6) con relleno `bg-primary rounded-full`
  al `{n}%` (pct = totalPagado/valorActivo, cap 100, redondeado).

---

## G. Card "Instrucciones de Pago" (stpBlock, líneas 433-464)

Solo si hay plan de pagos. `bg-card rounded-2xl border overflow-hidden`.

- **Header con fondo tenue**: `bg-primary/5 (#F4FAF8) border-b border-border px-5 py-3`,
  título **"Instrucciones de Pago"** `font-semibold text-xs`.
- Cuerpo `p-4 space-y-3`; filas `text-[11px] space-y-2.5` con `justify-between gap-4`:
  1. **"Banco Receptor"** (muted) → nombre del banco `font-semibold text-foreground` alineado derecha.
  2. **"CLABE"** (muted) → número `font-mono font-semibold text-xs` + **botón copiar**
     (`p-1 rounded-md hover:bg-muted`, icono Copy 12px `text-primary`). Al pulsar: copia al
     portapapeles y toast **"CLABE copiada al portapapeles"** (líneas 288-293).
  3. **"Referencia"** (muted) → `font-mono font-semibold text-xs`.
- **Nota de seguridad** (458-461): `border-t border-border pt-3`, fila `gap-2` con icono
  **Shield 14px text-primary** + texto
  **"CLABE vinculada exclusivamente a tu propiedad y RFC."** —
  `text-[10px] text-muted-foreground leading-relaxed`.

---

## H. Comportamiento resumido

| Interacción | Efecto |
|---|---|
| Pill de año / estatus | Filtra movimientos en cliente; contador "N registros" se actualiza |
| Chevron en fila multi-pago | Expande/colapsa sub-filas de pagos aplicados (estado por fila) |
| FileText | Modal recibo in-app (PaymentReceiptModal) |
| Eye | Genera recibo PDF (edge fn `generar-recibo-pago`) → visor modal, spinner mientras |
| Receipt | Abre CEP/comprobante en visor modal |
| Copy CLABE | Clipboard + toast éxito |
| "Descargar PDF" | Edge fn `generar-estado-cuenta` → visor modal con descarga |
| Escape | Cierra visor PDF |
| Columna derecha | Sticky a 80px al hacer scroll (desktop) |
| Animación de entrada | `animate-fade-in` (fade 0.4s ease) |
