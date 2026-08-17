#!/usr/bin/env bash
# Levanta el portal del cliente en modo desarrollo (web).
#
#   ./tool/dev.sh              -> web en http://localhost:5000
#   PORT=5100 ./tool/dev.sh    -> otro puerto
#   ./tool/dev.sh <device-id>  -> un dispositivo (ver: flutter devices)
#   PROFILE=1 ./tool/dev.sh    -> modo PROFILE (para medir rendimiento)
#   SIN_PREVIEW=1 ./tool/dev.sh-> sin el cintillo azul de PREVIEW arriba
#
# OJO CON EL RENDIMIENTO: por defecto esto corre en modo DEBUG, y en Flutter web
# debug compila con DDC sin optimizar. Es varias veces mas lento que release y el
# coste escala con el numero de widgets, asi que una pantalla densa se siente
# pesada aunque en produccion vaya bien. Para juzgar rendimiento hay que usar
# `PROFILE=1`; medir en debug lleva a "optimizar" cosas que no son el problema.
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

# --- Backend contra DEV -------------------------------------------------------
# `assets/env` apunta a PRODUCCION, asi que probar un cambio de edge function
# obliga a pasarlo por PR -> dev -> main -> deploy. Con BACKEND=dev la app corre
# contra el ambiente de desarrollo, donde `deploy-dev.yml` publica sola en
# cuanto algo entra a la rama `dev`: el ciclo baja de horas a un minuto.
#
#   BACKEND=dev ./tool/dev.sh
#
# Necesita `assets/env.dev` con la URL y la anon key de ese ambiente (mismo
# formato que `assets/env`, tambien gitignored). El archivo NO se toca: se pasa
# por --dart-define, asi que no hay riesgo de commitear el de prod cambiado ni
# de quedarse apuntando a DEV sin darse cuenta.
DEFINES_ENV=()
if [ "${BACKEND:-prod}" = "dev" ]; then
  # El canonico es `.env.dev` en la raiz, la convencion de siempre. Aqui SI se
  # puede usar un dotfile: este archivo NO es un asset de Flutter, lo lee bash y
  # sus valores viajan por --dart-define. (`assets/env`, el de produccion, no
  # puede llevar punto: Flutter no empaqueta dotfiles y la web release queda en
  # blanco.) Se aceptan las variantes viejas para no romperle a nadie.
  ENV_DEV=""
  for f in .env.dev assets/.env.dev assets/env.dev; do
    [ -f "$f" ] && ENV_DEV="$f" && break
  done
  if [ -z "$ENV_DEV" ]; then
    echo "Falta .env.dev con SUPABASE_URL y SUPABASE_ANON_KEY del ambiente DEV." >&2
    echo "Pidele los valores a quien administra el VPS de functions." >&2
    exit 1
  fi
  # El `|| true` NO sobra: con `set -e`, un grep que no encuentra la clave
  # devuelve 1 y mata el script en la asignacion. CLIENTE_ROL_ID es opcional,
  # asi que sin esto un .env.dev valido tumbaba el arranque sin decir por que.
  DEV_URL=$(grep -m1 '^SUPABASE_URL=' "$ENV_DEV" | cut -d= -f2- || true)
  DEV_KEY=$(grep -m1 '^SUPABASE_ANON_KEY=' "$ENV_DEV" | cut -d= -f2- || true)
  DEV_ROL=$(grep -m1 '^CLIENTE_ROL_ID=' "$ENV_DEV" | cut -d= -f2- || true)
  if [ -z "$DEV_URL" ] || [ -z "$DEV_KEY" ]; then
    echo "$ENV_DEV no trae SUPABASE_URL o SUPABASE_ANON_KEY." >&2
    exit 1
  fi
  DEFINES_ENV=(
    --dart-define=SUPABASE_URL="$DEV_URL"
    --dart-define=SUPABASE_ANON_KEY="$DEV_KEY"
  )
  # El id del rol Cliente puede no ser 23 fuera de produccion.
  [ -n "$DEV_ROL" ] && DEFINES_ENV+=(--dart-define=CLIENTE_ROL_ID="$DEV_ROL")
  echo "⚠️  Backend: DEV ($DEV_URL)"
