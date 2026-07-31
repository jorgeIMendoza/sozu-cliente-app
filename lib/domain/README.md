# lib/domain/ - puertos

Capa de contratos de la arquitectura hexagonal. Aqui vive **lo que la app
necesita del exterior**, nunca **como se consigue**.

Un **puerto** es una `abstract interface class` que declara operaciones, tipos de
retorno y errores. El **adaptador** (fuera de esta carpeta) la implementa contra
Supabase. La UI y los providers dependen del puerto; cambiar de backend, o
escribir un doble de prueba, es cambiar de implementacion sin tocar pantallas.

`abstract interface class` y no `abstract class`: es un contrato para
implementar, no una base para heredar.

## Regla: CERO dependencias

`lib/domain/` solo puede importar `lib/data/models.dart` y sus propios archivos.
Prohibido `supabase_flutter`, `flutter_riverpod` y `package:flutter/*`.

```bash
grep -rn "supabase_flutter\|flutter_riverpod\|package:flutter/" lib/domain/
```

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

Un super admin puede ver el portal como un cliente. Hoy eso es un parametro
`impersonate` en 27 de las 43 funciones de `data/api_client.dart`, y **cada sitio
de llamada repite la misma linea**
(`impersonate: ref.read(impersonationProvider).idPersona`). Olvidarla no rompe
nada visible: el admin ve datos vacios, o peor, escribe sobre su propio registro.

Decision: **los puertos no exponen `impersonate`**. La instancia queda atada al
cliente que se esta viendo y el adaptador resuelve la cabecera. Se pasa de ~46
oportunidades de olvidarlo a una, en la construccion del adaptador.

Esto convierte la impersonacion en una propiedad del **tipo** de puerto:

| Puerto | Impersona |
|---|---|
| `ClientPortalPort`, `ProfilePort` | si: el target es el cliente que se ve |
| `AdminPort` | no: actua como el administrador |
| `PushPort` | no: el token es del dispositivo logueado |
| `AppVersionPort` | no: pre-login, llave anonima |
| `AuthPort` | no: la sesion es la del usuario real |

Coste: el provider que expone `ClientPortalPort`/`ProfilePort` debe observar la
impersonacion, de modo que cambiar de cliente reconstruya el puerto e invalide
los providers que dependan de el.

## Puerto -> Edge Function

| Puerto | Edge Functions / RPC |
|---|---|
| `ClientPortalPort` | `cliente-resumen`, `cliente-menu`, `cliente-pagos`, `cliente-propiedades`, `cliente-propiedad-detalle`, `cliente-productos`, `cliente-documentos`, `cliente-expediente`, `cliente-notificaciones`, `cliente-estado-cuenta`, `cliente-estado-cuenta-pdf`, `cliente-datos-pago`, `cliente-recibo-pago`, `cliente-pago-final` |
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

1. **`ApiError` y `DocumentoInvalidoError` estan duplicados.** Los originales
   siguen en `lib/data/api_client.dart` porque borrarlos rompe todo lo que los
   importa. El adaptador debe usar los de `domain/api_error.dart` y, cuando ya
   nadie importe `api_client.dart`, los de alli se **borran** (no se dejan como
   alias: eso es como nacio la paleta bifurcada). `isNotClientError` NO se
   duplico: tiene 0 usos en el repo, es codigo muerto y se borra con el resto.
2. **`UserProfile` esta duplicado.** El original vive en
   `lib/providers/auth_provider.dart` con los mismos campos y el mismo nombre a
   proposito: cuando el adaptador aterrice, la migracion es cambiar el import y
   borrar la clase del provider. Importar los dos archivos a la vez da error de
   colision, y eso es intencional.
3. **`WrongCurrentPasswordError` desaparece.** Lo cubre
   `AuthPort.verifyPassword`, que lanza `AuthError(AuthFailure.invalidCredentials)`.
   Con eso `AuthController.mensajeErrorAcceso` puede irse a la UI.
4. **`PortalTracking` no tiene puerto.** `lib/core/portal_tracking.dart` llama
   tres RPC (`register_portal_session`, `touch_portal_session`,
   `close_portal_session`) y no encaja en ninguno de los seis puertos. Necesita
   uno propio (`TrackingPort`) en una tanda posterior.
5. **El canal Realtime no tiene puerto.** `lib/widgets/push_registrar.dart` se
   suscribe a la tabla `notificaciones_cliente` (unico acceso directo a una tabla
   del repo). Alimenta la misma campana que los push, asi que su sitio natural es
   `PushPort` como `Stream`, pero queda fuera de esta tanda.
6. **`cliente-expediente` se queda en `ClientPortalPort`** (decidido, ya no es una
   discrepancia). Lo consumen `expediente_screen` Y `perfil_screen`, asi que
   cualquiera de los dos puertos deja a una pantalla pidiendo el otro. El criterio
   que decide: las dos superficies de documentos van juntas. `documents()` son los
   que la empresa le da al cliente y `identityFile()` los que el cliente sube;
   separarlas obligaria a `expediente_screen` a depender de un puerto entero por un
   solo metodo.
7. **Nada consume todavia estos puertos.** Esta tanda es puramente aditiva.
