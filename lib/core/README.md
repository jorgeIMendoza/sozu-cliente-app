# `lib/core/` - infraestructura transversal

Lo que no es de ninguna feature y no es interfaz. Nada de aqui lleva prefijo de
feature: se nombra por su funcion (regla de nombres en `CLAUDE.md`).

19 archivos suenan a muchos, pero son **9 conceptos**: cuatro de ellos son
tercias `x.dart` + `x_stub.dart` + `x_web.dart`, que es el idioma de Dart para
resolver por plataforma en tiempo de compilacion. El `_stub` es la version no
web y el `_web` usa APIs del navegador; el archivo sin sufijo es la fachada que
elige. **No son duplicacion**: sin el par, `package:web` rompe el build del APK.

## Configuracion

| | |
|---|---|
| `backend_env.dart` | A que backend habla la app. `--dart-define` gana sobre `assets/env`, que es lo que hace funcionar `BACKEND=dev ./tool/dev.sh`. Nombra `SUPABASE_URL` porque es el nombre de la variable de entorno, un contrato con el `.env` y el CI |
| `version.dart` | La version del footer, y las dos banderas de compilacion: `isPreviewBuild` (enciende el cintillo Y los logs) y `hidePreviewBanner` (apaga solo el cintillo) |

## Formato

| | |
|---|---|
| `format.dart` | MXN a 2 decimales, fechas DD/MM/YYYY, compacto `$2.46M`. El archivo mas consumido de `core/`: 22 importadores |

## Archivos y media

| | |
|---|---|
| `open_document.dart` | Abrir una URL fuera de la app: navegador in-app en movil, pestana nueva en web. Envuelve `url_launcher` |
| `media_cache.dart` | Cache en disco a 7 dias, y el `ImageProvider` que la reusa. La clave es estable porque las URLs firmadas caducan y llegan distintas cada vez |
| `file_download.dart` + `_stub` + `_web` | Descargar con nombre propio. En web via blob; fuera de web se abre en el visor |
| `file_drop.dart` + `_stub` + `_web` | Arrastrar y soltar. Fuera del navegador devuelve null y la zona de carga sigue funcionando a golpe de boton |

## Plataforma

| | |
|---|---|
| `secure_session_storage.dart` | Tokens en secure storage. Implementa la interfaz de almacenamiento del propio SDK, asi que el acoplamiento con el vendor es su razon de existir, no una fuga |
| `push_service.dart` | FCM, solo movil. En web la campana es in-app. Recibe su `PushPort` por parametro: es estatico y no tiene `ref` |
| `url_strategy.dart` + `_stub` + `_web` | Quita el `#` de las URLs en web (`/login`, no `/#/login`) |
| `browser_ua_stub.dart` + `_web` | El user agent del navegador. Lo consume solo `portal_tracking` |
| `portal_tracking.dart` | Mediciones "Uso por portal" de Alta Direccion. **Viva en produccion**, no es codigo muerto. Recibe su `TrackingPort` por parametro, igual que `push_service` |

## Legacy: uno solo, y tiene fecha

| | |
|---|---|
| `portal_theme.dart` | Shim de `PortalColors` / `isPortalMode`. Muere con la migracion de `client`; hoy son 35 importadores y ~600 usos |

WARN: **`portal_theme` y `portal_tracking` se leen como hermanos y son
opuestos.** Uno es un shim deprecado esperando su borrado; el otro es telemetria
viva. Es la trampa que `CLAUDE.md` ya documenta: "Portal" significa el PRODUCTO
(`PortalAccess`, `PortalTracking`, correctos) o el MODO legacy de web ancha
(`isPortalMode`, `PortalColors`, `portal_theme`, deuda). Al borrar el shim la
ambiguedad desaparece sola; hasta entonces, el parecido es de nombre y nada mas.

## Lo que se fue de aqui, y por que

| Salio | A donde | Por que |
|---|---|---|
| `open_media.dart` | `shared/components/` | Importaba una PANTALLA de client: inversion de capas. Y sus 9 consumidores estaban todos en `client`, asi que no era transversal |
| `user_agent/` | `browser_ua_*` aqui mismo | "Agente" es un ROL de negocio en este sistema; el nombre se leia como algo de ese rol |
| el `SupabaseClient` de `portal_tracking` | `shared/adapters/` | Era el unico vendor fuera de un adaptador |

`widgets/network_image.dart` tambien se partio: su `ImageProvider` vino a
`media_cache` y su widget se fue a `ui/` como `SNetworkImage`.

## Lo unico que sigue mirando hacia arriba

`push_service` y `portal_tracking` importan `shared/ports/`. Es a proposito y no
es la inversion que se acaba de cerrar: importan un CONTRATO, que no conoce
flutter ni riverpod ni el vendor, y reciben su implementacion por parametro.
Eso es inversion de dependencias funcionando, no una fuga.

Queda la duda de si los dos deberian vivir en `shared/services/` en vez de aqui,
para que `core/` no dependa de nada. Cuesta 7 lineas de import. **Sin decidir**:
los dos son envoltorios de plataforma (FCM, device_info) y ese es el argumento
para dejarlos.

`portal_theme` importa `ui/`, pero es el shim legacy y cae con `client`.

## Por que sigue plano

Agrupar las cuatro tercias en subcarpetas dejaria 10 entradas en vez de 21, pero
cuesta ~90 lineas de import en ~60 archivos. No se hace ahora porque el diff
taparia el trabajo de `client`, que es donde esta el 90% de la deuda. Queda como
opcion, no como pendiente: el idioma `_stub` / `_web` plano es el estandar de
Dart y se lee bien una vez que sabes que las tercias son un concepto.
