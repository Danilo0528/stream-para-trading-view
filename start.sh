#!/bin/bash

echo "🎬 Iniciando TradingView Streamer en Koyeb"
echo "=========================================="

cleanup() {
    echo "🛑 Deteniendo servicios..."
    kill $FFMPEG_PID 2>/dev/null
    kill $BROWSER_PID 2>/dev/null
    kill $XVFB_PID 2>/dev/null
    exit 0
}

trap cleanup SIGTERM SIGINT EXIT

echo "🔊 Configurando audio virtual..."
pulseaudio -D --exit-idle-time=-1 2>/dev/null || true
sleep 1
pactl load-module module-null-sink sink_name=dummy 2>/dev/null || true
pactl set-default-sink dummy 2>/dev/null || true

echo "🖥️  Iniciando servidor X virtual..."
Xvfb :99 -screen 0 ${SCREEN_WIDTH}x${SCREEN_HEIGHT}x16 \
    -nolisten tcp -ac +extension GLX +render -noreset -dpi 96 &
XVFB_PID=$!
export DISPLAY=:99
sleep 3

if ! kill -0 $XVFB_PID 2>/dev/null; then
    echo "❌ Error: Xvfb no pudo iniciar"
    exit 1
fi
echo "✅ Servidor X iniciado (PID: $XVFB_PID)"

echo "🌐 Iniciando navegador Chromium..."
node /app/streamer.js &
BROWSER_PID=$!
sleep 8

if ! kill -0 $BROWSER_PID 2>/dev/null; then
    echo "❌ Error: Navegador no pudo iniciar"
    exit 1
fi
echo "✅ Navegador iniciado (PID: $BROWSER_PID)"

BITRATE_NUM=${VIDEO_BITRATE%k}
BUFSIZE=$((BITRATE_NUM * 2))k

echo ""
echo "📡 Configuración de Streaming"
echo "=========================================="
echo "Resolución: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
echo "Frame Rate: ${FRAME_RATE} fps"
echo "Video Bitrate: $VIDEO_BITRATE"
echo "=========================================="
echo ""

sleep 5

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
    -reconnect 1 \
    -reconnect_at_eof 1 \
    -reconnect_streamed 1 \
    -reconnect_delay_max 5 \
    "$RTMP_URL" &

FFMPEG_PID=$!
sleep 3

if ! kill -0 $FFMPEG_PID 2>/dev/null; then
    echo "❌ Error: FFMPEG no pudo iniciar"
    exit 1
fi

echo ""
echo "✅ STREAMING INICIADO EXITOSAMENTE"
echo "=========================================="
echo ""

RESTART_COUNT=0
MAX_RESTARTS=5

while true; do
    if ! kill -0 $FFMPEG_PID 2>/dev/null; then
        echo "⚠️  FFmpeg detenido. Reiniciando..."
        RESTART_COUNT=$((RESTART_COUNT + 1))
        
        if [ $RESTART_COUNT -ge $MAX_RESTARTS ]; then
            echo "❌ Demasiados reinicios. Saliendo..."
            exit 1
        fi
        
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
            "$RTMP_URL" &
        FFMPEG_PID=$!
    fi
    
    if ! kill -0 $BROWSER_PID 2>/dev/null; then
        echo "⚠️  Navegador detenido. Reiniciando..."
        node /app/streamer.js &
        BROWSER_PID=$!
        sleep 5
    fi
    
    sleep 30
done
