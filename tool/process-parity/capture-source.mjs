// User-level Source app navigation with per-animation-frame DOM observations.
// The API gate is the only manipulated runtime input; Source stores stay real.
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';
const [fixturePath, out, base = 'http://127.0.0.1:15413', theme = 'brutal', form = 'desktop'] = process.argv.slice(2);
if (!fixturePath || !out) throw new Error('capture-source.mjs FIXTURE OUTPUT [BASE THEME desktop|mobile]');
const source = process.env.RAFT_SOURCE ?? '/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source';
const { chromium } = createRequire(`${source}/packages/web/package.json`)('@playwright/test');
const fixtureBytes = readFileSync(fixturePath), fixture = JSON.parse(fixtureBytes), flow = fixture.process;
mkdirSync(out, { recursive: false });
const viewport = form === 'mobile' ? { width: 390, height: 844 } : { width: 1440, height: 900 };
const prefs = theme === 'brutal' ? { mode: 'light', lightThemeId: 'brutal', darkThemeId: 'elegant' }
  : { mode: theme === 'elegant-dark' ? 'dark' : 'light', lightThemeId: 'elegant', darkThemeId: 'elegant' };
const browser = await chromium.launch({ executablePath: process.env.RAFT_CHROMIUM ?? `${process.env.HOME}/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome` });
const context = await browser.newContext({ viewport, locale: 'en-US', timezoneId: 'Asia/Shanghai', permissions: ['notifications'], extraHTTPHeaders: { 'X-Process-Provider': `source-${form}-${theme}` } });
const page = await context.newPage();
let renderActive = true;
const renderFrames = [], renderDir = resolve(out, 'renderer-frames');
mkdirSync(renderDir);
const cdp = await context.newCDPSession(page);
cdp.on('Page.screencastFrame', event => {
  cdp.send('Page.screencastFrameAck', { sessionId: event.sessionId }).catch(() => {});
  if (!renderActive) return;
  const index = renderFrames.length;
  const name = `${String(index).padStart(4, '0')}.png`;
  writeFileSync(resolve(renderDir, name), Buffer.from(event.data, 'base64'));
  renderFrames.push({ index, file: name, at: performance.now(), wallTime: Date.now(), metadata: event.metadata });
});
await cdp.send('Page.startScreencast', { format: 'png', everyNthFrame: 1 });
const failures = [], stages = [];
const initialRuntime = await (await fetch(`${base}/__process/state`)).json();
const requestStart = initialRuntime.requests.at(-1)?.seq ?? 0;
if (initialRuntime.fixtureSha !== createHash('sha256').update(fixtureBytes).digest('hex')) throw new Error('Runtime and capture fixture hashes differ');
page.on('pageerror', error => failures.push({ at: performance.now(), kind: 'pageerror', message: String(error) }));
await page.routeWebSocket(/socket\.io/, ws => ws.close());
await context.addInitScript(({ prefs, flow }) => {
  localStorage.setItem('slock_access_token', 'fixture-access-token');
  localStorage.setItem('slock_refresh_token', 'fixture-refresh-token');
  localStorage.setItem('slock-theme-preferences-v2', JSON.stringify(prefs));
  localStorage.setItem('slock_locale', 'en');
  window.__processFrames = [];
  window.__processStage = 'bootstrap';
  const visible = el => {
    if (!el) return null;
    const r = el.getBoundingClientRect(), css = getComputedStyle(el);
    if (!r.width || !r.height || css.visibility === 'hidden' || css.display === 'none') return null;
    return { x: r.x, y: r.y, width: r.width, height: r.height };
  };
  const rects = selector => [...document.querySelectorAll(selector)].map(el => ({ text: el.textContent.trim(), rect: visible(el), selected: el.getAttribute('aria-selected') ?? el.getAttribute('data-active') })).filter(x => x.rect);
  const message = id => {
    const el = document.getElementById(`message-${id}`), rect = visible(el);
    if (!rect) return null;
    const scroller = el.closest('[data-testid="message-scroller"]');
    const view = visible(scroller);
    const inView = view && rect.y < view.y + view.height && rect.y + rect.height > view.y;
    return { rect, focusRect: visible(el.closest('[data-timeline-message-id]')), view, inView: Boolean(inView), highlighted: el.getAttribute('data-highlighted') === 'true' };
  };
  function frame(at) {
    window.__processFrames.push({ frame: window.__processFrames.length, at, wallTime: performance.timeOrigin + at, stage: window.__processStage, url: location.pathname + location.search,
      headers: rects('[data-slot="panel-header"]'), tabs: rects('[data-testid^="panel-tab-"]'),
      composer: rects('[data-testid="composer-textarea"]'), surfaces: rects('[data-testid="message-content-surface"]'),
      accepted: message(flow.acceptedMessageId), target: message(flow.targetMessageId),
      loading: [...document.querySelectorAll('[data-testid="message-content-surface"]')].filter(el => visible(el)).some(el => /^Loading[.\s]*$/.test(el.textContent.trim())),
    });
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}, { prefs, flow });
const control = async (action, key) => {
  const response = await fetch(`${base}/__process/${action}?key=${encodeURIComponent(key)}`);
  if (!response.ok) throw new Error(`control ${action} failed: ${response.status}`);
  return response.json();
};
const waitHeld = async key => {
  const deadline = performance.now() + 15000;
  while (performance.now() < deadline) {
    const state = await (await fetch(`${base}/__process/state`)).json();
    if (state.held.some(held => held.key === key && held.count > 0)) return state;
    await new Promise(r => setTimeout(r, 50));
  }
  throw new Error(`Source did not request held endpoint: ${key}`);
};
const stage = async name => {
  await page.evaluate(name => { window.__processStage = name; }, name);
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  const state = await page.evaluate(() => window.__processFrames.at(-1));
  stages.push({ name, frame: state });
  await page.screenshot({ path: resolve(out, `${String(stages.length).padStart(2, '0')}-${name}.png`) });
  return state;
};
try {
  await page.goto(base + flow.sourceRoute, { waitUntil: 'domcontentloaded' });
  await page.addStyleTag({ content: '#react-scan-root, body > div.ph-no-capture { display:none!important; }' });
  await page.locator(`#message-${flow.acceptedMessageId}`).waitFor({ state: 'visible', timeout: 30000 });
  await stage('accepted-tail');
  if (form === 'desktop') await page.getByTestId('left-rail-tab-activity').click();
  else {
    await page.getByTestId('chat-mobile-back').click();
    await page.getByRole('button', { name: /^Activity(?:\s+\d+)?$/ }).last().click();
  }
  await page.getByTestId('inbox-row').filter({ hasText: 'android-artifacts' }).waitFor({ state: 'visible' });
  await stage('activity');
  await control('arm', flow.hold);
  await page.getByTestId('inbox-row').filter({ hasText: 'android-artifacts' }).click();
  const heldState = await waitHeld(flow.hold);
  const heldRequest = heldState.requests.filter(row => row.kind === 'request' && row.key === flow.hold && row.seq > requestStart).at(-1);
  if (!heldRequest) throw new Error('No current capture-owned held request');
  const pending = await stage('pending-context');
  if (!pending.accepted?.inView) throw new Error('Source pending same-channel context did not retain accepted rows');
  if (pending.target?.inView) throw new Error('Source target visible before fixture response');
  if (!pending.headers.length || !pending.composer.length) throw new Error('Source pending context lost header/composer');
  const pendingReads = (await (await fetch(`${base}/__process/state`)).json()).requests.filter(row => row.kind === 'request' && row.key === `POST /channels/${flow.channelId}/read` && row.seq > heldRequest.seq);
  if (pendingReads.some(row => row.body?.seq > flow.acceptedSeq)) throw new Error('Read frontier advanced into unaccepted context');
  await control('release', flow.hold);
  await page.locator(`#message-${flow.targetMessageId}`).waitFor({ state: 'visible' });
  const accepted = await stage('accepted-context');
  if (!accepted.target?.inView || !accepted.target.highlighted) throw new Error('Source accepted target not visible/highlighted');
  const centerError = Math.abs(accepted.target.focusRect.y + accepted.target.focusRect.height / 2 - (accepted.target.view.y + accepted.target.view.height / 2));
  if (centerError > 1) throw new Error(`Source target center differs by ${centerError}px`);
  await page.waitForTimeout(2100);
  const expired = await stage('highlight-expired');
  if (expired.target?.highlighted) throw new Error('Source highlight did not expire after 2s');
} catch (error) {
  failures.push({ at: performance.now(), kind: 'flow', message: String(error), stage: stages.at(-1)?.name ?? 'bootstrap' });
  await page.screenshot({ path: resolve(out, 'failure.png') }).catch(() => {});
  process.exitCode = 1;
} finally {
  await cdp.send('Page.stopScreencast').catch(() => {});
  renderActive = false;
  await cdp.detach();
  writeFileSync(resolve(out, 'renderer-frames.json'), JSON.stringify(renderFrames, null, 2));
  const frames = await page.evaluate(() => window.__processFrames ?? []).catch(() => []);
  const state = await (await fetch(`${base}/__process/state`)).json();
  writeFileSync(resolve(out, 'frames.jsonl'), frames.map(frame => JSON.stringify(frame)).join('\n') + '\n');
  writeFileSync(resolve(out, 'result.json'), JSON.stringify({ provider: 'Source real App', sourceHead: '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6', sourceInputSha: initialRuntime.sourceInputSha ?? null, runtimeSha: initialRuntime.runtimeSha ?? null, runnerSha: createHash('sha256').update(readFileSync(new URL(import.meta.url))).digest('hex'), fixtureSha: createHash('sha256').update(fixtureBytes).digest('hex'), viewport, theme, form, rendererFrameCount: renderFrames.length, stages, failures, requests: state.requests.filter(row => row.seq > requestStart), result: failures.length ? 'FAIL' : 'PASS' }, null, 2));
  console.log(JSON.stringify({ result: failures.length ? 'FAIL' : 'PASS', out, frames: frames.length, failures }));
  await browser.close();
}
