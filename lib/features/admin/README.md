# Feature `admin`

Estado: **migrada al design system** · 2026-07-31 · 6 archivos · auditoría en 0

Área de super administrador: elegir un cliente para ver el portal como él
("Ver como") y enviar avisos. Segunda feature en el patrón nuevo, después de
`auth`.

## Estructura

```
layouts/
  admin_layout.dart          AdminLayout + AdminScrollArea
screens/
  select_client_screen.dart  selector de cliente
  announcements_screen.dart  envío de avisos (2 tabs)
components/
  admin_header_bar.dart      AdminHeaderBar · AdminHeaderAction
  client_filters.dart        Proyecto + Unidad
  client_row.dart            ClientRow - fila de cliente
```

## El scroll: la razón de `AdminScrollArea`

**El scroll envuelve al limitador de ancho, no al revés.** Al revés, la rueda del
ratón solo mueve la columna de contenido y en los laterales la página no
responde; en escritorio ancho eso es la mayor parte de la pantalla.

Por lo mismo las rutas de admin van `sinMarco: true` en el router: el `WebFrame`
volvía a meter el limitador por fuera y pintaba los lados con un `ColoredBox`,
que no tiene nada desplazable.

Consecuencia para las pantallas: **el contenido no puede traer scroll propio**.
Las listas van `shrinkWrap: true` + `NeverScrollableScrollPhysics`, o como
`Column`.

`resizeToAvoidBottomInset: false` también es deliberado: con el resize, en un
teléfono el encabezado y los filtros no caben en lo que queda y el contenido
desborda. Aquí se escribe arriba y los resultados van debajo, así que es correcto
que el teclado los tape; el padding inferior mantiene alcanzable el último.

Tests: `test/features/admin/admin_layout_test.dart` fija las dos cosas (el área
desplazable mide el viewport, y un gesto en el lateral mueve la página).

## Alto de los controles del encabezado

`kAdminHeaderControlHeight` (36) lo comparten los botones de texto y el cuadrado
del selector de tema. Con el alto por defecto de `TextButton` el hover quedaba
visiblemente más bajo que el del icono de al lado.

`AdminHeaderAction.isDanger` pinta "Cerrar sesión" en rojo y usa los roles
`dangerSoft` / `dangerSoftStrong` para el overlay del hover.

## Proyecto se busca escribiendo

`SAutocompleteField`, no un desplegable: el catálogo trae ~20 entradas y varias
no son proyectos inmobiliarios. Sin icono y **sin flecha**: esto no se despliega,
y una flecha promete un menú que un toque no abre.

Los tres campos (Proyecto, Unidad, buscador) son `STextField` por dentro, así que
comparten borde, anillo de foco, alto y la etiqueta ARRIBA.

## Deuda pendiente

| Qué | Dónde | Por qué sigue ahí |
|---|---|---|
| `Icon(size: 16/18/20)` · `strokeWidth: 2.5` | varios | **No existe familia de tokens de tamaño de icono**. El propio design system los cocina (18 en `s_search_field`, 26 en `s_empty_state`, 14 en `s_section_label`) |
| Geometría del lienzo de preview de avisos | `announcements_screen.dart` | `Offset(w - 36, 30)`, `Positioned(right: 20, top: 16)`: coordenadas acopladas entre sí, cambiarlas desalinea el dibujo |
| `_ClientList` con `shrinkWrap: true` | `select_client_screen.dart` | Construye todos los items de golpe. Bien con ~50 resultados de búsqueda, no con cientos |
| Catálogo de proyectos con entradas que no son proyectos | backend | Reusa el catálogo de avisos: trae "Productos", "Mutuo Vive". Solicitud de cambio en `Ejecuciones_manuales/`; NO se filtra por nombre a propósito (una lista negra se desincroniza y esconde el problema, que es de datos) |

## Auditoría de cierre - los 14 patrones en 0

```bash
F=lib/features/admin
for p in "PortalColors" "isPortalMode" "SozuTone" "SozuColors" "SozuType\." \
         "Color(0x" "fontSize:" "circular([0-9]" "EdgeInsets.all([0-9]" \
         "EdgeInsets.symmetric(horizontal: [0-9]" "SizedBox(height: [0-9]" \
         "SizedBox(width: [0-9]" "import '\.\./" "TextStyle("; do
  printf "%-42s %s\n" "$p" \
    "$(grep -rHn "$p" $F --include=*.dart | grep -vE ':[0-9]+: *///' | wc -l)"
done
```

El `-H` es obligatorio: sin el prefijo de archivo la salida es `80:///…` y el
filtro de dartdoc no coincide, así que las citas de código en los comentarios
contaban como sitios reales.

## Lo que cambió de píxel al migrar

Ningún test cubre tamaños ni espaciado, así que esto queda anotado y **sin
verificar visualmente**:

| Sitio | Antes | Ahora |
|---|---|---|
| Gaps de 6 px y 10 px | 6 · 10 | 8 (`xs`) · 12 (`sm`) - se redondea hacia arriba |
| Gap título/subtítulo del encabezado y de la fila de cliente | 2 | 4 (`xxs`) - no hay token de 2 |
| Pastilla "Viendo" | `vertical: 3` | 4 (+2 px de alto) |
| Etiquetas en mayúsculas (CANALES · DESTINATARIOS · PROGRAMACIÓN) | `letterSpacing: 1` | `overline` (0.4) - menos espaciadas |
| Ripple del multiselect | `circular(12)` | `mdBorder` (8) - ahora coincide con el borde real del campo |
| `contentPadding` del diálogo del selector | `fromLTRB(20,12,20,0)` | `lg, sm, lg, 0` (+4 horizontal en escritorio) |

El gap del skeleton era 6 y el de la fila real 2: **la lista brincaba 4 px al
cargar**. Ahora los dos usan `xxs`.
