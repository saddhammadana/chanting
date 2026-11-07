#!/usr/bin/env node
// Captures the Play Store screenshots from the release WEB build into
// docs/store/assets/screenshots*/. See docs/store/screenshots.md.
//
//   flutter build web --release
//   npm i --prefix /tmp/chanting-shots playwright-core@1.38.1
//   NODE_PATH=/tmp/chanting-shots/node_modules node tool/store/capture_screenshots_web.cjs [out_dir]
//
// It drives the app by URL and by its accessibility tree (button names), not by
// tap coordinates, so a layout change does not send a tap to the wrong place.
//
// Four device profiles, one per Play screenshot slot. The phone is portrait at
// exactly 1080x1920; the three large screens are landscape at exactly 16:9,
// which is what Play asks of its tablet and Chromebook slots.
//
//   DEVICE=tablet   only the profiles whose name contains that text
//   ONLY=05         only the shots whose name contains that text
const fs = require('fs');
const http = require('http');
const path = require('path');
const { chromium } = require('playwright-core');

const root = path.resolve(__dirname, '../..');
const web = path.join(root, 'build/web');
const out = path.resolve(process.argv[2] || path.join(root, 'docs/store/assets'));
const chrome =
  process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port = 8791;

// `wheel` is how far the continuous-reading shot scrolls to land on the seam
// between two prayers: a wider column wraps fewer lines, so each profile needs
// its own distance. `lift` is for a page that is one composition rather than a
// list — the share card — which a short landscape viewport cuts off at the
// bottom; scrolling by that much brings the whole card into frame.
const devices = [
  { name: 'phone', dir: 'screenshots', width: 432, height: 768, scale: 2.5, wheel: 620, lift: 0 },
  { name: 'tablet-7', dir: 'screenshots-tablet-7', width: 960, height: 540, scale: 2, wheel: 700, lift: 110 },
  { name: 'tablet-10', dir: 'screenshots-tablet-10', width: 1280, height: 720, scale: 2, wheel: 560, lift: 0 },
  { name: 'desktop', dir: 'screenshots-desktop', width: 1600, height: 900, scale: 1.5, wheel: 700, lift: 0 },
];

