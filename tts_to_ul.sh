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

# Reglas:
#  - Si hay -t -> usar TEXT (y NO mirar stdin)
#  - Si hay -f -> usar FILE (y NO mirar stdin)
#  - Si no hay -t ni -f -> leer stdin (si viene vacío, error)
if [[ -n "$TEXT" && -n "$FILE" ]]; then
  die "Elige SOLO una entrada: -t o -f (no ambas)."
fi

tmpwav="$(mktemp --tmpdir tts.XXXXXX.wav)"
trap 'rm -f "$tmpwav"' EXIT

if [[ -n "$TEXT" ]]; then
  printf "%s" "$TEXT" | "$PIPER_BIN" --model "$MODEL" --output_file "$tmpwav"

elif [[ -n "$FILE" ]]; then
  [[ -s "$FILE" ]] || die "El archivo no existe o está vacío: $FILE"
  "$PIPER_BIN" --model "$MODEL" --output_file "$tmpwav" < "$FILE"

else
  # stdin: debe tener contenido; si no, fallar claro
  if [[ -t 0 ]]; then
    usage
    die "No hay texto de entrada. Usa -t, -f o stdin."
  fi

  # Si stdin está cerrado/vacío, cat no dará nada; lo comprobamos
  input="$(cat)"
  if [[ -z "${input}" ]]; then
    usage
    die "No hay texto de entrada por stdin. Usa -t o -f."
  fi
  printf "%s" "$input" | "$PIPER_BIN" --model "$MODEL" --output_file "$tmpwav"
fi

[[ -s "$tmpwav" ]] || die "No se generó WAV temporal"

sox "$tmpwav" -r 8000 -c 1 -t ul "$OUT"
[[ -s "$OUT" ]] || die "No se generó UL: $OUT"
