FROM node:20-slim

# Variables de entorno para evitar prompts
ENV DEBIAN_FRONTEND=noninteractive \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=false \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# Instalar dependencias necesarias (optimizado para Koyeb)
RUN apt-get update && apt-get install -y \
    chromium \
    chromium-driver \
    xvfb \
    ffmpeg \
    pulseaudio \
    dbus-x11 \
    fonts-liberation \
    fonts-noto-color-emoji \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Crear usuario no-root (requerido por Koyeb)
RUN groupadd -r streamer && useradd -r -g streamer -G audio,video streamer \
    && mkdir -p /home/streamer/Downloads /app \
    && chown -R streamer:streamer /home/streamer /app

# Cambiar a usuario no-root
USER streamer
WORKDIR /app

# Copiar package.json primero (mejor cache de Docker)
COPY --chown=streamer:streamer package*.json ./

# Instalar dependencias de Node
RUN npm ci --only=production

# Copiar código fuente
COPY --chown=streamer:streamer . .

# Hacer ejecutables los scripts
USER root
RUN chmod +x /app/start.sh
USER streamer

# Variables de entorno con valores por defecto
ENV DISPLAY=:99 \
    WEBSITE_URL=https://www.tradingview.com/chart/ \
    RTMP_URL2=rtmp://a.rtmp.youtube.com/live2/6w9r-0vwh-5p44-wctw-0zwb \
    SCREEN_WIDTH=1280 \
    SCREEN_HEIGHT=720 \
    FRAME_RATE=25 \
    VIDEO_BITRATE=2500k \
    AUDIO_BITRATE=96k \
    KOYEB_OPTIMIZED=true

# Puerto para health check de Koyeb
EXPOSE 8080

# Comando de inicio
CMD ["/app/start.sh"]
