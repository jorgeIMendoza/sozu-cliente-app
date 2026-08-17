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
screens/     select_client_screen, announcements_screen
components/  admin_header_bar, client_filters, client_row
layouts/     admin_layout.dart         AdminLayout + AdminScrollArea
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

## Deuda conocida

La feature está en **0 legacy** de design system y de hexagonal (auditada con el
grep de `CLAUDE.md`, incluidos los patrones de espaciado y paleta cruda). Lo que
queda es estructural:

- `screens/announcements_screen.dart` son **1,361 líneas con 33 `setState`**. Por
  la regla de `CLAUDE.md` una pantalla solo compone: el formulario de alta de
  aviso y la lista de programados deberían ser dos componentes con estado, y la
  pantalla el ensamblaje. Es el archivo más grande fuera de `client/properties`.
- `screens/select_client_screen.dart` (439 líneas, 4 `setState`) tiene el mismo
  problema en pequeño: los filtros ya salieron a `client_filters.dart`, falta que
  salga el estado de búsqueda.

## Cómo agregar funcionalidad

1. Método nuevo de backend: firma en `AdminPort`, implementación en
   `AdminAdapter`, doble en `test/features/admin/fake_admin_port.dart`.
2. Dato para una pantalla: `FutureProvider` en `admin_providers.dart` que
   lea el puerto; mutaciones imperativas con `ref.read(adminPortProvider)`.
3. Pantalla nueva: envolver en `AdminLayout` (o `.fixed` si tiene
   pestañas), encabezado con `AdminHeaderBar`, ruta `sinMarco: true`.
4. Catálogo con datos raros (p. ej. entradas que no son proyectos): el
   problema es de datos, se corrige en backend; no filtrar por nombre en
   el cliente.
