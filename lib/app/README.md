# `lib/app/` - el shell de la aplicacion

Los widgets con los que `main.dart` envuelve TODO el arbol, en este orden:

```
LightThemeLock > VersionGate > PushRegistrar > PreviewBanner > (router)
```

| | |
|---|---|
| `light_theme_lock.dart` | Fuerza el tema claro mientras el usuario no ha entrado |
| `version_gate.dart` | Aviso de version nueva: suave posponible, o bloqueo total |
| `push_registrar.dart` | Registro de push, aviso en vivo de la campana y la sesion de medicion |
| `preview_banner.dart` | La franja de PREVIEW en los builds que no son de tienda |

## Por que no viven en `shared/`

**Porque dependen de features, y eso aqui es correcto.** Este es el punto de
composicion: su trabajo es cablear features entre si, asi que mira hacia arriba
por definicion.

`shared/` es lo contrario: una capa POR DEBAJO de las features, que ellas
consumen. Si el shell viviera ahi, `shared/` importaria `features/auth`,
`features/client/home` y `features/app_download`, y la regla de que `shared/` no
conoce features dejaria de poder aplicarse. Estaban en `lib/widgets/` (legacy) y
en `shared/components/` justamente por no tener este sitio.

Tampoco van en `ui/`: leen providers, y `ui/` no importa riverpod.

WARN: queda UNA excepcion viva a esa regla: `shared/providers/shared_providers.dart`
importa `features/auth` para derivar `authUserIdProvider`, que consumen los seis
providers de `client`. La sesion es estado global de la app que hoy vive dentro
de una feature; moverla son 31 archivos y no se ha hecho.
