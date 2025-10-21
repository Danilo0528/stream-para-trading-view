#!/bin/bash

echo "🎬 Iniciando TradingView Streamer en Koyeb"
echo "=========================================="
echo "Plan: Gratuito (recursos limitados)"
echo "Optimizaciones: Activadas"
echo "=========================================="

# Función de limpieza
cleanup() {
    echo "🛑 Deteniendo servicios..."
    kill $FFMPEG_PID 2>/dev/null
    kill $BROWSER_PID 2>/dev/null
    kill $XVFB_PID 2>/dev/null
    kill $PULSEAUDIO_PID 2>/dev/null
    exit 0
}

trap cleanup SIGTERM SIGINT EXIT

# Configurar PulseAudio (sin audio real, solo dummy)
echo "🔊 Configurando audio virtual..."
pulseaudio -D --exit-idle-time=-1 2>/dev/null || true
sleep 1

# Cargar módulo de audio dummy
pactl load-module module-null-sink sink_name=dummy 2>/dev/null || true
pactl set-default-sink dummy 2>/dev/null || true

# Iniciar Xvfb (X virtual framebuffer) - Optimizado para bajos recursos
echo "🖥️  Iniciando servidor X virtual..."
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
Xvfb :99 -screen 0 ${SCREEN_WIDTH}x${SCREEN_HEIGHT}x16 \
    -nolisten tcp \
    -ac \
    +extension GLX \
    +render \
    -noreset &

XVFB_PID=$!
export DISPLAY=:99
sleep 5

# Verificar que Xvfb inició correctamente
if ! kill -0 $XVFB_PID 2>/dev/null; then
    echo "❌ Error: Xvfb no pudo iniciar"
    exit 1
fi
echo "✅ Servidor X iniciado (PID: $XVFB_PID)"

# Iniciar navegador con Puppeteer (en background)
echo "🌐 Iniciando navegador Chromium..."
node /app/streamer.js &
BROWSER_PID=$!
sleep 8

# Verificar que el navegador inició
if ! kill -0 $BROWSER_PID 2>/dev/null; then
    echo "❌ Error: Navegador no pudo iniciar"
    exit 1
fi
echo "✅ Navegador iniciado (PID: $BROWSER_PID)"

# Verificar configuración RTMP
if [ "$RTMP_URL2" == "rtmp://a.rtmp.youtube.com/live2/YOUR_STREAM_KEY" ]; then
    echo "⚠️  ADVERTENCIA: RTMP_URL2 usando valor por defecto"
    echo "    Configura tu Stream Key de YouTube en las variables de entorno"
fi

# Calcular bufsize (2x bitrate)
BITRATE_NUM=${VIDEO_BITRATE%k}
BUFSIZE=$((BITRATE_NUM * 2))k

echo ""
echo "📡 Configuración de Streaming"
echo "=========================================="
echo "URL Destino: $RTMP_URL2"
echo "Resolución: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
echo "Frame Rate: ${FRAME_RATE} fps"
echo "Video Bitrate: $VIDEO_BITRATE"
echo "Audio Bitrate: $AUDIO_BITRATE"
echo "Buffer Size: $BUFSIZE"
echo "=========================================="
echo ""

# Esperar un poco más para que todo esté estable
sleep 5

# Iniciar FFMPEG con configuración optimizada para Koyeb
echo "📹 Iniciando captura y streaming..."

ffmpeg -loglevel warning \
    -f x11grab \
    -video_size ${SCREEN_WIDTH}x${SCREEN_HEIGHT} \
    -framerate ${FRAME_RATE} \
    -i :99 \
    -f pulse -i default \
    -c:v libx264 \
    -preset ultrafast \
    -tune zerolatency \
    -profile:v baseline \
    -level 3.0 \
    -b:v ${VIDEO_BITRATE} \
    -maxrate ${VIDEO_BITRATE} \
    -bufsize ${BUFSIZE} \
    -pix_fmt yuv420p \
    -g $((FRAME_RATE * 2)) \
    -keyint_min ${FRAME_RATE} \
    -sc_threshold 0 \
    -c:a aac \
    -b:a ${AUDIO_BITRATE} \
    -ar 44100 \
    -ac 2 \
    -f flv \
    -flvflags no_duration_filesize \
    -reconnect 1 \
    -reconnect_at_eof 1 \
    -reconnect_streamed 1 \
    -reconnect_delay_max 5 \
    "$RTMP_URL2" &

