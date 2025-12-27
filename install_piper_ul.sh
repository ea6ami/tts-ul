#!/usr/bin/env bash
set -euo pipefail

# ===== Config =====
PIPER_DIR="/opt/piper"
BIN_DIR="${PIPER_DIR}/bin"
MODEL_DIR="${PIPER_DIR}/models"

# Piper binary release (x86_64)
PIPER_TARBALL_URL="https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_x86_64.tar.gz"
PIPER_TARBALL_NAME="piper_linux_x86_64.tar.gz"

# Spanish voice (works in your setup)
VOICE_BASE="es_ES-carlfm-x_low"
VOICE_ONNX_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/carlfm/x_low/es_ES-carlfm-x_low.onnx?download=true"
VOICE_JSON_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/carlfm/x_low/es_ES-carlfm-x_low.onnx.json?download=true"
VOICE_ONNX_PATH="${MODEL_DIR}/${VOICE_BASE}.onnx"
VOICE_JSON_PATH="${MODEL_DIR}/${VOICE_BASE}.onnx.json"

# Test phrase
TEST_TEXT="Atención. Parte meteorológico automático. Temperatura estable."
TEST_WAV="${PIPER_DIR}/prueba.wav"
TEST_UL="${PIPER_DIR}/prueba.ul"

# ===== Helpers =====
msg() { echo -e "\n==> $*\n"; }
die() { echo "ERROR: $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Falta comando requerido: $1"
}

# sudo handling: work with or without sudo
SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    die "No eres root y no existe sudo. Ejecuta como root o instala sudo."
  fi
fi

download() {
  # download URL to output path using wget or curl
  local url="$1"
  local out="$2"

  if command -v wget >/dev/null 2>&1; then
    wget -O "$out" "$url"
  elif command -v curl >/dev/null 2>&1; then
    curl -L -o "$out" "$url"
  else
    die "Necesito wget o curl para descargar archivos."
  fi
}

# ===== Step A: Minimal packages =====
msg "Paso A: instalar dependencias mínimas"
$SUDO apt-get update -y
$SUDO apt-get install -y --no-install-recommends ca-certificates xz-utils sox curl wget

need_cmd sox
need_cmd wget
need_cmd tar

# ===== Step B: Create directories =====
msg "Paso B: preparar directorios"
$SUDO mkdir -p "$BIN_DIR" "$MODEL_DIR"

# ===== Step C: Download & extract Piper =====
msg "Paso C: descargar y extraer Piper"
cd "$BIN_DIR"

# download tarball if missing or empty
if [[ ! -s "${BIN_DIR}/${PIPER_TARBALL_NAME}" ]]; then
  msg "Descargando ${PIPER_TARBALL_NAME}"
  download "$PIPER_TARBALL_URL" "${BIN_DIR}/${PIPER_TARBALL_NAME}"
fi

# extract (creates piper/ directory)
if [[ ! -x "${BIN_DIR}/piper/piper" ]]; then
  msg "Extrayendo tarball"
  tar xzf "${BIN_DIR}/${PIPER_TARBALL_NAME}"
fi

# validate binary
[[ -x "${BIN_DIR}/piper/piper" ]] || die "No se encontró binario en ${BIN_DIR}/piper/piper"

msg "Validación: piper --help"
"${BIN_DIR}/piper/piper" --help >/dev/null

# ===== Step D: Download Spanish voice =====
msg "Paso D: descargar voz española (${VOICE_BASE})"
cd "$MODEL_DIR"

# Download voice ONNX
if [[ ! -s "$VOICE_ONNX_PATH" ]]; then
  msg "Descargando ONNX"
  download "$VOICE_ONNX_URL" "$VOICE_ONNX_PATH"
fi

# Download voice JSON
if [[ ! -s "$VOICE_JSON_PATH" ]]; then
  msg "Descargando JSON"
  download "$VOICE_JSON_URL" "$VOICE_JSON_PATH"
fi

# validate non-empty
[[ -s "$VOICE_ONNX_PATH" ]] || die "Modelo ONNX vacío o ausente: $VOICE_ONNX_PATH"
[[ -s "$VOICE_JSON_PATH" ]] || die "Modelo JSON vacío o ausente: $VOICE_JSON_PATH"

msg "Validación: tamaños de voz"
ls -lh "$VOICE_ONNX_PATH" "$VOICE_JSON_PATH"

# ===== Step E: Synthesize test WAV =====
msg "Paso E: prueba de síntesis a WAV"
cd "$PIPER_DIR"
rm -f "$TEST_WAV" "$TEST_UL"

echo "$TEST_TEXT" | "${BIN_DIR}/piper/piper" --model "$VOICE_ONNX_PATH" --output_file "$TEST_WAV"

[[ -s "$TEST_WAV" ]] || die "No se generó WAV o está vacío: $TEST_WAV"
msg "Validación: info WAV"
sox --i "$TEST_WAV"

# ===== Step F: Convert to .ul =====
msg "Paso F: convertir a .ul (G.711 µ-law, 8 kHz, mono)"
sox "$TEST_WAV" -r 8000 -c 1 -t ul "$TEST_UL"

[[ -s "$TEST_UL" ]] || die "No se generó UL o está vacío: $TEST_UL"
msg "Validación: info UL"
sox --i "$TEST_UL" | sed -n '1,12p'

# Light sanity checks on output properties
if ! sox --i "$TEST_UL" | grep -qi "Sample Rate.*8000"; then
  die "La salida .ul no parece 8000 Hz"
fi
if ! sox --i "$TEST_UL" | grep -qi "Channels.*1"; then
  die "La salida .ul no parece mono"
fi
if ! sox --i "$TEST_UL" | grep -qi "u-law"; then
  die "La salida no parece u-law"
fi

msg "TODO OK ✅"
echo "Piper: ${BIN_DIR}/piper/piper"
echo "Voz:   ${VOICE_ONNX_PATH}"
echo "Test:  ${TEST_UL}"
BASH

