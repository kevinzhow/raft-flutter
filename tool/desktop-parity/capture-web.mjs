// Captures every case in docs/desktop-cases.json from the REAL Raft Web app
// (served by web-runtime.mjs against the shared fixture) and writes the
// official visual-testing provider layout:
//   <out>/react/<caseId>.png
//   <out>/react/<caseId>.metadata.json
//
// Usage: node capture-web.mjs [--only substr[,substr]] [--out dir] [--base url]
// Optional --regions-out dir writes separate read-only layout diagnostics.
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { mkdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { createHash } from 'node:crypto';
import { measureDesktopRegions } from './measure-regions.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, '../..');
const sourceRoot = process.env.RAFT_SOURCE ??
  '/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source';
const require = createRequire(`${sourceRoot}/packages/web/package.json`);
const { chromium } = require('@playwright/test');

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : fallback;
};
const only = opt('only', '').split(',').filter(Boolean);
const regionsRoot = opt('regions-out', null);
if (regionsRoot) {
  if (existsSync(resolve(regionsRoot))) throw new Error('Choose a fresh --regions-out directory; preserve previous DOM evidence.');
  mkdirSync(resolve(regionsRoot), { recursive: true });
}
const outRoot = resolve(opt('out', resolve(repo, '.local/desktop-parity/visual-testing-results')));
const portFile = resolve(repo, '.local/desktop-parity/web-runtime.port');
const base = opt('base', `http://127.0.0.1:${existsSync(portFile) ? readFileSync(portFile, 'utf8').trim() : 15260}`);
const manifest = JSON.parse(readFileSync(resolve(repo, 'docs/desktop-cases.json'), 'utf8'));
const fixturePath = resolve(here, 'desktop-fixture.json');
const fixtureSha = createHash('sha256').update(readFileSync(fixturePath)).digest('hex');
const outDir = resolve(outRoot, 'react');
mkdirSync(outDir, { recursive: true });

const themePrefs = {
  brutal: { mode: 'light', lightThemeId: 'brutal', darkThemeId: 'elegant' },
  'elegant-light': { mode: 'light', lightThemeId: 'elegant', darkThemeId: 'elegant' },
  'elegant-dark': { mode: 'dark', lightThemeId: 'elegant', darkThemeId: 'elegant' },
};

// Dev-only overlays injected by the Vite dev server (react-scan / react-grab).
// They are not product UI and do not exist in production builds.
const HIDE_DEV_TOOLS_CSS = `#react-scan-root, body > div.ph-no-capture { display: none !important; }`;
// Freeze caret blink and transitions so hover/focus captures are stable.
const STABILIZE_CSS = `*, *::before, *::after { caret-color: transparent !important; transition-duration: 0s !important; animation-duration: 0s !important; animation-delay: 0s !important; }`;

const browser = await chromium.launch({
  executablePath: process.env.RAFT_CHROMIUM ?? `${process.env.HOME}/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome`,
});

async function runStep(page, step) {
  const target = () => {
    if (step.testId) return page.getByTestId(step.testId).first();
    if (step.role) return page.getByRole(step.role, { name: step.name, exact: step.exact ?? false }).nth(step.nth ?? 0);
    if (step.label) return page.getByLabel(step.label, { exact: step.exact ?? false }).nth(step.nth ?? 0);
    if (step.text) return page.getByText(step.text, { exact: step.exact ?? false }).nth(step.nth ?? 0);
    if (step.selector) return page.locator(step.selector).nth(step.nth ?? 0);
    throw new Error(`step has no target: ${JSON.stringify(step)}`);
  };
  switch (step.action) {
    case 'goto': await page.goto(base + step.path); break;
    case 'click': await target().click(); break;
    case 'hover': await target().hover(); break;
    case 'focus': await target().click(); break;
    case 'type': await target().fill(step.value); break;
    case 'press': await page.keyboard.press(step.key); break;
    case 'waitFor': await target().waitFor({ state: step.state ?? 'visible', timeout: step.timeout ?? 15000 }); break;
    case 'wait': await page.waitForTimeout(step.ms); break;
    case 'mouse': await page.mouse.move(step.x, step.y); break;
    default: throw new Error(`unknown step ${step.action}`);
  }
}

