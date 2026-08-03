# SOZU · Portal del Cliente

App Flutter multiplataforma (web, Android, iOS) donde el cliente de SOZU
consulta sus propiedades, pagos, estado de cuenta, documentos y perfil. Un
super administrador puede entrar en modo "Ver como" para navegar el portal con
los datos de un cliente.

Backend: Edge Functions de Supabase. Este repo es **solo frontend**.

## Reglas del proyecto

Seguridad, no negociable:

- Solo ANON KEY publica y el JWT del usuario. Nunca `service_role` ni
  credenciales de base de datos en el codigo.
- Cero queries a tablas. Todo dato sensible viaja por Edge Function.
- No se registra PII en logs (RFC, CURP, CLABE, montos).
- Sesion y tokens en `flutter_secure_storage`, nunca en SharedPreferences.

Codigo:

- Identificadores en ingles. En espanol solo los textos que ve el usuario y las
  claves del JSON del backend (esas las traduce el adaptador).
- El backend se consume por puertos. Ninguna pantalla importa el SDK.
- Estilos por token (`context.s`). Prohibidos `Color(0x...)`, `fontSize: 14`,
  `circular(16)` y `EdgeInsets.all(14)` en pantallas.
- Imports siempre `package:sozu_cliente_app/...`.
- dartdoc conciso: 1-3 lineas por miembro.
- Prohibido el guion largo. Solo `-`; como separador visible, `·`.

Proceso:

- Rama de trabajo: `dev-eddy`. De ahi salen los PR hacia `dev`.
- SQL y deploys de Edge Functions no se ejecutan desde aqui: se entrega un `.md`
  en `Ejecuciones_manuales/` y se aplica por el canal autorizado.

## Arquitectura

Puertos y adaptadores (hexagonal) sobre features por actor:

```text
lib/
  shared/          contrato y utilidades transversales
                   api_error.dart · ports/ · adapters/ · providers/
  features/
    auth/          acceso, biometria, cambio de contrasena
    admin/         selector de cliente ("Ver como") y avisos
    client/        el portal, por area de menu
                   home/ properties/ products/ documents/ profile/
                   layouts/  el shell de 5 tabs
  data/models.dart DTOs del backend (sin dependencias)
  ui/              design system: tokens, tema y 16 primitivas
  core/            formato, storage, descargas, version
  router.dart      rutas y guards de sesion
```

Cada feature (u hoja de `client`) tiene la misma forma:

| Carpeta | Que va ahi |
| --- | --- |
| `ports/` | el contrato: `abstract interface class` |
| `adapters/` | la implementacion; el unico sitio que sabe del backend |
| `providers/` | estado y datos para la UI |
| `screens/` | pantallas: solo composicion, sin logica |
| `components/` | piezas reutilizables (2+ pantallas) |
| `layouts/` | estructura: decide tema, scroll y breakpoints |
| `services/` | logica sin UI, solo si la feature la tiene |

Un puerto solo importa `models.dart` y `api_error.dart`: ni Flutter, ni Riverpod,
ni el SDK del backend. Es verificable con grep y el CI lo respeta.

Por que asi: el nombre de una clase no menciona al proveedor (`AuthAdapter`, no
`SupabaseAuthAdapter`), asi que cambiar de backend es reescribir los adaptadores
sin tocar pantallas ni tests. Y los tests usan dobles de los puertos, sin red.

Detalle en `docs/adr/` y en el README de cada feature.

## Correr la app

```bash
./tool/dev.sh                # web en http://localhost:5000 (hot reload)
./tool/dev.sh <device-id>    # telefono por cable (hot reload)
./tool/web.sh                # web en RELEASE, para medir rendimiento
./tool/apk.sh                # APK release, se copia a Descargas de Windows
./tool/check.sh              # formato + analyze + tests
```

Requiere `assets/env` (gitignored): copiar de `.env.example` y llenar
`SUPABASE_URL` y `SUPABASE_ANON_KEY`.

**Para juzgar rendimiento nunca se usa `dev.sh`**: corre en debug, que en web
compila sin optimizar y es varias veces mas lento que produccion. Medir con
`./tool/web.sh`, `PROFILE=1 ./tool/dev.sh` o un APK release.

Flujo diario, USB y diagnostico: `tool/README.md`.

## Estado

- 3 features migradas a la arquitectura: `auth`, `admin`, `client`.
- 324 tests. CI corre `flutter analyze` y `flutter test` antes de compilar, en
  los 8 pipelines.
- Deuda conocida: `PortalColors` e `isPortalMode` (el tema legacy y el
  interruptor movil/web) siguen en las pantallas del cliente. Es la siguiente
  tanda y esta anotada en `docs/adr/ESTADO.md`.

## Documentacion

| Archivo | Para que |
| --- | --- |
| `CLAUDE.md` | reglas operativas y convenciones, en detalle |
| `docs/adr/0001-arquitectura-modular.md` | por que features y design system |
| `docs/adr/0002-puertos-y-adaptadores.md` | por que hexagonal + inventario |
| `docs/adr/ESTADO.md` | que falta y en que orden |
| `lib/features/*/README.md` | reglas y funcionamiento de cada feature |
| `tool/README.md` | correr la app en web y en fisico |