else
  echo "Backend: produccion (assets/env)"
fi

DEVICE="${1:-web-server}"
# Sin argumento el destino es la web. Se recuerda si hubo argumento para poder
# avisar cuando hay un movil conectado y aun asi se va a arrancar en web.
ARGS_DADOS=$#
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

  # Con android-udev el nodo USB queda root:adbusers 0660, asi que el acceso lo
  # da el GRUPO. Pero la pertenencia a un grupo se fija al abrir la sesion: si
  # `usermod -aG adbusers` se corrio despues, esta shell no lo tiene aunque
  # /etc/group ya lo diga, y adb no puede abrir el nodo.
  #
  # `sg` arranca el servidor de adb con el grupo aplicado, que es todo lo que
  # hace falta: el servidor es el unico proceso que toca el USB. Evita el
  # `wsl --shutdown` y evita el chmod, que se pierde en cada reconexion.
  if getent group adbusers 2>/dev/null | grep -qw "$USER" &&
    ! id -nG 2>/dev/null | grep -qw adbusers; then
    if ! adb devices 2>/dev/null | tail -n +2 | grep -q "device$"; then
      echo "==> grupo adbusers pendiente en esta shell: relanzando adb con el grupo"
      adb kill-server >/dev/null 2>&1 || true
      sg adbusers -c "$ANDROID_HOME/platform-tools/adb start-server" >/dev/null 2>&1 || true
    fi
  fi

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
    if ! getent group adbusers >/dev/null 2>&1; then
      echo "    Falta el paquete con las reglas udev de Android:" >&2
      echo "      sudo pacman -S --noconfirm android-udev" >&2
    fi
    if ! getent group adbusers 2>/dev/null | grep -qw "$USER"; then
      echo "    No estas en el grupo adbusers:" >&2
      echo "      sudo usermod -aG adbusers \$USER" >&2
      echo "    (este script aplica el grupo solo con \`sg\`, sin reiniciar WSL)" >&2
    fi
    if [ -n "$NODO" ]; then
      echo "    Ultimo recurso, se pierde al reconectar el cable:" >&2
      echo "      sudo chmod 666 $NODO" >&2
    fi
    echo "      adb kill-server && adb devices" >&2
    exit 1
  fi
  if adb devices 2>/dev/null | tail -n +2 | grep -q "device$"; then
    echo "==> adb local (hot reload disponible)"
    echo "==> para la web en paralelo, en OTRA terminal:  ./tool/dev.sh"
  else
    # Candidatos para el servidor de adb de Windows, en orden:
    #  - 127.0.0.1  con `networkingMode=mirrored` WSL comparte la red del host,
    #    asi que el servidor de Windows se alcanza por localhost (y NO por el
    #    gateway, que en ese modo no lleva a ningun lado).
    #  - gateway    modo NAT, el de siempre.
    #
    # No basta con que el puerto abra: `adb devices` de arriba ya dejo un
    # servidor LOCAL escuchando en 127.0.0.1:5037, y en modo espejo eso se ve
    # igual que el de Windows. Se acepta el candidato solo si REPORTA un
    # dispositivo, que es lo unico que lo hace util.
    WIN_HOST=""
    for CAND in 127.0.0.1 "$(ip route show default 2>/dev/null | awk '{print $3}')"; do
      [ -z "$CAND" ] && continue
      timeout 3 bash -c "cat < /dev/null > /dev/tcp/$CAND/5037" 2>/dev/null || continue
      if ADB_SERVER_SOCKET="tcp:$CAND:5037" timeout 5 adb devices 2>/dev/null |
        tail -n +2 | grep -q "device$"; then
        WIN_HOST="$CAND"
        break
      fi
    done
    if [ -n "$WIN_HOST" ]; then
      export ADB_SERVER_SOCKET="tcp:$WIN_HOST:5037"
      echo "!!  Usando el puente al adb de Windows ($WIN_HOST): SIN HOT RELOAD." >&2
      echo "    Los forwards quedan en el host y WSL no los alcanza." >&2
      echo "    Para tener hot reload, usa depuracion inalambrica:" >&2
      echo "      adb pair <ip-telefono>:<puerto>   # codigo de 6 digitos" >&2
      echo "      adb connect <ip-telefono>:<puerto>" >&2
      echo "    Detalle en tool/android-usb.md" >&2
    else
      echo "!!  Ningun dispositivo y no hay servidor de adb en Windows." >&2
      echo "    En Windows, dentro de platform-tools, deja corriendo:" >&2
      echo "      .\\adb.exe -a -P 5037 nodaemon server" >&2
      echo "    (el flag -a es obligatorio en modo NAT; en mirrored no estorba)" >&2
      echo "" >&2
      echo "    O usa depuracion inalambrica, que da hot reload:" >&2
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
  "${DEFINES_ENV[@]+"${DEFINES_ENV[@]}"}"
)

