cat > README.md <<'EOF'
# TTS ligero a G.711 µ-law (.ul) para radio / AllStarLink

Sistema de Text-to-Speech en español, ligero, offline y sin GPU, pensado para:

- Radioaficionados
- AllStarLink / Asterisk
- Partes meteorológicos automáticos
- Contenedores LXC con pocos recursos

Usa Piper TTS con una voz española ligera y genera salida final en:

- G.711 µ-law
- 8 kHz
- mono
- formato .ul

---

## Requisitos del sistema

- Debian 12 / Ubuntu 22.04 o compatible
- Arquitectura x86_64
- Sin GPU
- Acceso a Internet solo durante la instalación

No es necesario tener git instalado.

---

## Instalación (máquina nueva)

### 1. Descargar el script de instalación
```
wget https://raw.githubusercontent.com/ea6ami/tts-ul/main/install_piper_ul.sh

chmod +x install_piper_ul.sh

./install_piper_ul.sh
```
El script realiza:

- instalación de dependencias mínimas
- descarga del binario Piper
- descarga de una voz española ligera
- generación de un WAV de prueba
- conversión a G.711 µ-law (.ul)
- validación completa del sistema

Si termina sin errores, el sistema queda listo.

---

## Generar audio .ul

### Descargar el script de generación
```
wget https://raw.githubusercontent.com/ea6ami/tts-ul/main/tts_to_ul.sh

chmod +x tts_to_ul.sh
```
---

## Formas de uso

### Texto directo

./tts_to_ul.sh -t "Buenas tardes. Parte meteorológico automático." -o parte.ul

### Desde archivo de texto

./tts_to_ul.sh -f texto.txt -o parte.ul

### Desde stdin (scripts o cron)

echo "Mensaje automático del sistema." | ./tts_to_ul.sh -o mensaje.ul

---

## Resultado

El archivo generado (.ul) es:

- G.711 µ-law
- 8 kHz
- mono
- compatible directamente con AllStar / Asterisk

Puede copiarse directamente al directorio de sonidos usado por AllStar o Asterisk.

---

## Notas importantes

- El formato .ul es audio crudo, no WAV
- Es normal que sox muestre avisos al inspeccionarlo
- El sistema funciona offline una vez instalado

---

## Componentes usados

- Piper TTS (binario, sin Python)
- Voz española ligera es_ES-carlfm-x_low
- SoX para conversión a G.711 µ-law

---

## Licencia

Uso libre para sistemas de radio y automatización.
EOF
