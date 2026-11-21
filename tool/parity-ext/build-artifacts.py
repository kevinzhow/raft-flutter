#!/usr/bin/env python3
"""Artifacts collection route states, shared by the Web and Flutter hosts."""
import json

from builders import manifest_path

PREFIX = "components.artifacts."
ID = "pt_743b9130-45de-40f0-bdc0-9d08b6fb447a"
SRC = "packages/web/src/apps/artifacts/"
STATES = {
    "desktop": ("grid", "table", "picker-conv", "picker-author", "viewer",
                "viewer-menu", "visibility", "visibility-confirm", "rename",
                "display-report", "delete-confirm"),
    "phone": ("grid", "list", "picker-conv", "viewer", "rename",
              "display-report", "delete-confirm"),
}

READY = {
    "grid": '[data-testid="artifacts-dashboard-grid"] [data-artifact-open]',
    "table": '[data-testid="artifacts-all-table"] [data-artifact-open]',
    "list": '[data-testid="artifacts-all-rows"] [data-artifact-open]',
    "picker-conv": '[role="listbox"] [role="option"]',
    "picker-author": '[role="listbox"] [role="option"]',
    "viewer": '[data-testid="artifact-viewer-text"]',
    "viewer-menu": '[data-testid="artifact-viewer-menu"]',
    "visibility": '[data-testid="artifact-viewer-visibility-public"]',
    "visibility-confirm": '[data-testid="artifact-widen-public-dialog"]',
    "rename": '[data-testid="artifact-rename-input"]',
    "display-report": '[data-testid="artifact-list-composer"] textarea',
    "delete-confirm": '[role="dialog"]',
}

MENU_STATES = {"viewer-menu", "visibility", "visibility-confirm", "rename",
               "display-report", "delete-confirm"}


def build_cases():
    for platform, states in STATES.items():
        phone = platform == "phone"
        for state in states:
            for suffix, theme in (("brutal", "brutal-light"), ("elegant-dark", "elegant-dark")):
                steps = [{"type": "wait", "ms": 450}]
                flutter = []
                if state in {"table", "list"}:
                    steps.append({"type": "click", "target": '[data-testid="artifacts-dashboard-view-list"]'})
                    flutter.append({"type": "tap", "key": "artifacts-view-list"})
                if state.startswith("picker-"):
                    filter_id = "author" if state.endswith("author") else "conversation"
                    steps.append({"type": "click", "target": f'[data-testid="artifacts-all-{filter_id}-filter"]'})
                    flutter.append({"type": "tap", "key": f"artifacts-filter-{filter_id}", "scroll": False})
                if state == "viewer" or state in MENU_STATES:
                    steps += [
                        {"type": "click", "target": f'[data-artifact-id="{ID}"] [data-artifact-open]'},
                        {"type": "wait", "ms": 500},
                    ]
                    flutter.append({"type": "tap", "key": f"artifact-dashboard-open-{ID}"})
                if state in MENU_STATES:
                    steps.append({"type": "click", "target": '[data-testid="artifact-viewer-menu-trigger"]'})
                    flutter.append({"type": "tap", "key": "artifact-viewer-menu-trigger"})
                if state in {"visibility", "visibility-confirm"}:
                    steps.append({
                        "type": "hover" if state == "visibility" else "click",
                        "target": '[data-testid="artifact-viewer-menu-visibility"]',
                    })
                    flutter.append(
                        {"type": "hover", "finder": {"text": "Who can see",
                                                      "in": "artifact-viewer-menu-surface"}}
                        if state == "visibility"
                        else {"type": "tapText", "text": "Who can see"}
                    )
                if state == "visibility-confirm":
                    steps.append({"type": "click", "target": '[data-testid="artifact-viewer-visibility-public"]'})
                    flutter.append({"type": "tapText", "text": "Anyone with the link"})
                action = {
                    "rename": ("rename", "Rename"),
                    "display-report": ("display-report", "Doesn't display well here"),
                    "delete-confirm": ("delete", "Delete"),
                }.get(state)
                if action is not None:
                    item, label = action
                    steps.append({"type": "click", "target": f'[data-testid="artifact-viewer-menu-{item}"]'})
                    flutter.append({"type": "tapText", "text": label})
                yield {
                    "id": f"{PREFIX}{platform}.{state}.{suffix}",
                    "title": f"Artifacts collection {platform} {state} ({theme})",
                    "suite": "raft-flutter-extension",
                    "captureType": "component-fixture",
                    "surface": "artifacts",
                    "category": "extension/artifacts",
                    "viewport": {"width": 390 if phone else 1280,
                                 "height": 844 if phone else 900, "density": 1},
                    "locale": "en",
                    "theme": theme,
                    "variants": [{"id": "default", "name": "Default", "props": {
                        "extCase": state, "extFixture": "artifacts",
                        "platform": "mobile" if phone else "desktop",
                        "parityTheme": theme,
                    }}],
                    "capture": {"selector": READY[state], "crop": "viewport",
                                "contract": "viewport-with-portal",
                                "interactions": steps + [{"type": "wait", "ms": 450}],
                                "androidInteractions": flutter},
                    "reactPathHint": SRC + "ArtifactsDashboard.tsx",
                    "androidCaseHint": "apps/raft_flutter/test/parity/cases/ext_artifacts.dart",
                    "tolerance": {"pixelRatio": .02, "layoutDp": 1, "ignoreAntialiasing": True},
                }


def main():
    path = manifest_path()
    manifest = json.loads(path.read_text())
    manifest["cases"] = [
        case for case in manifest["cases"] if not case["id"].startswith(PREFIX)
    ] + list(build_cases())
    path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
