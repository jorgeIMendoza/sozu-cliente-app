# Correr la app en desarrollo

Flujo diario. El detalle y el diagnóstico están en `android-usb.md`.

---

## Web (siempre disponible)

```bash
./tool/dev.sh
```

→ <http://localhost:5000>. `r` hot reload, `R` hot restart, `q` salir.

---

## Móvil por CABLE (camino probado, con hot reload)

`usbipd-win` pasa el USB de verdad a WSL, así que `adb` corre **local** y los
`adb forward` quedan en WSL: el hot reload funciona. El serial del teléfono es
fijo, no rota como el puerto inalámbrico.

### Una vez en Windows

PowerShell **admin**: `winget install usbipd`

### Cada vez que conectas el cable

PowerShell **admin**:

```powershell
usbipd list                            # busca tu telefono, copia el BUSID
usbipd attach --wsl --busid <BUSID>
```

En WSL:

```bash
./tool/dev.sh DYLRPNJNIRKNZPRG
```

Si sale `no permissions`, falta acceso al nodo USB. Permanente (una vez):

```bash
sudo pacman -S --noconfirm android-udev
sudo usermod -aG adbusers $USER
# y luego, desde Windows:  wsl --shutdown
```

Inmediato, sin reiniciar: `sudo chmod 666 /dev/bus/usb/001/002` (se pierde al
reconectar el cable). `dev.sh` imprime estos comandos si detecta el caso.

---

## Móvil por Wi-Fi (alternativa, sin cable)

Es el APK nativo de verdad, no una página web. La Wi-Fi solo transporta los datos
entre `adb` y el teléfono; la app queda instalada en el cajón de aplicaciones.

### Una vez por teléfono

Ajustes → Acerca del teléfono → 7 toques en **Número de compilación** →
Opciones de desarrollador.

En Oppo/ColorOS hacen falta además:
- **Depuración USB** activada
- **Desactivar monitoreo de permisos** activada

### Cada sesión

**1.** Teléfono: Opciones de desarrollador → **Depuración inalámbrica** → activar.

Esa pantalla muestra dos puertos **distintos**, y confundirlos es el error típico:

```
Dirección IP y puerto
  10.203.192.183:37129          <- el de `adb connect`

"Vincular dispositivo con código de emparejamiento"
  Código: 123456
  10.203.192.183:41235          <- el de `adb pair`
```

Android los rota cada vez que reactivas Depuración inalámbrica.

**2.** En WSL:

```bash
export PATH="$HOME/android-sdk/platform-tools:$PATH"
unset ADB_SERVER_SOCKET

# Solo cuando el telefono lo pida (primera vez en esta red, o tras reiniciar):
adb pair 10.203.192.183:41235      # pega el codigo de 6 digitos

adb connect 10.203.192.183:37129
adb devices                         # debe salir <ip>:<puerto>  device
```

**3.** Correr:

```bash
./tool/dev.sh 10.203.192.183:37129
```

---

## Las dos a la vez

Dos terminales, una por plataforma, cada una con su propio hot reload:

```bash
# terminal 1
./tool/dev.sh

# terminal 2  (cable)
./tool/dev.sh DYLRPNJNIRKNZPRG
# ...o inalambrico:
./tool/dev.sh 10.203.192.183:37129
```

Comparten el código, así que el mismo cambio se prueba en las dos resoluciones
presionando `r` en cada terminal.

`flutter run -d all` **no** sirve: incluye móviles y escritorio, no `web-server`.

---

## Cosas que se olvidan

| Situación | Qué hacer |
|---|---|
| Cambiaste `pubspec.yaml` (assets, fuentes, dependencias) | matar y relanzar `dev.sh`. Ni `r` ni `R` los toman |
| Cambiaste algo `const` | `R`, no `r` |
| `r` / `R` no responden | ¿estás con el puente al adb de Windows? No da hot reload. Usa cable con `usbipd` o inalámbrico |
| `no permissions` en `adb devices` | falta `android-udev` + grupo `adbusers`, o un `chmod 666` al nodo |
| `adb devices` vacío tras conectar el cable | falta `usbipd attach --wsl --busid <BUSID>` en Windows |
| El puerto ya no funciona | Android lo rotó: volver a `adb connect` con el nuevo |
| Errores de `detector.dart.js` o websocket en la consola | es la extensión Dart Debug de Chrome fallando, no la app. Desactivarla |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | tenías la app de producción instalada; Flutter desinstala y reinstala, y se pierden los datos |

---

## Otros scripts

| Script | Para qué |
|---|---|
| `check.sh` | formato + `analyze` + tests. Lo mismo que el IDE |
| `apk.sh` | compila el APK y lo copia a Descargas de Windows |
| `android-setup.sh` | reinstalar el SDK de Android (ya está hecho) |
| `install-temurin.sh` | reinstalar el JDK (ya está hecho) |
| `wsl-expose.ps1` | abrir la **web** en el navegador del celular. NO es la app nativa |
