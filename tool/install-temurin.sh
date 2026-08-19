#!/usr/bin/env bash
# Instala Eclipse Temurin 21 (OpenJDK) en ~/jdk21, sin sudo.
#
#   ./tool/install-temurin.sh
#
# Busca el tarball en este orden:
#   1. Descargas de Windows  <- rapido, la red de Windows va por otra ruta
#   2. ~/Downloads
#   3. Descarga desde Adoptium con reanudacion  <- lento (~10 KB/s desde WSL)
#
# Si vas por la opcion 3, dejalo corriendo: `-C -` reanuda donde se corto.
set -uo pipefail

VER_MAJOR=21
DEST="$HOME/jdk21"
TMP="${TMPDIR:-/tmp}/temurin-dl"
mkdir -p "$TMP"

log() { printf '\033[1;36m▶ %s\033[0m\n' "$1"; }
ok()  { printf '\033[1;32mOK   %s\033[0m\n' "$1"; }
die() { printf '\033[1;31mFAIL %s\033[0m\n' "$1" >&2; exit 1; }

if [ -x "$DEST/bin/java" ]; then
  ok "ya instalado: $("$DEST/bin/java" -version 2>&1 | head -1)"
  exit 0
fi

# --- 1. Buscar un tarball ya descargado --------------------------------------
# Se descartan los perfiles plantilla de Windows: existen siempre y no son del
# usuario.
CANDIDATES=()
for base in /mnt/c/Users/*/Downloads "$HOME/Downloads" "$TMP"; do
  [ -d "$base" ] || continue
  case "$(basename "$(dirname "$base")")" in
    Default|"Default User"|Public|"All Users") continue ;;
  esac
  while IFS= read -r f; do CANDIDATES+=("$f"); done < <(
    find "$base" -maxdepth 1 -iname "*jdk*${VER_MAJOR}*linux*.tar.gz" -o \
                 -maxdepth 1 -iname "OpenJDK${VER_MAJOR}U*linux*.tar.gz" 2>/dev/null
  )
done

TARBALL=""
if [ "${#CANDIDATES[@]}" -gt 0 ]; then
  # El mas reciente, por si hay varios intentos.
  TARBALL="$(ls -t "${CANDIDATES[@]}" 2>/dev/null | head -1)"
  ok "encontrado: $TARBALL ($(du -h "$TARBALL" | cut -f1))"
fi

# --- 2. Descargar si no hay ---------------------------------------------------
if [ -z "$TARBALL" ]; then
  TARBALL="$TMP/temurin${VER_MAJOR}.tar.gz"
  log "No encontre el tarball. Descargando de Adoptium (lento desde WSL)"
  echo "  Atajo: bajalo en Windows desde"
  echo "  https://adoptium.net/temurin/releases/?os=linux&arch=x64&version=$VER_MAJOR"
  echo "  dejalo en Descargas y vuelve a correr este script."
  echo
  URL="https://api.adoptium.net/v3/binary/latest/${VER_MAJOR}/ga/linux/x64/jdk/hotspot/normal/eclipse"
  for i in $(seq 1 20); do
    curl -fL -C - --retry 5 --retry-delay 5 --progress-bar -o "$TARBALL" "$URL" && break
    printf '  reintento %s\n' "$i"
    sleep 3
  done
  [ -s "$TARBALL" ] || die "no se pudo descargar"
fi

# --- 3. Verificar que es un tar.gz valido ------------------------------------
# Una descarga cortada deja un archivo que parece bueno hasta que falla el
# extract a medias y queda un JDK incompleto.
tar -tzf "$TARBALL" >/dev/null 2>&1 || die "$TARBALL esta corrupto o incompleto; borralo y reintenta"

# --- 4. Extraer --------------------------------------------------------------
log "Extrayendo en $DEST"
rm -rf "$DEST"
mkdir -p "$DEST"
tar -xzf "$TARBALL" -C "$DEST" --strip-components=1 || die "fallo al extraer"
[ -x "$DEST/bin/java" ] || die "no quedo un java ejecutable en $DEST/bin"

ok "$("$DEST/bin/java" -version 2>&1 | head -1)"
echo
echo "Siguiente paso:"
echo "  ./tool/android-setup.sh"