const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.png': 'image/png', '.webp': 'image/webp',
  '.wasm': 'application/wasm', '.ttf': 'font/ttf', '.otf': 'font/otf',
  '.mp3': 'audio/mpeg', '.css': 'text/css', '.ico': 'image/x-icon',
};
const server = http.createServer((req, res) => {
  let file = path.join(web, decodeURIComponent(req.url.split('?')[0]));
  if (!file.startsWith(web)) return res.writeHead(403).end();
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  if (!fs.existsSync(file)) return res.writeHead(404).end();
  res.writeHead(200, { 'content-type': types[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});

// Today at 07:30 local time, so every shot shows the same greeting, the
// morning service on the goal card, and "today" for the practice ring.
const morning = new Date();
morning.setHours(7, 30, 0, 0);
const today = `${morning.getFullYear()}-${String(morning.getMonth() + 1).padStart(2, '0')}-${String(morning.getDate()).padStart(2, '0')}`;

// What a person who has used the app for a while has stored. Never a fresh
// install: that opens the tour and the goal page instead of the app.
const basePrefs = {
  welcome_seen_version: 999,
  goal_prompt_seen: true,
  practice_goal_minutes: 15,
  practice_seconds: [`${today}:540`],
  last_read_id: 'jaya-paritta',
  favorite_ids: ['jaya-paritta', 'ratanattaya-vandana'],
};
const set = {
  id: 'store-set',
  name: 'สวดก่อนนอน',
  prayerIds: ['ratanattaya-vandana', 'pubba-bhaga-namakara', 'jaya-paritta'],
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function open(browser, dev, route, prefs = {}) {
  const context = await browser.newContext({
    viewport: { width: dev.width, height: dev.height },
    deviceScaleFactor: dev.scale,
    locale: 'th-TH',
    colorScheme: 'light',
    // Android in every profile, Chromebook included: what Play lists is the
    // Android app, so desktop scrollbars and hover chrome have no place in it.
    hasTouch: true,
    isMobile: true,
  });
  await context.addInitScript(
    ({ prefs, at }) => {
      const offset = at - Date.now();
      const now = Date.now.bind(Date);
      Date.now = () => now() + offset;
      for (const [key, value] of Object.entries(prefs)) {
        localStorage.setItem(`flutter.${key}`, JSON.stringify(value));
      }
    },
    { prefs: { ...basePrefs, ...prefs }, at: morning.getTime() },
  );
  const page = await context.newPage();
  await page.goto(`http://localhost:${port}/#${route}`);
  await page.waitForSelector('flutter-view, flt-glass-pane', { timeout: 60000 });
  await sleep(6000); // fonts, artwork and the splash's fade-out
  return page;
}

// Flutter builds its accessibility tree only when asked.
async function semantics(page) {
  await page.evaluate(() =>
    document.querySelector('flt-semantics-placeholder')?.click(),
  );
  await sleep(800);
}

async function tap(page, name) {
  const target = page.getByRole('button', { name }).first();
  await target.waitFor({ timeout: 10000 });
  await target.click();
  await sleep(1500);
}

// For nodes Playwright will not click because Flutter's semantics overlay is
// transparent: find the node, then touch the screen where it is.
async function tapItem(page, role, label) {
  const at = await page.evaluate(
    ({ role, label }) => {
      const node = [...document.querySelectorAll(`flt-semantics[role="${role}"]`)].find(
        (e) => (e.getAttribute('aria-label') || e.textContent).includes(label),
      );
      if (!node) return null;
      const r = node.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    },
    { role, label },
  );
  if (!at) throw new Error(`no ${role} labelled "${label}"`);
  await page.touchscreen.tap(at.x, at.y);
  await sleep(1500);
}

// Away from whatever was just pressed, so no tooltip or hover is left in frame.
async function restPointer(page, dev) {
  await page.mouse.move(dev.width / 2, dev.height * 0.45);
  await sleep(2500);
}

const shots = [
  ['01-home', '/', {}],
  ['02-categories', '/categories', {}],
  [
    '03-reading',
    '/prayer/ratanattaya-vandana?section=tham-wat-chao',
    { show_roman_default: true, show_meaning_default: true, inline_translation: true },
  ],
  [
    '04-continuous',
    '/prayer/ratanattaya-vandana?section=tham-wat-chao',
    { continuous_reading: true },
    async (page, dev) => {
      // Down to where one prayer ends and the next begins.
      await page.mouse.move(dev.width / 2, dev.height / 2);
      await page.mouse.wheel(0, dev.wheel);
      await sleep(1500);
    },
  ],
  [
    '05-mala',
    '/prayer/jaya-paritta?section=bot-suat-phiset',
    { mala_count: 21, mala_target: 108 },
    async (page, dev) => {
      await semantics(page);
      await tap(page, 'ตัวเลือกเพิ่มเติม');
      await tapItem(page, 'menuitem', 'ตัวนับรอบสวด');
      // The click above left the menu button's tooltip up; let it go.
      await restPointer(page, dev);
      await sleep(1500);
    },
  ],
  ['06-settings', '/settings/reading', {}],
  [
    '07-playlist-share',
    '/playlists/store-set/share',
    { playlists: [JSON.stringify(set)] },
    async (page, dev) => {
      if (!dev.lift) return;
      await page.mouse.move(dev.width / 2, dev.height / 2);
      await page.mouse.wheel(0, dev.lift);
      await sleep(1500);
    },
  ],
  [
    '08-meditation',
    '/meditation',
    { meditation_minutes: 10 },
  ],
];

(async () => {
  if (!fs.existsSync(path.join(web, 'index.html'))) {
    throw new Error('no build/web — run `flutter build web --release` first');
  }
  await new Promise((r) => server.listen(port, r));
  const browser = await chromium.launch({ executablePath: chrome });
  try {
    const only = process.env.ONLY;
    const wanted = process.env.DEVICE;
    for (const dev of devices) {
      if (wanted && !dev.name.includes(wanted)) continue;
      const dir = path.join(out, dev.dir);
      fs.mkdirSync(dir, { recursive: true });
      console.log(`${dev.name} (${dev.width * dev.scale}x${dev.height * dev.scale})`);
      for (const [name, route, prefs, act] of shots) {
        if (only && !name.includes(only)) continue;
        const page = await open(browser, dev, route, prefs);
        if (act) await act(page, dev);
        await page.screenshot({ path: path.join(dir, `${name}.png`) });
        await page.context().close();
        console.log(`  ${dev.dir}/${name}.png`);
      }
    }
  } finally {
    await browser.close();
    server.close();
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
