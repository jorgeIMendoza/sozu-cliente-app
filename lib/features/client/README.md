# Feature `client`

El portal del cliente: inicio, propiedades, productos, pagos, estado de cuenta,
facturas, mantenimientos, notificaciones, expediente y perfil.

Es la feature con MAS deuda del repo y la unica sin cerrar. `auth` y `admin` ya
estan al dia y sirven de plantilla.

## Lo unico que ya esta homologado: el shell

`layouts/client_shell.dart` es el UNICO chrome de navegacion, y decide por
**ancho disponible** (`context.bp.hasSidebar`), nunca por `kIsWeb`.

```text
layouts/client_shell.dart          ClientShell + ImpersonationBanner + sidebar
layouts/client_bottom_nav.dart     ClientBottomNav (barra inferior)
layouts/client_top_bar.dart        ClientTopBar
layouts/client_shell_widgets.dart  avatar, buscador y menu de la barra superior
```

Habia TRES (`PortalShell`, `_SideNav`, bottom nav) elegidos en tres sitios y con
dos criterios que no coincidian: `isPortalMode` miraba plataforma Y ancho,
`isDesktop` solo ancho. Una tablet Android ancha recibia el layout de telefono.

El menu es fuente unica (`_portalNavItems` en `client_shell.dart`), lo consumen
la barra lateral y la inferior, y `test/features/client/menu_test.dart` fija que
ningun destino apunte a una ruta que el router no registra.

## Lo que falta, en orden

1. **El color del shell**: 26 `PortalColors` y un `Theme(sozuLightTheme())`. Al
   caer, todo el marco responde al tema. Es el siguiente paso.
2. Los otros tres `Theme(sozuLightTheme())` de deuda: `pagar_screen`,
   `pago_final_screen`, `credito_hipotecario_drawer`.
3. Las pantallas, por seccion de menu, de menor a mayor. `properties` al final:
   sola concentra el 55% de la deuda.
4. **17 pantallas montan su propio `Scaffold`** y 14 su propio `AppBar`. Falta
   un `ClientLayout` -titulo, acciones, scroll y pull-to-refresh- con el mismo
   contrato que `AdminLayout`, que ya esta probado.

## Menu acordado (pendiente de implementar)

Hoy son 9 destinos y el shell solo tiene 4 ramas, asi que 5 de ellos salen del
`IndexedStack` y pierden el estado de la pestana. Lo decidido es agrupar a 4:

```text
Inicio
Propiedades   detalle · mantenimientos · como llegar · productos
Finanzas      pagos · estado de cuenta · facturas
Perfil        expediente/documentos · datos fiscales
```

Notificaciones NO es destino de menu: es la campana de la barra superior. Mismo
criterio que "Mis documentos", que ya se quito por vivir en dos sitios.

## Reglas

Las de `CLAUDE.md`, sin excepciones propias. Las tres que mas se incumplen aqui:

- Nada de `PortalColors` ni `SozuBrand` en pantallas: `context.s.color`.
- Nada de `SizedBox(height: N)` ni `EdgeInsets` con numero: `context.s.space`.
- Una pantalla ensambla; el estado vive en un componente o en un provider.
