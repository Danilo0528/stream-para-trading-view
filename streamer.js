const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');

puppeteer.use(StealthPlugin());

const websiteUrl = process.env.WEBSITE_URL || 'https://www.tradingview.com/chart/';
const screenWidth = parseInt(process.env.SCREEN_WIDTH) || 1280;
const screenHeight = parseInt(process.env.SCREEN_HEIGHT) || 720;

async function startBrowser() {
    console.log('🚀 Iniciando navegador headless en Koyeb...');
    console.log(`📺 URL: ${websiteUrl}`);
    console.log(`📐 Resolución: ${screenWidth}x${screenHeight}`);

    const browser = await puppeteer.launch({
        headless: true,
        executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/bin/chromium',
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--single-process',
            '--disable-gpu',
            '--window-size=' + screenWidth + ',' + screenHeight,
            '--disable-background-timer-throttling',
            '--disable-backgrounding-occluded-windows',
            '--disable-renderer-backgrounding',
            '--disable-features=TranslateUI',
            '--disable-blink-features=AutomationControlled',
            '--disable-software-rasterizer',
            '--disable-extensions',
            '--mute-audio',
            '--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        ],
        defaultViewport: {
            width: screenWidth,
            height: screenHeight
        }
    });

    const page = await browser.newPage();
    await page.setViewport({ width: screenWidth, height: screenHeight });

    await page.setRequestInterception(true);
    page.on('request', (request) => {
        const resourceType = request.resourceType();
        if (['font', 'media'].includes(resourceType)) {
            request.abort();
        } else {
            request.continue();
        }
    });

    page.on('dialog', async dialog => {
        console.log('🔔 Dialog detectado:', dialog.message());
        await dialog.dismiss();
    });

    page.on('error', error => {
        console.error('❌ Error en página:', error.message);
    });

    page.on('pageerror', error => {
        console.error('❌ Error JS en página:', error.message);
    });

    console.log('🌐 Navegando a la URL...');
    try {
        await page.goto(websiteUrl, {
            waitUntil: 'domcontentloaded',
            timeout: 60000
        });
        console.log('✅ Página cargada exitosamente');
    } catch (error) {
        console.error('❌ Error al cargar página:', error.message);
        throw error;
    }

    await page.waitForTimeout(5000);

    try {
        await page.evaluate(() => {
            const closeButtons = document.querySelectorAll('[data-name="close"], .close, .tv-dialog__close, [aria-label="Close"]');
            closeButtons.forEach(btn => {
                try { btn.click(); } catch (e) {}
            });
            
            const hideSelectors = [
                '.tv-header',
                '.tv-floating-toolbar',
                '.tv-feed-widget',
                '.tv-social-row',
                '[data-role="toast"]'
            ];
            
            hideSelectors.forEach(selector => {
                const elements = document.querySelectorAll(selector);
                elements.forEach(el => {
                    if (el) el.style.display = 'none';
                });
            });

            const style = document.createElement('style');
            style.textContent = `
                .tv-header { display: none !important; }
                .tv-floating-toolbar { display: none !important; }
                .layout__area--center { height: 100vh !important; }
            `;
            document.head.appendChild(style);
            
            console.log('✅ Interfaz optimizada');
        });
    } catch (error) {
        console.log('⚠️ No se pudo optimizar completamente:', error.message);
    }

    console.log('♻️ Iniciando heartbeat...');
    setInterval(async () => {
        try {
            await page.evaluate(() => {
                if (window.localStorage) {
                    window.localStorage.setItem('lastActivity', Date.now().toString());
                }
            });
        } catch (error) {
            console.error('❌ Error en heartbeat:', error.message);
        }
    }, 60000);

    console.log('✅ Navegador listo y estable');
    return { browser, page };
}

process.on('unhandledRejection', (error) => {
    console.error('❌ Error no manejado:', error);
    process.exit(1);
});

process.on('SIGTERM', () => {
    console.log('⚠️ Recibida señal SIGTERM, cerrando...');
    process.exit(0);
});

startBrowser().catch(error => {
    console.error('❌ Error fatal al iniciar:', error);
    process.exit(1);
});
