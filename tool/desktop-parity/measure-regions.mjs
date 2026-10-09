// Read-only DOM measurements. This function is serialized by Playwright; keep
// every helper inside it. No candidate is selected from raster similarity.
export function measureDesktopRegions() {
  const rect = (r) => ({ x: r.x, y: r.y, width: r.width, height: r.height });
  const inspect = (el) => {
    const r = el.getBoundingClientRect(), css = getComputedStyle(el);
    const visible = r.width > 0 && r.height > 0 &&
      css.display !== 'none' && css.visibility !== 'hidden' &&
      Number(css.opacity) !== 0 && el.checkVisibility({ checkVisibilityCSS: true, checkOpacity: true });
    return { tag: el.tagName, testId: el.getAttribute('data-testid'),
      slot: el.getAttribute('data-slot'), rect: rect(r), visible,
      display: css.display, visibility: css.visibility, opacity: css.opacity,
      computedStyle: Object.fromEntries(['backgroundColor', 'color', 'fontFamily',
        'fontSize', 'fontWeight', 'lineHeight', 'borderLeftColor', 'borderLeftWidth',
        'borderBottomColor', 'borderBottomWidth'].map((key) => [key, css[key]])) };
  };
  const probe = (selector) => {
    const elements = [...document.querySelectorAll(selector)];
    const candidates = elements.map(inspect), visible = candidates.filter((e) => e.visible);
    return { selector, candidates,
      status: visible.length === 1 ? 'eligible' : visible.length > 1 ? 'ambiguous' : elements.length ? 'hidden' : 'absent',
      rect: visible.length === 1 ? visible[0].rect : null };
  };
  const regions = {
    rail: probe('[data-testid="workspace-left-rail"]'),
    sidebar: probe('[data-testid="sidebar-root"]'),
    rightPanel: probe('[data-testid="thread-side-column"], [data-testid="workspace-secondary-sidebar"]'),
  };
  const mainFrame = probe('[data-testid="thread-main-column"]');
  const main = document.querySelector('[data-testid="thread-main-column"]');
  // Source PanelHeader's actual top-level frame, excluding sidebar headers and
  // nested card/dialog headers. Include only declared ancestor CSS border and
  // padding insets (Activity's attached Panel has a left border). This is not a
  // positional tolerance or a page-specific correction.
  const candidates = main ? [...main.querySelectorAll('[data-slot="panel-header"]')].map((el) => {
    const node = inspect(el), insets = { left: 0, right: 0, top: 0 }, ancestors = [];
    let reachedMain = false;
    for (let ancestor = el.parentElement; ancestor; ancestor = ancestor.parentElement) {
      const css = getComputedStyle(ancestor), r = ancestor.getBoundingClientRect();
      const values = Object.fromEntries(['borderLeftWidth', 'borderRightWidth', 'borderTopWidth',
        'paddingLeft', 'paddingRight', 'paddingTop'].map((key) => [key, parseFloat(css[key]) || 0]));
      insets.left += values.borderLeftWidth + values.paddingLeft;
      insets.right += values.borderRightWidth + values.paddingRight;
      insets.top += values.borderTopWidth + values.paddingTop;
      ancestors.push({ tag: ancestor.tagName, slot: ancestor.getAttribute('data-slot'),
        testId: ancestor.getAttribute('data-testid'), rect: rect(r), cssInsets: values,
        backgroundColor: css.backgroundColor, borderLeftColor: css.borderLeftColor });
      if (ancestor === main) { reachedMain = true; break; }
    }
    return { ...node, ownershipInsets: insets, ancestors, reachedMain };
  }) : [];
  const same = (a, b) => Math.abs(a - b) < 1e-6;
  const topHeaders = mainFrame.rect ? candidates.filter((e) => e.visible && e.reachedMain &&
    same(e.rect.x, mainFrame.rect.x + e.ownershipInsets.left) &&
    same(e.rect.y, mainFrame.rect.y + e.ownershipInsets.top) &&
    same(e.rect.width, mainFrame.rect.width - e.ownershipInsets.left - e.ownershipInsets.right)) : [];
  const headerStatus = mainFrame.status !== 'eligible' ? mainFrame.status :
    topHeaders.length === 1 ? 'eligible' : topHeaders.length > 1 ? 'ambiguous' :
      candidates.some((e) => !e.visible) && !candidates.some((e) => e.visible) ? 'hidden' : 'absent';
  regions.header = { status: headerStatus,
    selector: '[data-testid="thread-main-column"] [data-slot="panel-header"]',
    rule: 'one visible panel-header at the main content top/width after declared ancestor CSS border/padding',
    candidates, topHeaders, rect: topHeaders.length === 1 ? topHeaders[0].rect : null };
  if (mainFrame.status === 'eligible' && ['eligible', 'absent'].includes(headerStatus)) {
    const frame = mainFrame.rect, header = regions.header.rect;
    const y = header ? header.y + header.height : frame.y;
    const height = frame.y + frame.height - y;
    regions.body = { status: height > 0 ? 'eligible' : 'hidden',
      rect: height > 0 ? { x: frame.x, y, width: frame.width, height } : null,
      rule: header ? 'entire measured main frame below its top header, including tabs/composer' :
        'entire measured main frame; no top-level header exists',
      derivedFrom: { mainFrame: frame, header } };
  } else {
    regions.body = { status: mainFrame.status === 'eligible' ? headerStatus : mainFrame.status,
      rect: null, rule: 'withheld when main frame or its header split is ambiguous/hidden' };
  }
  return { schemaVersion: 1, geometryContractVersion: 2, coordinateSystem: 'Source CSS viewport',
    viewport: { width: innerWidth, height: innerHeight, density: devicePixelRatio },
    mainFrame, regions,
    railFooter: [...document.querySelectorAll('[data-slot="app-rail-footer"] button')].map((button) => ({
      ...inspect(button), label: button.getAttribute('aria-label'),
      icons: [...button.querySelectorAll('svg')].map((icon) => ({
        ...inspect(icon), declaredWidth: icon.getAttribute('width'),
        declaredHeight: icon.getAttribute('height'),
        computedWidth: getComputedStyle(icon).width, computedHeight: getComputedStyle(icon).height,
        classes: icon.getAttribute('class'),
      })),
    })),
    overlays: [...document.querySelectorAll('[role="dialog"], [data-testid="notification-center"], [data-message-affordance="reaction-picker"]')].map(inspect),
    note: 'layout boxes include any pixels occluded by overlays; no screenshot-aware masks or score-selected crops' };
}
