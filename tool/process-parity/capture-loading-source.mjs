// Real pinned Source App: HTTP gates and actual Activity/history interactions.
// DOM layout observations and compositor frames remain distinct evidence.
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';
const [fixturePath, out, base = 'http://127.0.0.1:15415', theme = 'brutal', form = 'desktop'] = process.argv.slice(2);
if (!fixturePath || !out) throw new Error('capture-loading-source.mjs FIXTURE OUTPUT [BASE THEME desktop|mobile]');
const source = process.env.RAFT_SOURCE ?? '/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source';
const { chromium } = createRequire(`${source}/packages/web/package.json`)('@playwright/test');
const bytes = readFileSync(fixturePath), fixture = JSON.parse(bytes), flow = fixture.process;
const runnerSha = createHash('sha256').update(readFileSync(new URL(import.meta.url))).digest('hex');
mkdirSync(out, { recursive: false });
const viewport = form === 'mobile' ? { width: 390, height: 844 } : { width: 1440, height: 900 };
const prefs = theme === 'brutal' ? { mode: 'light', lightThemeId: 'brutal', darkThemeId: 'elegant' }
  : { mode: theme === 'elegant-dark' ? 'dark' : 'light', lightThemeId: 'elegant', darkThemeId: 'elegant' };
const browser = await chromium.launch({ executablePath: process.env.RAFT_CHROMIUM ?? `${process.env.HOME}/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome` });
const context = await browser.newContext({ viewport, locale: 'en-US', timezoneId: 'Asia/Shanghai', permissions: ['notifications'], extraHTTPHeaders: { 'X-Process-Provider': `source-loading-${form}-${theme}` } });
const page = await context.newPage();
const rendererFrames = [], stages = [], failures = [], rendererDir = resolve(out, 'renderer-frames');
mkdirSync(rendererDir);
const cdp = await context.newCDPSession(page);
let renderActive = true;
cdp.on('Page.screencastFrame', event => {
  cdp.send('Page.screencastFrameAck', { sessionId: event.sessionId }).catch(() => {});
  if (!renderActive) return;
  const index = rendererFrames.length, file = `${String(index).padStart(4, '0')}.png`;
  writeFileSync(resolve(rendererDir, file), Buffer.from(event.data, 'base64'));
  rendererFrames.push({ index, file, at: performance.now(), wallTime: Date.now(), metadata: event.metadata });
});
await cdp.send('Page.startScreencast', { format: 'png', everyNthFrame: 1 });
const runtimeState = async () => (await fetch(`${base}/__process/state`)).json();
const initial = await runtimeState(), requestStart = initial.requests.at(-1)?.seq ?? 0;
if (initial.fixtureSha !== createHash('sha256').update(bytes).digest('hex')) throw new Error('Runtime fixture differs');
page.on('pageerror', error => failures.push({ kind: 'pageerror', message: String(error), at: performance.now() }));
await page.routeWebSocket(/socket\.io/, ws => ws.close());
await context.addInitScript(({ prefs, flow }) => {
  localStorage.setItem('slock_access_token', 'fixture-access-token');
  localStorage.setItem('slock_refresh_token', 'fixture-refresh-token');
  localStorage.setItem('slock-theme-preferences-v2', JSON.stringify(prefs));
  localStorage.setItem('slock_locale', 'en');
  window.__loadingFrames = [];
  window.__loadingStage = 'bootstrap';
  const visible = el => {
    if (!el) return null;
    const r = el.getBoundingClientRect(), css = getComputedStyle(el);
    if (!r.width || !r.height || css.visibility === 'hidden' || css.display === 'none') return null;
    return { x: r.x, y: r.y, width: r.width, height: r.height };
  };
  const rects = selector => [...document.querySelectorAll(selector)].map(el => ({ text: el.textContent.trim(), rect: visible(el) })).filter(row => row.rect);
  const message = id => {
    if (!id) return null;
    const el = [...document.querySelectorAll(`#message-${id}`)].find(el => visible(el)), rect = visible(el);
    if (!rect) return null;
    const view = visible(el.closest('[data-testid="message-scroller"]'));
    return { rect, focusRect: visible(el.closest('[data-timeline-message-id]')), view,
      inView: Boolean(view && rect.y < view.y + view.height && rect.y + rect.height > view.y), highlighted: el.getAttribute('data-highlighted') === 'true' };
  };
  function frame(at) {
    const body = document.body?.textContent ?? '';
    window.__loadingFrames.push({ frame: window.__loadingFrames.length, at, wallTime: performance.timeOrigin + at, stage: window.__loadingStage,
      url: location.pathname + location.search, historyLength: history.length, historyState: history.state,
      headers: rects('[data-slot="panel-header"]'), tabs: rects('[data-testid^="panel-tab-"]'), composer: rects('[data-testid="composer-textarea"]'),
      surfaces: rects('[data-testid="message-content-surface"]'), channelScroller: rects('[data-testid="message-scroller"]'),
      // The actual Source node uses CSS uppercase. Read its source text for
      // identity and retain compositor PNGs for the displayed uppercase glyphs.
      channelPlaceholder: body.includes('Loading channel'), selectChannel: body.includes('Select a channel'),
      messageLoading: [...document.querySelectorAll('[data-testid="message-content-surface"]')].filter(el => visible(el)).some(el => /^Loading[.\s]*$/.test(el.textContent.trim())),
      accepted: message(flow.acceptedMessageId), target: message(flow.targetMessageId), replacement: message(flow.replacementTargetId) });
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}, { prefs, flow });
const control = async (action, key) => {
  const response = await fetch(`${base}/__process/${action}?key=${encodeURIComponent(key)}`);
  if (!response.ok) throw new Error(`Gate ${action}: ${response.status}`);
  return response.json();
};
const waitHeld = async key => {
  const deadline = performance.now() + 15000;
  while (performance.now() < deadline) {
    const state = await runtimeState();
    if (state.held.some(row => row.key === key && row.count > 0)) return state;
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  throw new Error(`Source did not hold ${key}`);
};
const stage = async name => {
  await page.evaluate(name => { window.__loadingStage = name; }, name);
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  const frame = await page.evaluate(() => window.__loadingFrames.at(-1));
  stages.push({ name, frame });
  await page.screenshot({ path: resolve(out, `${String(stages.length).padStart(2, '0')}-${name}.png`) });
  return frame;
};
function check(actual, label) { if (!actual) failures.push({ kind: 'assertion', stage: stages.at(-1)?.name, message: label, at: performance.now() }); }
const readsAfter = (state, seq, channelId) => state.requests.filter(row => row.seq > seq && row.kind === 'request' && row.key === `POST /channels/${channelId}/read`);
const row = name => page.getByTestId('inbox-row').filter({ hasText: name });
const activate = async name => form === 'desktop' ? row(name).dblclick() : row(name).click();
try {
  await page.goto(base + flow.sourceRoute, { waitUntil: 'domcontentloaded' });
  await page.addStyleTag({ content: '#react-scan-root, body > div.ph-no-capture { display:none!important; }' });
  if (flow.flow.startsWith('cold-')) {
    if (flow.opener === 'sidebar') {
      await page.locator(`[data-sidebar-channel-id="${flow.channelId}"]`).waitFor({ state: 'visible', timeout: 30000 });
      await page.getByTestId('composer-textarea').waitFor({ state: 'visible' });
    } else await row(flow.channelName).waitFor({ state: 'visible', timeout: 30000 });
    await stage(flow.prelude ?? 'activity-ready');
    await control('arm', flow.tailHold);
    if (flow.flow === 'cold-unknown') await control('arm', flow.metadataHold);
    await page.evaluate(() => { window.__loadingStage = 'cold-activation'; });
    if (flow.opener === 'sidebar') await page.locator(`[data-sidebar-channel-id="${flow.channelId}"]`).click();
    else await activate(flow.channelName);
    if (flow.flow === 'cold-unknown') {
      await waitHeld(flow.metadataHold);
      const pending = await stage('pending-identity');
      check(pending.channelPlaceholder, 'Unresolved identity must show Source loading-channel placeholder');
      check(!pending.composer.length && !pending.tabs.length, 'Unresolved identity must not fabricate resolved conversation controls');
      check(!pending.accepted, 'Unresolved identity must not paint tail');
      await control('release', flow.metadataHold);
    }
    const held = await waitHeld(flow.tailHold);
    const tailRequest = held.requests.filter(r => r.kind === 'request' && r.key === flow.tailHold && r.seq > requestStart).at(-1);
    await page.getByTestId('composer-textarea').waitFor({ state: 'visible' });
    const pending = await stage('pending-tail');
    check(pending.headers.some(header => header.text.includes(flow.channelName)), 'Known metadata header must be mounted while cold tail waits');
    check(pending.tabs.length > 0 && pending.composer.length > 0, 'Known metadata tabs/composer must be mounted before message response');
    check(!pending.accepted, 'Cold tail must not fabricate accepted message');
    check(!pending.channelPlaceholder && !pending.selectChannel, 'Resolved cold shell must not show unresolved/Select channel');
    check(readsAfter(await runtimeState(), tailRequest.seq, flow.channelId).every(r => (r.body?.seq ?? 0) === 0), 'Cold unaccepted tail has no positive read ACK');
    await page.waitForTimeout(350);
    await stage('tail-still-held');
    await page.evaluate(() => { window.__loadingStage = 'tail-response-delivery'; });
    await control('release', flow.tailHold);
    await page.locator(`#message-${flow.acceptedMessageId}`).waitFor({ state: 'visible' });
    const accepted = await stage('tail-accepted');
    check(accepted.accepted?.inView, 'Accepted cold tail must paint in viewport');
  } else {
    await page.locator(`#message-${flow.acceptedMessageId}`).waitFor({ state: 'visible', timeout: 30000 });
    await stage('accepted-tail');
    if (form === 'desktop') await page.getByTestId('left-rail-tab-activity').click();
    else {
      await page.getByTestId('chat-mobile-back').click();
      await page.getByRole('button', { name: /^Activity(?:\s+\d+)?$/ }).last().click();
    }
    await row(flow.channelName).waitFor({ state: 'visible' });
    await stage('activity-ready');
    await control('arm', flow.hold);
    await control('arm', flow.replacementHold);
    await activate(flow.channelName);
    await waitHeld(flow.hold);
    await stage('superseded-target-pending');
    if (form === 'desktop') await page.goBack();
    else await page.getByTestId('chat-mobile-back').click();
    await row(flow.replacementName).waitFor({ state: 'visible' });
    await stage('back-to-activity');
    await activate(flow.replacementName);
    await waitHeld(flow.replacementHold);
    await stage('replacement-pending');
    await control('release', flow.replacementHold);
    await page.locator(`#message-${flow.replacementTargetId}`).waitFor({ state: 'visible' });
    const accepted = await stage('replacement-accepted');
    check(accepted.replacement?.inView, 'Replacement target accepted before stale release');
    const before = await runtimeState(), releaseStart = before.requests.at(-1)?.seq ?? 0;
    await page.evaluate(() => { window.__loadingStage = 'late-response-delivery'; });
    const release = await control('release', flow.hold);
    await page.waitForTimeout(350);
    const after = await stage('stale-response-released');
    check(after.url === accepted.url, 'Stale response cannot replace destination URI');
    check(after.replacement?.inView && !after.target, 'Stale response cannot replace accepted replacement viewport');
    const state = await runtimeState();
    check(!state.requests.some(r => r.seq > releaseStart && r.kind === 'request' && r.key === flow.tailHold), 'Superseded context error cannot start old fallback tail');
    check(readsAfter(state, releaseStart, flow.channelId).every(r => (r.body?.seq ?? 0) <= flow.acceptedSeq), 'Stale context cannot advance old accepted read frontier');
    const lateFrames = await page.evaluate(() => window.__loadingFrames.filter(r => ['late-response-delivery', 'stale-response-released'].includes(r.stage)));
    check(lateFrames.every(r => r.url === accepted.url && !r.target && r.replacement?.inView), 'Every observed late-response frame retains only accepted replacement target');
    stages.at(-1).releasedRequestCount = release.count;
    // Aborted client requests are retained as such, never called delivered late
    // success. Actual response records decide what race was exercised.
    stages.at(-1).staleResponseObserved = state.requests.some(r => r.seq > releaseStart && r.kind === 'response' && r.key === flow.hold);
  }
} catch (error) {
  failures.push({ kind: 'flow', stage: stages.at(-1)?.name ?? 'bootstrap', message: String(error), at: performance.now() });
  await page.screenshot({ path: resolve(out, 'failure.png') }).catch(() => {});
} finally {
  await cdp.send('Page.stopScreencast').catch(() => {});
  renderActive = false;
  await cdp.detach();
  const frames = await page.evaluate(() => window.__loadingFrames ?? []).catch(() => []);
  const state = await runtimeState();
  writeFileSync(resolve(out, 'renderer-frames.json'), JSON.stringify(rendererFrames, null, 2));
  writeFileSync(resolve(out, 'frames.jsonl'), frames.map(frame => JSON.stringify(frame)).join('\n') + '\n');
  writeFileSync(resolve(out, 'result.json'), JSON.stringify({ provider: 'Source real App', flow: flow.flow, requirement: flow.requirement,
    sourceHead: initial.sourceHead, sourceInputSha: initial.sourceInputSha, runtimeSha: initial.runtimeSha,
    runnerSha, fixtureSha: createHash('sha256').update(bytes).digest('hex'),
    viewport, theme, form, frameCount: frames.length, rendererFrameCount: rendererFrames.length, stages, failures,
    requests: state.requests.filter(r => r.seq > requestStart), result: failures.length ? 'FAIL' : 'PASS' }, null, 2));
  console.log(JSON.stringify({ result: failures.length ? 'FAIL' : 'PASS', out, frames: frames.length, rendererFrames: rendererFrames.length, failures }));
  await browser.close();
  if (failures.length) process.exitCode = 1;
}
