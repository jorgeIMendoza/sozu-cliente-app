#!/usr/bin/env bash
# Levanta el portal del cliente en modo desarrollo (web).
#
#   ./tool/dev.sh              -> web en http://localhost:5000
#   PORT=5100 ./tool/dev.sh    -> otro puerto
#   ./tool/dev.sh <device-id>  -> un dispositivo (ver: flutter devices)
#
# WEB Y MOVIL A LA VEZ: dos terminales, una por plataforma. Cada una tiene su
# propio hot reload. `flutter run -d all` NO sirve aqui porque no incluye el
# dispositivo web-server, solo moviles y escritorio.
#
#   terminal 1:  ./tool/dev.sh
#   terminal 2:  ./tool/dev.sh 10.203.192.183:5555
#
# Los dos comparten el mismo codigo fuente, asi que un cambio se prueba en las
# dos resoluciones presionando `r` en cada terminal.
#
# En la terminal, mientras corre:  r = hot reload | R = hot restart | q = salir
set -euo pipefail

cd "$(dirname "$0")/.."

# El SDK vive fuera del PATH por defecto en WSL.
export PATH="$HOME/flutter/bin:$PATH"

if ! command -v flutter >/dev/null; then
  echo "flutter no esta en el PATH. Instalalo en ~/flutter (ver README)." >&2
  exit 1
fi

if [ ! -f assets/env ]; then
  echo "Falta assets/env. Copia .env.example y llena SUPABASE_URL / SUPABASE_ANON_KEY." >&2
  exit 1
fi

DEVICE="${1:-web-server}"
PORT="${PORT:-5000}"

# --- Dispositivos fisicos -----------------------------------------------------
# Dos caminos, y NO son equivalentes:
#
# 1. INALAMBRICO (recomendado): `adb` corre dentro de WSL y el telefono se
#    conecta por TCP. Los `adb forward` quedan LOCALES, asi que flutter alcanza
#    el Dart VM service y el HOT RELOAD FUNCIONA.
#
# 2. Puente al servidor de adb de Windows: sirve para instalar y lanzar, pero
#    `adb forward` crea el tunel en el host de Windows y WSL no lo alcanza, asi
#    que flutter nunca conecta al VM service y `r`/`R` no hacen nada.
#
# Por eso se prefiere el local y el puente solo se usa como ultimo recurso, con
# aviso. Ver tool/android-usb.md.
if [ "$DEVICE" != "web-server" ] && [ "$DEVICE" != "chrome" ]; then
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
  export PATH="$ANDROID_HOME/platform-tools:$PATH"
  [ -x "$HOME/jdk21/bin/java" ] && [ -z "${JAVA_HOME:-}" ] && export JAVA_HOME="$HOME/jdk21"

  # 1. Servidor local: si ya hay un dispositivo conectado, ese gana.
  unset ADB_SERVER_SOCKET
  # `no permissions` es un caso aparte: el dispositivo SI esta ahi, falta acceso
  # al nodo USB. Sin distinguirlo, el mensaje mandaba al camino inalambrico, que
  # no tiene nada que ver.
  if adb devices 2>/dev/null | grep -q "no permissions"; then
    # El nodo se calcula desde sysfs, NO con `ls | tail -1`: los hubs virtuales
    # de USB/IP tambien son nodos y son los que quedan al final de la lista.
    # busnum/devnum cambian en cada reconexion, asi que no se puede cachear.
    NODO=""
    for D in /sys/bus/usb/devices/*/; do
      [ -f "$D/idVendor" ] || continue
      case "$(cat "$D/product" 2>/dev/null)" in
        *"USB/IP"*|*"Virtual Host Controller"*) continue ;;
      esac
      B="$(cat "$D/busnum" 2>/dev/null)"; V="$(cat "$D/devnum" 2>/dev/null)"
      [ -n "$B" ] && [ -n "$V" ] || continue
      NODO="$(printf '/dev/bus/usb/%03d/%03d' "$B" "$V")"
    done
    echo "!!  El dispositivo esta conectado pero sin permisos sobre el nodo USB." >&2
    echo "    Permanente (una vez, y ya no vuelve a pasar al reconectar):" >&2
    echo "      sudo pacman -S --noconfirm android-udev" >&2
    echo "      sudo usermod -aG adbusers \$USER" >&2
    echo "      luego, desde Windows:  wsl --shutdown" >&2
    if [ -n "$NODO" ]; then
      echo "    Ahora mismo, sin reiniciar (se pierde al reconectar el cable):" >&2
      echo "      sudo chmod 666 $NODO" >&2
    else
      echo "    No se pudo ubicar el nodo; revisa:  ls -la /dev/bus/usb/*/*" >&2
    fi
    echo "      adb kill-server && adb devices" >&2
    exit 1
  fi
  if adb devices 2>/dev/null | tail -n +2 | grep -q "device$"; then
    echo "==> adb local (hot reload disponible)"
    echo "==> para la web en paralelo, en OTRA terminal:  ./tool/dev.sh"
  else
    WIN_HOST="$(ip route show default 2>/dev/null | awk '{print $3}')"
    if [ -n "$WIN_HOST" ] && timeout 3 bash -c "cat < /dev/null > /dev/tcp/$WIN_HOST/5037" 2>/dev/null; then
      export ADB_SERVER_SOCKET="tcp:$WIN_HOST:5037"
      echo "!!  Usando el puente al adb de Windows: SIN HOT RELOAD." >&2
      echo "    Los forwards quedan en el host y WSL no los alcanza." >&2
      echo "    Para tener hot reload, usa depuracion inalambrica:" >&2
      echo "      adb pair <ip-telefono>:<puerto>   # codigo de 6 digitos" >&2
      echo "      adb connect <ip-telefono>:<puerto>" >&2
      echo "    Detalle en tool/android-usb.md" >&2
    else
      echo "!!  Ningun dispositivo. Activa depuracion inalambrica y corre:" >&2
      echo "      adb pair <ip-telefono>:<puerto>" >&2
      echo "      adb connect <ip-telefono>:<puerto>" >&2
      echo "    Detalle en tool/android-usb.md" >&2
      exit 1
    fi
  fi
