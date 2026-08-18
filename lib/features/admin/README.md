# Feature `admin`

Área de super administrador: elegir un cliente para ver el portal como él
("Ver como") y enviar avisos por push, correo y WhatsApp. Dos pantallas,
fuera del shell del portal.

## Reglas

Qué sí:

- El backend se consume SOLO vía `AdminPort` a través de los providers de
  la feature. Las pantallas no conocen el adaptador.
- La autorización real la da el backend (`administrar_app_clientes`); la
  UI solo pinta y enruta.
- `impersonation_provider` es API pública de la feature: la capa de datos
  del cliente lo observa para el contexto "Ver como".
- Scroll de página completa: el contenido no trae scroll propio (listas
  con `shrinkWrap` o `Column`; ver `AdminLayout`).
- dartdoc conciso: 1-3 líneas por miembro.

Qué no:

- Nada de `supabase_flutter` fuera de `adapters/admin_adapter.dart`.
- Nada de vendor en nombres: `AdminAdapter`, no `SupabaseAdminAdapter`.
- Sin llamadas sueltas a edge functions: todo pasa por `AdminPort`.
- Los DTOs (`AdminCliente`, `AvisoApp`...) no se mueven aquí: viven en
  `data/models.dart`, el contrato compartido con cero imports.
- Biometría no aplica al admin: entra siempre con correo y contraseña
  (regla implementada en `features/auth`).

## Estructura

```text
ports/       admin_port.dart           contrato (12 métodos)
adapters/    admin_adapter.dart        implementación actual (único con supabase_flutter)
providers/   admin_providers.dart      adminPortProvider + 5 FutureProviders
             impersonation_provider.dart  contexto "Ver como"
             client_filters_provider.dart filtros del selector, fuera del State
screens/     select_client_screen, announcements_screen
components/  admin_header_bar · client_filters · client_row
             announcement_form · recent_announcements
             bell_animation_settings · catalog_select_fields
layouts/     admin_layout.dart         AdminLayout + AdminScrollArea (sin variantes)
```

## Funcionamiento

- Selector: busca por nombre/correo o filtra por proyecto y unidad; al
  elegir, `impersonation_provider` fija el `clientId` y los providers del
  cliente recargan con ese contexto. El target se limpia al cambiar de
  usuario o cerrar sesión.
- Avisos: crear (inmediato o calendarizado, con destino por proyecto,
  modelo, nivel o propiedad), listar y cancelar programados; más la
  animación de la campana del cliente.
- `AdminScrollArea`: el scroll envuelve al limitador de ancho, nunca al
  revés (la rueda debe funcionar en los laterales). Las rutas de admin van
  `sinMarco: true` en el router por lo mismo.

## Un solo layout, un solo scroll

`AdminLayout` **no tiene variantes**, y las dos pantallas lo montan igual. Tuvo
una, `AdminLayout.fixed`, sin scroll de página, porque `announcements_screen`
usaba `TabBarView` y un `TabBarView` no tiene alto intrínseco: no cabe dentro de
un scroll. El precio era que las dos pantallas se desplazaban distinto y que en
avisos la rueda del ratón solo respondía sobre la columna central.

Hoy las pestañas son `STabs` (`ui/primitives/s_tabs.dart`), que pinta solo la
fila de etiquetas; el cuerpo se elige en línea con un `int _tab`. Así avisos
cabe en el `AdminLayout` normal y `.fixed` se borró.

**Regla:** el contenido de una pantalla de admin NO trae scroll propio. Listas
con `shrinkWrap: true` y sin physics, o mejor como `Column`. Lo fija
`test/features/admin/admin_screens_homologadas_test.dart`, que exige un único
scroll de página del ancho del viewport en las dos.

## Estado que NO vive en la pantalla

`client_filters_provider` guarda proyecto, unidad y busqueda del selector. Es el
equivalente de un store de Zustand: el estado vive en el provider, asi que
sobrevive a salir del selector y volver. Eran campos de
`_SelectClientScreenState` y se perdian al ir a avisos o al entrar como un
cliente y regresar.

