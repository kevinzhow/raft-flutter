// WP-ART0 spike: Porthole's framework-agnostic host (`createHost`) inside an app WebView.
//
// The app loads a wrapper page whose origin is one the content Worker lets frame pages (the Raft
// app's origin, APP_ORIGIN, or an EXTRA_APP_ORIGINS entry). This script runs in that page: it
// mounts Raft Web v1.24's `artifact` display (the same config as
// packages/web/src/apps/artifacts/ArtifactFrame.tsx RAFT_ARTIFACT_DISPLAYS) and carries the
// capability calls and display events to Dart over one JavaScript channel.
//
// A WebView's JavaScript channel is visible in every frame, the content's included (Android's
// addJavascriptInterface; WebKit's script message handlers): the channel itself is no boundary.
// So every message to Dart carries the page's nonce, which Dart wrote into this page and which a
// cross-origin frame cannot read; Dart drops any message without it.
import {
  createHost,
  defineDisplays,
  compile,
  frameFallback,
  LIBRARY_CDNS,
} from "@botiverse/porthole";
import { ARTIFACT_PAGE_THEME_VARIABLES } from "raft-shared/artifactPageTheme";
import { ARTIFACT_FRAME_SANDBOX } from "./sandbox.mjs";

// Kept equal to packages/web/src/apps/artifacts/ArtifactFrame.tsx (v1.24.0).
const RAFT_ARTIFACT_DISPLAYS = defineDisplays({
  artifact: {
    preset: "artifact",
    options: {
      egress: LIBRARY_CDNS,
      runtime: "1",
      capabilities: { annotate: {}, comments: {}, copyText: {}, find: {}, openLink: {} },
      layout: { kind: "fill" },
      errors: "host",
      theme: { variables: ARTIFACT_PAGE_THEME_VARIABLES },
    },
    served: { storage: { scope: "this artifact, across its versions" } },
  },
});

const channel = window.RaftArtifactBridge;
const nonce = document.documentElement.dataset.bridgeNonce ?? "";
delete document.documentElement.dataset.bridgeNonce;

function send(type, detail) {
  try {
    channel.postMessage(JSON.stringify({ nonce, type, detail: detail ?? null }));
  } catch {
    // No channel (a test page): nothing to tell.
  }
}

let seq = 0;
const pending = new Map();
function ask(type, detail) {
  const id = ++seq;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    send(type, { ...detail, id });
  });
}

let display = null;
let theme = {};

function mount(options) {
  const { location, id, version, title, scheme } = options;
  theme = options.theme ?? {};
  const source = `${new URL(location.origin).protocol}//*.${options.contentDomain}`;
  const config = RAFT_ARTIFACT_DISPLAYS.served(source)?.artifact ?? null;
  const compiled = config ? compile(config) : null;
  send("compiled", { sandbox: compiled?.sandbox ?? null, sandboxMatchesWeb: compiled?.sandbox === ARTIFACT_FRAME_SANDBOX, allow: compiled?.allow ?? null });
  if (!config || compiled.sandbox !== ARTIFACT_FRAME_SANDBOX) {
    send("outcome", { state: "blocked", reason: "config" });
    return;
  }
  let first = location;
  const host = createHost(config, {
    handlers: {
      openLink: ({ url }) => ask("openLink", { url }),
      copyText: ({ text }) => ask("copyText", { text }),
      comments: (request) => ask("comments", { request }),
    },
    confirm: (request) => ask("confirm", { capability: request.capability, args: request.args, title: request.display.title }),
    theme: () => theme,
    hostInfo: { name: "raft-flutter", version: "art0-spike" },
    locator: {
      async locate() {
        if (first) {
          const located = first;
          first = null;
          return located;
        }
        return ask("locate", {});
      },
    },
  });
  display = host.mount(document.getElementById("frame"), {
    displayId: `artifact:${id}@${version}`,
    title,
    scheme,
    instance: { scope: `artifact:${id}`, document: { kind: "artifact", id, version: location.instanceVersion ?? String(version) } },
    declaration: null,
    viewer: { level: "view" },
  });
  for (const event of ["initialized", "outcome", "resize", "contentError", "hostError", "navigated", "navigationBlocked", "refused", "muted", "storage", "annotation", "findRequested", "findUpdated"]) {
    display.on(event, (detail) => {
      if (event === "outcome") send("fallback", { fallback: frameFallback(detail) });
      send(event, detail ?? null);
    });
  }
  display.find.takeShortcut(true);
}

// Dart's calls. Only Dart reaches these (runJavaScript in this page); a frame can't.
window.RaftArtifactHost = Object.freeze({
  mount(options) {
    mount(options);
  },
  answer(id, ok, value) {
    const call = pending.get(id);
    if (!call) return;
    pending.delete(id);
    if (ok) call.resolve(value);
    else call.reject(Object.assign(new Error(String(value?.code ?? "failed")), value ?? {}));
  },
  setScheme(scheme, values) {
    theme = values ?? theme;
    display?.setTheme(scheme);
  },
  async find(query, direction) {
    const result = await display?.find.query(query, direction ? { direction } : undefined);
    send("findResult", { query, result: result ?? "unsupported" });
  },
  clearFind() {
    display?.find.clear();
  },
  annotations(action, arg) {
    try {
      const controls = display?.annotations;
      if (!controls) return;
      if (action === "start") controls.start(arg ?? undefined);
      else if (action === "stop") controls.stop();
      else if (action === "show") controls.show(arg);
      else if (action === "focus") controls.focus(arg);
      else if (action === "clear") controls.clear();
      send("annotationsAck", { action });
    } catch (error) {
      send("annotationsAck", { action, error: String(error?.message ?? error) });
    }
  },
  reload() {
    display?.reload();
  },
  destroy() {
    display?.destroy();
    display = null;
  },
});

send("ready", { origin: window.location.origin });
