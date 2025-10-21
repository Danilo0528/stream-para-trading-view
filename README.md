# 📺 TradingView 24/7 Streamer para Koyeb

Stream TradingView a YouTube/Twitch 24/7 usando el plan gratuito de Koyeb.

## 🚀 Deploy Rápido

1. **Fork este repo en GitHub**
2. **Obtén tu Stream Key** de YouTube/Twitch
3. **Deploy en Koyeb**:
   - Conecta tu repo de GitHub
   - Builder: Dockerfile
   - Instance: Eco (gratis)
   - Variables de entorno:
     ```
     RTMP_URL2=rtmp://a.rtmp.youtube.com/live2/TU_STREAM_KEY
     WEBSITE_URL=https://www.tradingview.com/chart/BTCUSD/
     ```

## ⚙️ Configuración

| Variable | Valor Recomendado |
|----------|-------------------|
| SCREEN_WIDTH | 1280 |
| SCREEN_HEIGHT | 720 |
| FRAME_RATE | 25 |
| VIDEO_BITRATE | 2500k |

## 📚 Más Info

Ver archivos completos de documentación en el repositorio.

---

Creado con ❤️ para la comunidad
