# Probar en el teléfono por cable, desde WSL

WSL2 **no pasa el USB**: `adb` dentro de WSL no ve el teléfono aunque esté
conectado. Hay dos caminos y el segundo es el que da hot reload.

---

## Camino A: solo instalar el APK (sin hot reload)

```bash
./tool/apk.sh --debug
```

Deja el APK en `C:\Users\T14 G1 I7\Downloads\sozu-apk\`. Desde ahí:

- Cópialo al teléfono por cable y ábrelo (hay que permitir "instalar apps
  desconocidas"), o
- Instálalo con el `adb` de Windows: `adb install -r app-arm64-v8a-debug.apk`

Sirve para ver la app. No sirve para iterar: cada cambio exige recompilar e
instalar de nuevo.

---

## Camino B: hot reload en el teléfono - depuración INALÁMBRICA

Es el único que da hot reload desde WSL, y no necesita cable ni el servidor de
adb en Windows.

### Por qué no sirve el puente por USB

Se puede hacer que el servidor de adb corra en Windows y el cliente en WSL
(`adb -a -P 5037 nodaemon server` + `ADB_SERVER_SOCKET`). Eso alcanza para
**instalar y lanzar** la app, pero **no para hot reload**:

`adb forward` crea el túnel al Dart VM service en el host donde corre el
**servidor**, o sea Windows. WSL no puede alcanzar ese puerto, así que
`flutter run` nunca conecta al VM service y `r` / `R` no hacen nada.

Comprobado: `adb forward --list` muestra el forward, y desde WSL el puerto no
responde.

### Una vez: activar depuración inalámbrica

Teléfono y PC en la **misma red Wi-Fi**.

Ajustes → Opciones de desarrollador → **Depuración inalámbrica** → activar.

### Cada sesión

En la pantalla de Depuración inalámbrica hay **dos puertos distintos**:

- el de la pantalla principal → para `adb connect`
- el que sale en "Vincular dispositivo con código de emparejamiento" → para
  `adb pair`, junto con un código de 6 dígitos

```bash
export PATH="$HOME/android-sdk/platform-tools:$PATH"
unset ADB_SERVER_SOCKET          # adb tiene que correr LOCAL, en WSL

# Solo la primera vez con esta red, o cuando el telefono lo pida de nuevo:
adb pair 10.203.192.183:PUERTO_DE_EMPAREJAMIENTO
# pega el codigo de 6 digitos

adb connect 10.203.192.183:PUERTO_DE_DEPURACION
adb devices                      # debe aparecer como <ip>:<puerto>  device
```

La IP del teléfono sale en la misma pantalla de Depuración inalámbrica.

```bash
./tool/dev.sh 10.203.192.183:PUERTO_DE_DEPURACION
```

`r` hot reload, `R` hot restart. `dev.sh` prefiere el adb local sobre el puente,
así que no hay que configurar nada más.

---

## Web y móvil a la vez

Dos terminales, una por plataforma. Cada una con su propio hot reload:

```bash
# terminal 1
./tool/dev.sh

# terminal 2
./tool/dev.sh 10.203.192.183:PUERTO
```

Comparten el código fuente, así que el mismo cambio se prueba en las dos
resoluciones presionando `r` en cada terminal.

`flutter run -d all` **no** sirve para esto: incluye móviles y escritorio, pero
no el dispositivo `web-server`.

---

## Si el teléfono ya tenía la app de producción

```
INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match newer version
```

El build local va firmado con la llave de debug y la app distribuida con la de
release; Android no permite reemplazar una por otra. Flutter lo resuelve solo
desinstalando la anterior, pero **se pierden los datos de la app**, incluida la
sesión guardada. Para evitarlo, desinstalar antes a mano.

## Si algo falla

| Síntoma | Causa |
|---|---|
| `r` / `R` no hacen nada, la app corre | estás con el puente al adb de Windows; los forwards viven en el host. Usa inalámbrico |
| `adb devices` vacío | Depuración inalámbrica apagada, o el teléfono en otra red |
| `failed to connect` en `adb connect` | puerto equivocado: el de `connect` no es el de `pair` |
| `device unauthorized` | falta el `adb pair` con el código de 6 dígitos |
| el puerto cambia solo | Android lo rota al reactivar Depuración inalámbrica; volver a `adb connect` |
| `flutter devices` no lo muestra pero `adb devices` sí | falta `flutter config --android-sdk`; corre `./tool/android-setup.sh` |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | ver la sección de arriba |

Nota: el teléfono debe estar accesible desde WSL. Se comprueba con
`ping <ip-telefono>`; WSL2 sale a la LAN sin configuración extra.

## Alternativa: usbipd-win

Existe [usbipd-win](https://github.com/dorssel/usbipd-win), que pasa el USB de
verdad a WSL. Da un `adb` local sin puente, pero necesita soporte USB/IP en el
kernel de WSL y un `usbipd attach` por sesión. El puente de adb es más simple y
no depende del kernel; si el puente te falla de forma persistente, esta es la
siguiente opción.

## No confundir con `tool/wsl-expose.ps1`

Ese script es otra cosa: expone el **servidor web** de desarrollo a la red local
para abrir la app en el navegador del celular. No tiene nada que ver con el APK ni
con el cable. Sirve para probar responsive rápido, sin SDK de Android.