fi
BUILD_TIMESTAMP="$(TZ=America/Mexico_City date +%y%m%d.%H%M)"

flutter pub get

COMMON_ARGS=(
  --dart-define=BUILD_TIMESTAMP="$BUILD_TIMESTAMP"
  --dart-define=APP_ENV=dev
)

if [ "$DEVICE" = "web-server" ] || [ "$DEVICE" = "chrome" ]; then
  # 0.0.0.0 para poder abrirlo desde el navegador de Windows y desde el
  # celular en la misma red (util para probar responsive en fisico).
  echo "==> http://localhost:$PORT"
  # Para probar en las dos plataformas a la vez, cada una necesita su terminal.
  # El `|| true` es obligatorio: con `set -e`, un grep sin coincidencias (ningun
  # movil conectado) mataba el script ANTES de arrancar flutter run.
  ADB_BIN="${ANDROID_HOME:-$HOME/android-sdk}/platform-tools/adb"
  MOVIL=""
  if [ -x "$ADB_BIN" ]; then
    MOVIL="$("$ADB_BIN" devices 2>/dev/null | tail -n +2 \
      | grep "device$" | head -1 | awk '{print $1}' || true)"
  fi
  if [ -n "$MOVIL" ]; then
    echo "==> movil detectado. En OTRA terminal, para probar los dos a la vez:"
    echo "      ./tool/dev.sh $MOVIL"
  fi

  # WSL2 esta detras de NAT: escuchar en 0.0.0.0 NO alcanza para que el celular
  # llegue, hace falta un portproxy en Windows. Se imprime el comando exacto en
  # vez de explicarlo, porque la IP de WSL cambia en cada reinicio.
  if grep -qi microsoft /proc/version 2>/dev/null; then
    WSL_IP="$(ip -4 -o addr show eth0 2>/dev/null | sed -n 's|.*inet \([0-9.]*\)/.*|\1|p' | head -1)"
    PS1_WIN="$(command -v wslpath >/dev/null && wslpath -w "$(pwd)/tool/wsl-expose.ps1" || echo 'tool\wsl-expose.ps1')"
    echo "==> WSL IP: ${WSL_IP:-desconocida}"
    echo "    Para abrir desde el celular, en PowerShell de Windows COMO ADMIN:"
    echo "      powershell -ExecutionPolicy Bypass -File \"$PS1_WIN\" -Port $PORT"
    echo "    (una vez por reinicio de WSL; imprime la URL para el celular)"
  fi

  exec flutter run -d "$DEVICE" \
    --web-hostname 0.0.0.0 \
    --web-port "$PORT" \
    "${COMMON_ARGS[@]}"
fi

exec flutter run -d "$DEVICE" "${COMMON_ARGS[@]}"