En memoria a proposito, sin `shared_preferences`: es contexto de trabajo de la
sesion, no una preferencia. Al cerrar sesion se limpia, porque si no el
siguiente admin en la misma maquina hereda el proyecto y la unidad del anterior.

Los `TextEditingController` SI son locales -son del widget de texto- y se
siembran en `initState` con lo que el store recuerda.

Por eso se quito **"Volver al portal"** del encabezado: existia para no perder
el trabajo al salir del selector, y ahora los filtros ya no se pierden. Volver
al portal es elegir un cliente, que es la accion propia de esta pantalla.

Las acciones del encabezado van a la DERECHA en las dos anchuras. En telefono
colgaban a la izquierda y parecian parte del subtitulo; el `Align` de
`AdminHeaderBar` no es decorativo: sin el, el `Wrap` se encoge al ancho de su
contenido y `WrapAlignment.end` no tiene contra que empujar.

## Aire en escritorio

`announcements_screen` va a `maxWidth: 1240` y **no** a los 880 del selector.
No es una discrepancia: alli el contenido es UNA columna (buscador y lista) y
estirarla solo alarga las lineas; aqui son DOS, formulario y avisos recientes en
`Row` con flex 3:2. Con 880 cada una quedaba en ~430 px y los campos internos se
apilaban igual que en telefono. **La homologacion es de layout y de scroll, no
de pixeles.** En movil las dos columnas se apilan.

"Avisos recientes" va paginado de 5 en 5 (`_kAnnouncementsPerPage`). Con la
lista entera el alto de la pagina dependia de cuantos avisos hubiera; paginando
es constante. Al recargar vuelve a la pagina 1: un aviso nuevo entra al
principio y quedarse en la pagina 3 lo escondia justo cuando se quiere ver
confirmado.

## Las pantallas solo componen

Igual que en `auth`. `announcements_screen` eran **1,472 líneas con 35
`setState`**; hoy son **115** y el único `setState` que queda es el índice de
pestaña, que es composición -qué se pinta- y no lógica.

| Componente | Qué carga |
|---|---|
| `announcement_form` | contenido, canales, destino en cascada y programación |
| `recent_announcements` | lista paginada y cancelar programados |
| `bell_animation_settings` | animación de la campana, con vista previa |
| `catalog_select_fields` | `SelectField` y `MultiSelectField`, usados por el alta |

**Lo que hizo posible el corte fueron dos providers nuevos**, no mover código:
`adminAnnouncementsProvider` y `adminBellAnimationProvider`. El formulario y la
lista de recientes se hablaban por estar en el mismo `State` (`_submit` llamaba
a `_loadAnnouncements`). Ahora el formulario hace `ref.invalidate` al enviar y
la lista se entera sola: ninguno de los dos conoce al otro.

WARN: La lista NO se pide desde `initState`. `RecentAnnouncements` observa el
provider y se resuelve solo; además `ref.read` antes de que `initState` termine
revienta con "dependOnInheritedWidgetOfExactType called before initState
completed".

## Deuda conocida

## Cómo agregar funcionalidad

1. Método nuevo de backend: firma en `AdminPort`, implementación en
   `AdminAdapter`, doble en `test/features/admin/fake_admin_port.dart`.
2. Dato para una pantalla: `FutureProvider` en `admin_providers.dart` que
   lea el puerto; mutaciones imperativas con `ref.read(adminPortProvider)`.
3. Pantalla nueva: envolver en `AdminLayout` -no hay otra variante-, encabezado
   con `AdminHeaderBar`, ruta `sinMarco: true`. Si lleva pestañas, `STabs` y el
   cuerpo en línea; nunca `TabBarView`.
4. Catálogo con datos raros (p. ej. entradas que no son proyectos): el
   problema es de datos, se corrige en backend; no filtrar por nombre en
   el cliente.