const results = [];
for (const visualCase of manifest.cases) {
  if (only.length && !only.some((s) => visualCase.id.includes(s))) continue;
  const variant = visualCase.variants[0];
  const web = variant.props.web ?? {};
  const { width, height } = visualCase.viewport;
  const context = await browser.newContext({
    viewport: { width, height },
    deviceScaleFactor: visualCase.viewport.density ?? 1,
    locale: 'en-US',
    timezoneId: 'Asia/Shanghai',
    // Desktop clients do not show the web push-permission prompt banner.
    permissions: ['notifications'],
    reducedMotion: 'reduce',
  });
  await context.addInitScript(({ prefs }) => {
    localStorage.setItem('slock_access_token', 'fixture-access-token');
    localStorage.setItem('slock_refresh_token', 'fixture-refresh-token');
    localStorage.setItem('slock-theme-preferences-v2', JSON.stringify(prefs));
    localStorage.setItem('slock_locale', 'en');
  }, { prefs: themePrefs[visualCase.theme] });
  const page = await context.newPage();
  // No realtime backend: the socket is refused deterministically.
  await page.routeWebSocket(/socket\.io/, (ws) => ws.close());
  // Loading-state cases: the listed API calls never answer.
  for (const held of variant.props.hold ?? []) {
    const [method, path] = held.split(' ');
    await page.route((url) => url.pathname === `/api${path}`, (route) => {
      if (route.request().method() !== method) return route.fallback();
      // Intentionally never fulfilled.
    });
  }
  const imagePath = resolve(outDir, `${visualCase.id}.png`);
  const started = Date.now();
  try {
    await page.goto(base + variant.props.route, { waitUntil: 'domcontentloaded' });
    await page.addStyleTag({ content: HIDE_DEV_TOOLS_CSS + STABILIZE_CSS }).catch(() => {});
    for (const step of web.ready ?? []) await runStep(page, step);
    // No socket: the shell's realtime-bootstrap fallback (agents, machines,
    // sidebar-order, followed threads) fires 2s after mount
    // (store/socketBridge.ts:328-375). Wait past it so agent avatars/labels
    // are loaded, matching Flutter which loads them during bootstrap.
    await page.waitForTimeout(2600);
    for (const step of web.steps ?? []) await runStep(page, step);
    // Click-driven cases: park the pointer on inert header chrome so the
    // clicked row does not keep a hover state (Flutter taps leave no hover).
    if (!(web.steps ?? []).some((s) => s.action === 'hover')) {
      await page.mouse.move(Math.round(width * 0.55), 2);
    }
    await page.addStyleTag({ content: HIDE_DEV_TOOLS_CSS + STABILIZE_CSS });
    await page.waitForTimeout(web.settleMs ?? 800);
    // Real raft-ui faces must be in use (production Web loads them from
    // Google Fonts). Unlike the official React provider spec, nothing here
    // stubs the font request; verify instead of trusting it.
    const fonts = await page.evaluate(async () => {
      await document.fonts.ready;
      const raft = ['Hanken Grotesk', 'Inter', 'Geist', 'Geist Mono'];
      // Primary family of every element that renders its own text.
      const used = new Set();
      for (const el of document.querySelectorAll('body *')) {
        if (![...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim())) continue;
        const r = el.getBoundingClientRect();
        if (!r.width || !r.height) continue;
        used.add(getComputedStyle(el).fontFamily.split(',')[0].trim().replaceAll('"', ''));
      }
      const required = raft.filter((f) => used.has(f));
      for (const f of required) await document.fonts.load(`16px "${f}"`);
      const loaded = [...new Set([...document.fonts].filter((f) => f.status === 'loaded').map((f) => f.family.replaceAll('"', '')))];
      return { used: [...used], required, loaded, missing: required.filter((f) => !loaded.includes(f)), body: getComputedStyle(document.body).fontFamily };
    });
    if (!fonts.required.length || fonts.missing.length) {
      throw new Error(`raft-ui fonts not in use/loaded: required=${fonts.required} missing=${fonts.missing} used=${fonts.used}`);
    }
    const regions = await page.evaluate((probes) => {
      const out = {};
      for (const [name, sel] of Object.entries(probes)) {
        const el = document.querySelector(sel);
        if (!el) continue;
        const r = el.getBoundingClientRect();
        if (r.width && r.height) out[name] = { x: r.x, y: r.y, width: r.width, height: r.height };
      }
      return out;
    }, {
      'rail': '[data-testid="workspace-left-rail"]',
      'rail.first': '[data-testid="left-rail-tab-search"]',
      'sidebar': '[data-testid="sidebar-root"]',
      'thread': '[data-testid="thread-side-column"]',
      'threadMain': '[data-testid="thread-main-column"]',
      'notificationCenter': '[data-testid="notification-center"]',
      'reactionPicker': '[data-message-affordance="reaction-picker"]',
      'composer': '[data-testid="composer-textarea"]',
      'message.agent-reply': '#message-msg-agent-reply',
    });
    if (regionsRoot) {
      const measured = await page.evaluate(measureDesktopRegions);
      writeFileSync(resolve(regionsRoot, `${visualCase.id}.regions.json`), JSON.stringify({
        ...measured, caseId: visualCase.id, theme: visualCase.theme,
        route: variant.props.route, url: page.url(), fixtureSha256: fixtureSha,
        sourceCommit: '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
        capturedAt: new Date().toISOString(),
      }, null, 2));
    }
    await page.screenshot({ path: imagePath });
    writeFileSync(resolve(outDir, `${visualCase.id}.metadata.json`), JSON.stringify({
      provider: 'react',
      providerType: 'react-playwright',
      source: 'raft-web-real-app',
      caseId: visualCase.id,
      image: `visual-testing-results/react/${visualCase.id}.png`,
      viewport: visualCase.viewport,
      theme: visualCase.theme,
      route: variant.props.route,
      url: page.url(),
      selector: 'viewport',
      crop: { mode: 'viewport', contract: visualCase.capture.contract, rect: { x: 0, y: 0, width, height }, targetRect: { x: 0, y: 0, width, height }, outset: null },
      regions,
      fonts,
      fixtureSha256: fixtureSha,
      sourceCommit: '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
      capturedAt: new Date().toISOString(),
    }, null, 2));
    results.push({ id: visualCase.id, ok: true, ms: Date.now() - started });
    console.log(`ok   ${visualCase.id} (${Date.now() - started}ms)`);
  } catch (error) {
    await page.screenshot({ path: resolve(outDir, `${visualCase.id}.failure.png`) }).catch(() => {});
    writeFileSync(resolve(outDir, `${visualCase.id}.failure.json`), JSON.stringify({ caseId: visualCase.id, error: String(error?.message ?? error), url: page.url() }, null, 2));
    results.push({ id: visualCase.id, ok: false, error: String(error?.message ?? error).split('\n')[0] });
    console.log(`FAIL ${visualCase.id}: ${String(error?.message ?? error).split('\n')[0]}`);
  }
  await context.close();
}
await browser.close();
writeFileSync(resolve(outDir, '_capture-summary.json'), JSON.stringify({ at: new Date().toISOString(), base, fixtureSha256: fixtureSha, results }, null, 2));
const failed = results.filter((r) => !r.ok).length;
console.log(`react: ${results.length - failed}/${results.length} captured`);
process.exit(failed ? 1 : 0);
