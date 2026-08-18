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
providers/   admin_providers.dart      adminPortProvider + 3 FutureProviders
             impersonation_provider.dart  contexto "Ver como"
             client_filters_provider.dart filtros del selector, fuera del State
screens/     select_client_screen, announcements_screen
components/  admin_header_bar, client_filters, client_row
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

## Deuda conocida

La feature está en **0 legacy** de design system y de hexagonal (auditada con el
grep de `CLAUDE.md`, incluidos los patrones de espaciado y paleta cruda). Lo que
queda es estructural:

- `screens/announcements_screen.dart` son **~1,350 líneas con 33 `setState`**.
  Por la regla de `CLAUDE.md` una pantalla solo compone: el formulario de alta de
  aviso y la lista de programados deberían ser dos componentes con estado, y la
  pantalla el ensamblaje. Es el archivo más grande fuera de `client/properties`.
  Es lo mismo que ya se hizo en `auth`, a diez veces el tamaño.
- `screens/select_client_screen.dart` son 492 líneas, pero ya con **0
  `setState`**: el estado de los filtros salió a `client_filters_provider` y lo
  único que queda dentro son los `TextEditingController` y el debounce, que son
  del widget de texto. Lo que falta ahí es partir la pantalla en componentes,
  no sacarle estado.

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
