// raft-flutter parity EXTENSION cases: sidebar row context menus on the phone
// Home list (and the desktop variants the shell cases lack): muted channel, DM,
// pinned agent DM, pinned row (Unpin), section header, custom section, sidebar
// surface and the "Move to section" submenu.
//
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx, after ShellCases.tsx: it renders the shell host's own
// view (ParityExtShView) with the shell fixture, so both providers show the
// same seeded workspace as components.shell.*. Identifiers are prefixed
// `parityExtRm`. Ids: components.row-menus.<platform>.<surface>.<theme>
// (tool/parity-ext/build-row-menus.py).

type ParityExtRmProps = {
  raw: string;
  platform: "desktop" | "mobile";
  surface: string;
  preset: string;
  theme: string;
  extra: number;
};

function parityExtRmProps(): ParityExtRmProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.row-menus.") || params.get("extKind") !== "row-menus") return null;
  return {
    raw,
    platform: params.get("platform") === "mobile" ? "mobile" : "desktop",
    surface: params.get("surface") ?? "",
    preset: params.get("preset") ?? "default",
    theme: params.get("parityTheme") ?? "brutal-light",
    extra: Number(params.get("extra") ?? 0),
  };
}

// Sidebar derives the selected row from the URL: the server root (no
// conversation open) before the first render, like the shell host.
(function parityExtRmPrimeRoute() {
  if (typeof window === "undefined") return;
  if (!parityExtRmProps()) return;
  window.history.replaceState(null, "", `/s/${fxServer.slug}${window.location.search}`);
})();

function parityExtRowMenusElement() {
  const p = parityExtRmProps();
  if (!p) return null;
  return <ParityExtShView p={p as never} />;
}
