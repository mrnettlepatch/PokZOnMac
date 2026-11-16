#!/bin/bash
# construir.sh — convierte Pokémon Z (versión de Windows) en una app nativa de macOS.
#
# Uso:
#   ./construir.sh "/ruta/a/Pokemon Z v2.19" [carpeta_destino]
#
# carpeta_destino: dónde crear "Pokemon Z.app" (por defecto /Applications).
# Variables opcionales:
#   MKXPZ_ZIP=/ruta/mkxp-z.zip   usar un zip de mkxp-z ya descargado
#   FORZAR=1                     sustituir una app existente (la antigua va a la Papelera)
set -euo pipefail

# mkxp-z probado con este port (commit 3c7c47c, macOS universal)
MKXPZ_URL="https://nightly.link/mkxp-z/mkxp-z/actions/runs/43788937344/mkxp-z.macos.universal.app.dev-3c7c47c.zip"
MKXPZ_SHA256="1ee91858530b34a0400ba427c3271610d5487a9b42da57d2c81bf23053232c34"
# Alternativa si el artefacto anterior ha caducado (última versión de desarrollo, no probada)
MKXPZ_URL_LATEST_PAGE="https://nightly.link/mkxp-z/mkxp-z/workflows/autobuild/dev"

APP_NAME="Pokemon Z.app"
BUNDLE_ID="io.github.pokzonmac.pokemonz"
HERE="$(cd "$(dirname "$0")" && pwd)"
PORT="$HERE/port"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m !\033[0m %s\n' "$*"; }
fail()  { printf '\033[1;31m ✗ %s\033[0m\n' "$*" >&2; exit 1; }

[ $# -ge 1 ] || { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
[ "$(uname)" = "Darwin" ] || fail "Este script es para macOS."
command -v ruby >/dev/null || fail "Hace falta Ruby (viene con macOS; si no, instálalo con: brew install ruby)."

GAME="$(cd "$1" 2>/dev/null && pwd)" || fail "No existe la carpeta del juego: $1"
DEST="${2:-/Applications}"
[ -f "$GAME/Game.ini" ] && [ -f "$GAME/Data/Scripts.rxdata" ] || fail "'$GAME' no parece la carpeta de Pokémon Z (falta Game.ini o Data/Scripts.rxdata)."
grep -qi 'Pokemon Z' "$GAME/Game.ini" || warn "Game.ini no menciona 'Pokemon Z'; el port está pensado para Pokémon Z v2.19."
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"
APP="$DEST/$APP_NAME"
case "$DEST" in
  "$HOME/Downloads"*|"$HOME/Descargas"*) warn "mkxp-z no arranca desde la carpeta Descargas: mueve la app a Aplicaciones antes de jugar." ;;
esac
if [ -e "$APP" ]; then
  if [ "${FORZAR:-0}" = "1" ]; then
    TRASHED="$HOME/.Trash/Pokemon Z (anterior $(date +%Y%m%d-%H%M%S)).app"
    mv "$APP" "$TRASHED"; warn "La app anterior se ha movido a la Papelera."
  else
    fail "Ya existe $APP. Bórrala o ejecuta con FORZAR=1 para sustituirla."
  fi
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1. Motor mkxp-z ------------------------------------------------------------
info "Obteniendo el motor mkxp-z"
ZIP="$WORK/mkxp-z.zip"
if [ -n "${MKXPZ_ZIP:-}" ]; then
  cp "$MKXPZ_ZIP" "$ZIP"; ok "Usando $MKXPZ_ZIP"
elif curl -fsSL -o "$ZIP" "$MKXPZ_URL" && [ "$(shasum -a 256 "$ZIP" | cut -d' ' -f1)" = "$MKXPZ_SHA256" ]; then
  ok "mkxp-z 3c7c47c descargado y verificado (SHA-256)"
else
  warn "La versión probada de mkxp-z ya no está disponible; se usará la última de desarrollo."
  LATEST="$(curl -fsSL "$MKXPZ_URL_LATEST_PAGE" | grep -o 'https://[^"]*macos\.universal\.app[^"]*\.zip' | head -1)" || true
  [ -n "$LATEST" ] || fail "No se pudo descargar mkxp-z. Descárgalo a mano (macos.universal.app) y usa MKXPZ_ZIP=/ruta/al.zip"
  curl -fsSL -o "$ZIP" "$LATEST" || fail "No se pudo descargar $LATEST"
  ok "Descargado $LATEST"
fi
unzip -q "$ZIP" -d "$WORK/mkxpz"
SRC_APP="$(find "$WORK/mkxpz" -maxdepth 2 -name '*.app' -type d | head -1)"
[ -n "$SRC_APP" ] || fail "El zip de mkxp-z no contiene una .app"

# 2. Estructura de la app ----------------------------------------------------
info "Creando $APP"
cp -R "$SRC_APP" "$APP"
BIN="$APP/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")"
chmod +x "$BIN"
G="$APP/Contents/Game"
cp -cR "$GAME" "$G" 2>/dev/null || cp -R "$GAME" "$G"   # -c: copia instantánea en APFS
cp -R "$WORK/mkxpz/stdlib" "$G/stdlib"
mkdir -p "$G/scripts"
cp -R "$WORK/mkxpz/scripts/preload" "$G/scripts/preload"
# Archivos solo para Windows/JoiPlay
find "$G" -maxdepth 2 \( -iname '*.exe' -o -iname '*.dll' -o -iname '*.lnk' \) -delete
rm -f "$G/.nomedia" "$G/preload.rb"
ok "Juego copiado (la carpeta original no se modifica)"

# 3. Port ---------------------------------------------------------------------
info "Aplicando el port a los scripts del juego"
ruby "$PORT/patch_scripts.rb" "$GAME/Data/Scripts.rxdata" "$G/Data/Scripts.rxdata"
cp "$PORT/pokemonz_mac.rb" "$G/scripts/preload/"
cp "$PORT/mkxp.json" "$G/mkxp.json"
cp "$PORT/mando_xbox.mkxp1" "$G/mando_xbox.mkxp1"
ok "Compatibilidad macOS instalada"

# 4. Info.plist, firma y ajustes ----------------------------------------------
info "Configurando y firmando la app"
P="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName 'Pokemon Z'" \
                        -c "Set :CFBundleIdentifier $BUNDLE_ID" \
                        -c "Set :CFBundleGetInfoString 'Pokemon Z (PokZOnMac)'" "$P"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string 'Pokemon Z'" "$P" 2>/dev/null || true
xattr -cr "$APP"
codesign --force --deep -s - "$APP" >/dev/null 2>&1 && ok "Firmada (ad-hoc)" || warn "No se pudo firmar; abre la app con clic derecho > Abrir."
# Evita el aviso "¿reabrir ventanas?" tras un cierre inesperado, que bloquea el motor
defaults write "$BUNDLE_ID" NSQuitAlwaysKeepsWindows -bool false

# Mapeado de mando de Xbox (mkxp-z lo lee de esta ruta; no se sobrescribe uno existente)
DATA="$HOME/Library/Application Support/PokemonZ"
mkdir -p "$DATA/PokemonZ"
if [ ! -e "$DATA/PokemonZkeybindings.mkxp1" ]; then
  cp "$PORT/mando_xbox.mkxp1" "$DATA/PokemonZkeybindings.mkxp1"; ok "Mapeado de mando de Xbox instalado"
else
  warn "Ya tenías controles personalizados; no se han cambiado."
fi

echo
ok "¡Listo! Abre '$APP'."
echo "   Partidas: ~/Library/Application Support/PokemonZ/PokemonZ"