FFMPEG_PID=$!
sleep 3

# Verificar que FFMPEG inició
if ! kill -0 $FFMPEG_PID 2>/dev/null; then
    echo "❌ Error: FFMPEG no pudo iniciar"
    echo "Verifica tu RTMP_URL2 y configuración"
    exit 1
fi

echo ""
echo "✅ STREAMING INICIADO EXITOSAMENTE"
echo "=========================================="
echo "PIDs de procesos activos:"
echo "  • Xvfb:    $XVFB_PID"
echo "  • Browser: $BROWSER_PID"
echo "  • FFmpeg:  $FFMPEG_PID"
echo "=========================================="
echo ""
echo "📊 Monitoreo activo iniciado..."
echo "   El sistema reiniciará automáticamente si detecta fallos"
echo ""

# Contador de reinicios
RESTART_COUNT=0
MAX_RESTARTS=5

# Loop de monitoreo y auto-recuperación
while true; do
    # Verificar FFmpeg
    if ! kill -0 $FFMPEG_PID 2>/dev/null; then
        echo "⚠️  FFmpeg detenido. Intentando reiniciar..."
        RESTART_COUNT=$((RESTART_COUNT + 1))
        
        if [ $RESTART_COUNT -ge $MAX_RESTARTS ]; then
            echo "❌ Demasiados reinicios ($RESTART_COUNT). Saliendo..."
            exit 1
        fi
        
        # Reiniciar FFmpeg
        ffmpeg -loglevel warning \
            -f x11grab \
            -video_size ${SCREEN_WIDTH}x${SCREEN_HEIGHT} \
            -framerate ${FRAME_RATE} \
            -i :99 \
            -f pulse -i default \
            -c:v libx264 \
            -preset ultrafast \
            -tune zerolatency \
            -b:v ${VIDEO_BITRATE} \
            -maxrate ${VIDEO_BITRATE} \
            -bufsize ${BUFSIZE} \
            -pix_fmt yuv420p \
            -g $((FRAME_RATE * 2)) \
            -c:a aac \
            -b:a ${AUDIO_BITRATE} \
            -ar 44100 \
            -f flv \
            -reconnect 1 \
            -reconnect_at_eof 1 \
            -reconnect_streamed 1 \
            -reconnect_delay_max 5 \
            "$RTMP_URL2" &
        FFMPEG_PID=$!
        echo "✅ FFmpeg reiniciado (PID: $FFMPEG_PID)"
    fi
    
    # Verificar navegador
    if ! kill -0 $BROWSER_PID 2>/dev/null; then
        echo "⚠️  Navegador detenido. Intentando reiniciar..."
        RESTART_COUNT=$((RESTART_COUNT + 1))
        
        if [ $RESTART_COUNT -ge $MAX_RESTARTS ]; then
            echo "❌ Demasiados reinicios ($RESTART_COUNT). Saliendo..."
            exit 1
        fi
        
        node /app/streamer.js &
        BROWSER_PID=$!
        echo "✅ Navegador reiniciado (PID: $BROWSER_PID)"
        sleep 5
    fi
    
    # Verificar Xvfb
    if ! kill -0 $XVFB_PID 2>/dev/null; then
        echo "❌ Xvfb detenido. Error crítico, saliendo..."
        exit 1
    fi
    
    # Reset contador si todo va bien por 5 minutos
    if [ $RESTART_COUNT -gt 0 ]; then
        RESET_TIME=$((RESET_TIME + 30))
        if [ $RESET_TIME -ge 300 ]; then
            RESTART_COUNT=0
            RESET_TIME=0
            echo "✅ Sistema estable, contador de reinicios reseteado"
        fi
    fi
    
    # Esperar antes del próximo check
    sleep 30
done