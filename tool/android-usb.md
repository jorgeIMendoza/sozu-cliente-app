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

## Camino B: hot reload en el teléfono (recomendado)

La idea: el **servidor** de adb corre en Windows (donde está el USB) y el
**cliente** de adb corre en WSL apuntándole por TCP. Flutter en WSL ve el
teléfono como si estuviera conectado localmente.

### Una vez: platform-tools en Windows

Descarga
<https://dl.google.com/android/repository/platform-tools-latest-windows.zip>
y descomprímelo, por ejemplo en `C:\platform-tools`.

### Una vez: depuración USB en el teléfono

Ajustes → Acerca del teléfono → toca 7 veces "Número de compilación" →
Ajustes → Opciones de desarrollador → **Depuración por USB**.

Conecta el cable y acepta el diálogo de "¿Permitir depuración USB?" que sale en
la pantalla del teléfono.

### Cada sesión

**1. En Windows** (PowerShell normal, sin admin). Deja esta ventana abierta:

```powershell
cd C:\platform-tools
.\adb.exe kill-server
.\adb.exe -a -P 5037 nodaemon server
```

`-a` es la parte que importa: hace que el servidor escuche en todas las
interfaces y no solo en `127.0.0.1`. Sin eso WSL no lo alcanza.

**2. En WSL**, en otra terminal:

```bash
export ADB_SERVER_SOCKET=tcp:$(ip route show default | awk '{print $3}'):5037
adb devices
```

`ip route show default` da la IP del host Windows visto desde WSL. **No uses una
IP fija**: cambia en cada reinicio.

Deberías ver tu teléfono listado. Si dice `unauthorized`, mira la pantalla del
teléfono y acepta el diálogo.

**3. Correr la app:**

```bash
./tool/dev.sh <id-del-dispositivo>     # el id sale de: flutter devices
```

`r` hot reload, `R` hot restart, igual que en web.

### Para que persista

En `~/.bashrc`:

```bash
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export PATH="$HOME/flutter/bin:$ANDROID_HOME/platform-tools:$PATH"
# Solo si el servidor de adb de Windows esta corriendo:
export ADB_SERVER_SOCKET=tcp:$(ip route show default | awk '{print $3}'):5037
```

⚠️ Con `ADB_SERVER_SOCKET` puesto y el servidor de Windows apagado, `adb` en WSL
falla en vez de arrancar su propio servidor. Si te estorba, exporta la variable
solo cuando la ocupes.

---

## Si algo falla

| Síntoma | Causa |
|---|---|
| `adb devices` vacío | falta `-a` en el servidor de Windows, o el firewall bloquea el 5037 |
| `unauthorized` | falta aceptar el diálogo en la pantalla del teléfono |
| `adb: failed to check server version` | el servidor de Windows no está corriendo, o la IP cambió tras reiniciar |
| `flutter devices` no lo muestra pero `adb devices` sí | falta `flutter config --android-sdk`; corre `./tool/android-setup.sh` |
| Versiones de adb distintas | usa la misma `platform-tools` en los dos lados |

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