# El cintillo de PREVIEW ocupa alto real y desplaza todo hacia abajo, asi que
# estorba al revisar diseño en el telefono. Se apaga solo el cintillo: sigue
# siendo un build de preview, con sus logs de diagnostico.
if [ -n "${SIN_PREVIEW:-}" ]; then
  COMMON_ARGS+=(--dart-define=HIDE_PREVIEW=true)
  echo "==> sin cintillo de PREVIEW (sigue siendo build de preview)"
fi

# En profile no hay hot reload (el JIT no esta), pero es el UNICO modo en el que
# los tiempos significan algo.
if [ -n "${PROFILE:-}" ]; then
  COMMON_ARGS+=(--profile)
  echo "==> modo PROFILE: sin hot reload, con tiempos reales"
fi

if [ "$DEVICE" = "web-server" ] || [ "$DEVICE" = "chrome" ]; then
  # Para probar en las dos plataformas a la vez, cada una necesita su terminal.
  # El `|| true` es obligatorio: con `set -e`, un grep sin coincidencias (ningun
  # movil conectado) mataba el script ANTES de arrancar flutter run.
  ADB_BIN="${ANDROID_HOME:-$HOME/android-sdk}/platform-tools/adb"
  MOVIL=""
  if [ -x "$ADB_BIN" ]; then
    MOVIL="$("$ADB_BIN" devices 2>/dev/null | tail -n +2 \
      | grep "device$" | head -1 | awk '{print $1}' || true)"
  fi
  # Va ANTES de la comprobacion del puerto: si el puerto esta ocupado se sale,
  # y lo primero que hay que leer es que el destino no era la web.
  if [ -n "$MOVIL" ]; then
    if [ "$ARGS_DADOS" -eq 0 ]; then
      # El caso que muerde: se conecta el telefono, se lanza dev.sh a secas y
      # sale la web. No es un error -es el destino por defecto- pero con el
      # cable puesto casi nunca es lo que se queria.
      echo "==> OJO: hay un movil conectado ($MOVIL) y esto va a arrancar en WEB."
      echo "    Sin argumento, dev.sh usa el servidor web. Para el telefono:"
      echo "      ./tool/dev.sh $MOVIL"
    else
      echo "==> movil detectado. En OTRA terminal, para probar los dos a la vez:"
      echo "      ./tool/dev.sh $MOVIL"
    fi
  fi

  # Se comprueba AQUI y no se deja fallar a flutter: `flutter run` tarda casi un
  # minuto en llegar al bind (pub get + compilar) y entonces escupe un
  # SocketException con ocho frames de stack que no nombra la causa real, que
  # casi siempre es otro dev.sh vivo en otra terminal.
  if ss -lnt 2>/dev/null | awk '{print $4}' | grep -qE "[:.]$PORT\$"; then
    echo "==> El puerto $PORT ya esta ocupado, seguramente por otro ./tool/dev.sh." >&2
    echo "    Cierra aquel con 'q' en su terminal, o levanta este en otro puerto:" >&2
    echo "      PORT=5100 ./tool/dev.sh" >&2
    exit 1
  fi

  # 0.0.0.0 para poder abrirlo desde el navegador de Windows y desde el
  # celular en la misma red (util para probar responsive en fisico).
  echo "==> http://localhost:$PORT"

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
