# Puertos - lib/shared/ + features/<f>/ports/

Capa de contratos de la arquitectura hexagonal. Aqui vive **lo que la app
necesita del exterior**, nunca **como se consigue**.

Cada puerto vive en la hoja de la feature que lo consume:

- `lib/shared/api_error.dart` - errores comunes a todos los puertos.
- `lib/shared/ports/` - puertos transversales (`PushPort`, `AppVersionPort`), con
  sus implementaciones en `lib/shared/adapters/` y sus providers (mas el
  `authUserIdProvider` de la sesion) en `lib/shared/providers/`.
- `lib/features/<f>/ports/` - el puerto de cada feature (`auth`, `admin`).
- `lib/features/client/<area>/ports/` - la feature `client` se organiza por
  menu: `home`, `properties`, `products`, `documents`, `profile`.

Un **puerto** es una `abstract interface class` que declara operaciones, tipos de
retorno y errores. El **adaptador** (fuera de esta carpeta) la implementa contra
Supabase. La UI y los providers dependen del puerto; cambiar de backend, o
escribir un doble de prueba, es cambiar de implementacion sin tocar pantallas.

`abstract interface class` y no `abstract class`: es un contrato para
implementar, no una base para heredar.

## Regla: CERO dependencias

Los puertos solo pueden importar `lib/data/models.dart` y
`lib/shared/api_error.dart`. Prohibido `supabase_flutter`, `flutter_riverpod` y
`package:flutter/*`.

```bash
grep -rn "supabase_flutter\|flutter_riverpod\|package:flutter/" \
     lib/shared/ports/ lib/features/*/ports/ lib/features/client/*/ports/
```

Solo `ports/`: `lib/shared/adapters/` importa el SDK del backend a proposito y
`lib/shared/providers/` importa riverpod, que es justo su trabajo.

Debe salir vacio. Si un metodo parece necesitar Flutter, esta mal definido: lo
que necesita son datos por parametro (bytes, base64, String), no un
`BuildContext` ni un `XFile`.

## Los modelos NO se duplican

`lib/data/models.dart` tiene **cero imports**: los DTOs de las Edge Functions ya
son Dart puro, o sea que ya son agnosticos del backend. Los puertos los usan tal
cual. No hay entidades de dominio paralelas ni mappers: duplicar 1,639 lineas
para renombrar campos seria la capa de coladera que el proyecto prohibe.

Los tipos conservan su nombre actual (`ClienteResumen`, `PropiedadDetalle`, ...);
los **metodos** de los puertos van en ingles y sin `fetch`/`get` cuando el
sustantivo ya lo dice: `summary()`, no `fetchClienteResumen()`.

## Impersonacion: la lleva el puerto, no el metodo

Un super admin puede ver el portal como un cliente. Antes eso era un parametro
`impersonate` en 27 de las 43 funciones de la vieja capa de acceso a datos, y
**cada sitio de llamada repetia la misma linea**
(`impersonate: ref.read(impersonationProvider).idPersona`). Olvidarla no rompe
nada visible: el admin ve datos vacios, o peor, escribe sobre su propio registro.

Decision: **los puertos no exponen `impersonate`**. La instancia queda atada al
cliente que se esta viendo y el adaptador resuelve la cabecera. Se pasa de ~46
oportunidades de olvidarlo a una, en la construccion del adaptador.

Esto convierte la impersonacion en una propiedad del **tipo** de puerto:

| Puerto | Impersona |
|---|---|
| `HomePort`, `PropertiesPort`, `ProductsPort`, `DocumentsPort`, `ProfilePort` | si: el target es el cliente que se ve |
| `AdminPort` | no: actua como el administrador |
| `PushPort` | no: el token es del dispositivo logueado |
| `AppVersionPort` | no: pre-login, llave anonima |
| `AuthPort` | no: la sesion es la del usuario real |

Coste: los providers que exponen los puertos de `client` deben observar la
impersonacion, de modo que cambiar de cliente reconstruya el puerto e invalide
los providers que dependan de el.

## Puerto -> Edge Function

| Puerto | Edge Functions / RPC |
|---|---|
| `HomePort` | `cliente-resumen`, `cliente-menu`, `cliente-notificaciones` |
| `PropertiesPort` | `cliente-propiedades`, `cliente-propiedad-detalle`, `cliente-pagos`, `cliente-estado-cuenta`, `cliente-estado-cuenta-pdf`, `cliente-datos-pago`, `cliente-recibo-pago`, `cliente-pago-final` |
| `ProductsPort` | `cliente-productos` |
| `DocumentsPort` | `cliente-documentos`, `cliente-expediente` |
| `ProfilePort` | `cliente-perfil` (acciones `catalogos`, `update_personal`, `update_fiscal`, `cuenta_add`, `cuenta_update`, `banco_add`, `avatar_upload`, `avatar_delete`) |
| `AdminPort` | `admin-clientes`, `admin-avisos-app` |
| `PushPort` | `cliente-push-token` |
| `AppVersionPort` | `cliente-app-version` |
| `AuthPort` | Auth de Supabase + RPC `get_current_user_profile`, `mark_password_changed` |

## Errores: parte del contrato

Cada puerto documenta que lanza. Un puerto que no declara sus fallos no sirve
para escribir un doble de prueba.

- `ApiError(status, code)`: cualquier fallo de backend. `status == 0` es red
  caida.
- `DocumentoInvalidoError(reason)`: solo `uploadIdentityDocument`. `reason` viene
  en espanol y se muestra tal cual.
- `AuthError(AuthFailure)`: solo `AuthPort`. El adaptador traduce las excepciones
  de Supabase a un enum cerrado; sin esto la UI tendria que importar
  `supabase_flutter` para decidir que mensaje mostrar.

`AuthFailure` separa a proposito **`network` de `sessionRevoked`**: el candado
biometrico decide con eso si el refresh token guardado se conserva (sin red, el
token sigue vivo, se reintenta) o se borra (revocado). Si los dos llegaran como
un mismo error, `BiometricService` borraria un token sano en cada corte de red y
dejaria al usuario fuera.

## Deuda abierta (para el agente de adaptadores)

1. **`WrongCurrentPasswordError` desaparece.** Lo cubre
   `AuthPort.verifyPassword`, que lanza `AuthError(AuthFailure.invalidCredentials)`.
   Con eso `AuthController.mensajeErrorAcceso` puede irse a la UI.
2. **`PortalTracking` no tiene puerto.** `lib/core/portal_tracking.dart` llama
   tres RPC (`register_portal_session`, `touch_portal_session`,
   `close_portal_session`) y no encaja en ninguno de los seis puertos. Necesita
   uno propio (`TrackingPort`) en una tanda posterior.
3. **El canal Realtime no tiene puerto.** `lib/widgets/push_registrar.dart` se
   suscribe a la tabla `notificaciones_cliente` (unico acceso directo a una tabla
   del repo). Alimenta la misma campana que los push, asi que su sitio natural es
   `PushPort` como `Stream`, pero queda fuera de esta tanda.
4. **`cliente-expediente` se queda en `DocumentsPort`** (decidido, ya no es una
   discrepancia). Lo consumen `expediente_screen` Y `perfil_screen`, asi que
   cualquiera de los dos puertos deja a una pantalla pidiendo el otro. El criterio
   que decide: las dos superficies de documentos van juntas. `documents()` son los
   que la empresa le da al cliente y `identityFile()` los que el cliente sube;
   separarlas obligaria a `expediente_screen` a depender de un puerto entero por un
   solo metodo.
