"""Browser chrome with the pinned Web panel and a deterministic bridge."""

import json

from builders import manifest_path


PREFIX = "components.browser.desktop."
STATES = (
    "page", "empty", "editing", "invalid", "overflow", "narrow",
    "artifact-behind", "artifact-front", "short-front", "long-front",
)


def test_id(name):
    return f'[data-testid="web-preview{("-" + name) if name else ""}"]'


def click(name):
    return {"type": "click", "target": test_id(name)}


def tap(name):
    return {"type": "tap", "key": f"browser-{name}"}


def browser_case(state, suffix):
    react, flutter = [], []
    selector = test_id("")
    if state == "empty":
        react.append(click("new-tab"))
        flutter.append(tap("new-tab"))
        selector += f':has({test_id("empty-tab")})'
    if state in ("editing", "invalid"):
        react.append(click("address"))
        flutter.append(tap("address"))
        selector += f':has({test_id("address-input")})'
    if state == "invalid":
        react.extend([
            {"type": "fill", "target": test_id("address-input"), "value": "not an address"},
            {"type": "press", "target": test_id("address-input"), "key": "Enter"},
        ])
        flutter.extend([
            {"type": "enter", "key": "browser-address-input", "value": "not an address"},
            {"type": "key", "key": "enter"},
        ])
    if state == "overflow":
        react.append(click("more-tabs"))
        flutter.append(tap("more-tabs"))
        selector = f'body:has({test_id("more-tabs-list")})'
    if state == "artifact-front":
        react.append({"type": "click", "target": '[data-testid="side-window-switch-chip"]'})
        flutter.append({"type": "tap", "key": "switch-to-artifact"})
        selector = '[data-browser-fixture]:has([data-testid="artifact-viewer-text"])'
    theme = f"raft-{suffix}"
    return {
        "id": f"{PREFIX}{state}.{suffix}",
        "title": f"Desktop browser {state} ({theme})",
        "captureType": "component-fixture",
        "surface": "browser",
        "category": "extension/browser",
        "suite": "raft-flutter-extension",
        "viewport": {"width": 1280, "height": 900, "density": 1},
        "theme": theme,
        "locale": "en",
        "variants": [{"id": "default", "name": "Default", "props": {
            "extCase": state, "parityTheme": theme, "platform": "desktop",
            **({"extFixture": "artifact-discussion"} if state == "artifact-front" else {}),
        }}],
        "capture": {
            "selector": selector,
            "crop": "viewport" if state == "overflow" else "element",
            "contract": "viewport-with-portal" if state == "overflow" else "component-bounds",
            **({} if state == "overflow" else {
                "androidKey": "browser-artifact-fixture" if state == "artifact-front" else "desktop-browser"
            }),
            "interactions": react,
            "androidInteractions": flutter,
        },
        "reactPathHint": "features/webPreview/BrowserPanel.tsx",
        "androidCaseHint": "test/parity/cases/ext_browser.dart",
        "tolerance": {"pixelRatio": 0.04, "layoutDp": 1, "ignoreAntialiasing": False},
    }


path = manifest_path()
manifest = json.loads(path.read_text())
manifest["cases"] = [case for case in manifest["cases"] if not case["id"].startswith(PREFIX)]
manifest["cases"].extend(browser_case(state, suffix) for state in STATES for suffix in ("light", "dark"))
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n")
