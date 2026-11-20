// Rasteriza SVGs com o Chromium (suporta filtros: textura de tinta, traço tremido).
// Uso: node tools/render_svg.js jobs.json   (jobs = [{svg, png, w, h, scale}])
const fs = require('fs');
const { chromium } = require('playwright');
(async () => {
  const jobs = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const browser = await chromium.launch();
  const ctxs = {};
  for (const j of jobs) {
    const key = j.scale;
    if (!ctxs[key]) ctxs[key] = await (await browser.newContext({ deviceScaleFactor: j.scale })).newPage();
    const page = ctxs[key];
    await page.setViewportSize({ width: j.w, height: j.h });
    const svg = fs.readFileSync(j.svg, 'utf8');
    await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
    await page.screenshot({ path: j.png, omitBackground: true, clip: { x: 0, y: 0, width: j.w, height: j.h } });
  }
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
