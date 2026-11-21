#!/usr/bin/env python3
"""Capture the mounted Artifact Viewer discussion and a dismissed control."""

import json
from pathlib import Path

from builders import manifest_path

PREFIX = "components.artifact-discussion."
THEMES = {"light": "raft-light", "dark": "raft-dark"}
SIZES = {"desktop": (1280, 900), "phone": (390, 844)}
STATES = ("comments", "resolved", "closed")
FIXTURE = Path(__file__).parent / "fixtures" / "artifact-discussion.json"


def test_id(name):
    return f'[data-testid="{name}"]'


def case(device, state, suffix, theme, clock):
    width, height = SIZES[device]
    phone = device == "phone"
    panel = test_id("artifact-comments-panel")
    content = test_id("artifact-viewer-text")
    steps = (
        ["artifact-viewer-menu-trigger", "artifact-viewer-menu-comments"]
        if phone
        else ["artifact-viewer-comments-toggle"]
    )
    if state == "menu":
        steps = steps[:1]
        selector = f'body:has({test_id("artifact-viewer-menu-comments")})'
    elif state == "closed":
        steps += ["artifact-comments-close"]
        selector = f"body:has({content}):not(:has({panel}))"
    else:
        mention = '[data-mention="user:visual-user"]'
        draft = test_id("artifact-review-draft")
        selector = f"body:has({panel} {mention}):has({panel} {draft})"
        if phone:
            selector += f':has({test_id("artifact-viewer-comments-sheet")})'
        if state == "resolved":
            steps += ["artifact-comments-resolved-toggle"]
            selector += f':has({panel} {test_id("artifact-comment-resolved-by")})'
    interactions = [{"type": "click", "target": test_id(step)} for step in steps]
    if state == "comments":
        root = f'{test_id("artifact-comment-thread")}[data-thread-id="discussion-root"]'
        interactions.append({"type": "click", "target": f'{root} {test_id("artifact-comment-body")}'})
        selector += f':has({root}[aria-current="true"])'
    return {
        "id": f"{PREFIX}{device}.{state}.{suffix}",
        "title": f"Artifact discussion {device} {state} ({theme})",
        "captureType": "component-fixture",
        "surface": "artifact-discussion",
        "category": "extension/artifact-discussion",
        "suite": "raft-flutter-extension",
        "viewport": {"width": width, "height": height, "density": 1, "touch": phone},
        "theme": theme,
        "locale": "en",
        "variants": [{"id": "default", "name": "Default", "props": {
            "extFixture": "artifact-discussion", "extKind": "artifact-discussion",
            "extCase": state, "parityTheme": theme, "clockIso": clock,
            "platform": "mobile" if phone else "desktop",
        }}],
        "capture": {
            "selector": selector, "crop": "viewport", "contract": "viewport-with-portal",
            "interactions": interactions,
            "androidInteractions": [],
        },
        "reactPathHint": "apps/artifacts/ArtifactViewer.tsx → ArtifactCommentsPanel.tsx",
        "androidCaseHint": "test/parity/cases/ext_artifact_discussion.dart",
        "tolerance": {"pixelRatio": 0.04, "layoutDp": 1, "ignoreAntialiasing": False},
    }


if __name__ == "__main__":
    path = manifest_path()
    manifest = json.loads(path.read_text())
    clock = json.loads(FIXTURE.read_text())["clockIso"]
    manifest["cases"] = [
        row for row in manifest["cases"] if not row["id"].startswith(PREFIX)
    ] + [
        case(device, state, suffix, theme, clock)
        for device in SIZES
        for state in ((*STATES, "menu") if device == "phone" else STATES)
        for suffix, theme in THEMES.items()
    ]
    path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n")
