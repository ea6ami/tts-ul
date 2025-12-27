#!/usr/bin/env bash
set -euo pipefail

PIPER_BIN="/opt/piper/bin/piper/piper"
MODEL="/opt/piper/models/es_ES-carlfm-x_low.onnx"

OUT=""
TEXT=""
FILE=""

usage() {
  cat <<EOF
Uso:
  $0 -t "texto" -o salida.ul
  $0 -f texto.txt -o salida.ul
  echo "texto" | $0 -o salida.ul

Opciones:
  -t  Texto directo
  -f  Archivo de texto (UTF-8)
  -o  Archivo de salida .ul (obligatorio)
  -m  Ruta a modelo .onnx (opcional; por defecto: $MODEL)
EOF
}

die(){ echo "ERROR: $*" >&2; exit 1; }

while getopts ":t:f:o:m:h" opt; do
  case "$opt" in
    t) TEXT="$OPTARG" ;;
    f) FILE="$OPTARG" ;;
    o) OUT="$OPTARG" ;;
    m) MODEL="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) die "Opción inválida: -$OPTARG" ;;
    :) die "Falta argumento para -$OPTARG" ;;
  esac
done

[[ -n "$OUT" ]] || { usage; die "Debes indicar -o salida.ul"; }
[[ -x "$PIPER_BIN" ]] || die "No existe Piper en: $PIPER_BIN"
[[ -s "$MODEL" ]] || die "No existe el modelo en: $MODEL"

# Decide input source (exactly one of: TEXT, FILE, STDIN-with-data)
input_count=0
[[ -n "$TEXT" ]] && input_count=$((input_count+1))
[[ -n "$FILE" ]] && input_count=$((input_count+1))

# Solo cuenta stdin si HAY datos disponibles (no basta con "no es tty")
stdin_has_data=0
if [[ ! -t 0 ]]; then
  # read -t 0 no consume, solo comprueba disponibilidad inmediata
  if IFS= read -r -t 0 _; then
    stdin_has_data=1
    input_count=$((input_count+1))
  fi
fi

if [[ "$input_count" -eq 0 ]]; then
  usage
  die "No hay texto de entrada. Usa -t, -f o stdin."
elif [[ "$input_count" -gt 1 ]]; then
  die "Elige SOLO una entrada: -t, -f o stdin."
fi

tmpwav="$(mktemp --tmpdir tts.XXXXXX.wav)"
trap 'rm -f "$tmpwav"' EXIT

# Generate WAV (16k) then convert to ul (8k, mono, u-law)
if [[ -n "$TEXT" ]]; then
  printf "%s" "$TEXT" | "$PIPER_BIN" --model "$MODEL" --output_file "$tmpwav"
elif [[ -n "$FILE" ]]; then
  [[ -s "$FILE" ]] || die "El archivo no existe o está vacío: $FILE"
  "$PIPER_BIN" --model "$MODEL" --output_file "$tmpwav" < "$FILE"
else
  # stdin (con datos)
  cat | "$PIPER_BIN" --model "$MODEL" --output_file "$tmpwav"
fi

[[ -s "$tmpwav" ]] || die "No se generó WAV temporal"

# Convert
sox "$tmpwav" -r 8000 -c 1 -t ul "$OUT"

[[ -s "$OUT" ]] || die "No se generó UL: $OUT"
