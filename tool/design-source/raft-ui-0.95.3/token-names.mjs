#!/usr/bin/env node
// Renames raft-ui tokens to the names the Raft Design System docs use.
//
//   node node_modules/@botiverse/raft-ui/codemods/token-names.mjs <dir-or-file>... [--dry]
//
// Rewrites Tailwind utilities (`bg-layer-panel`, `hover:border-line-muted/50`)
// and CSS custom properties (`var(--primary-soft)`) in .ts, .tsx, .js, .jsx,
// .mjs, .css and .html files. The old names were deprecated aliases up to
// raft-ui 0.56 and are removed after it: run this before upgrading past 0.56.
//
// Review by hand afterwards: a guard that forbids a former name (a lint rule,
// a test's doesNotMatch, an allowlist) now forbids the current one, and a
// pattern built from parts (/bg-brutal-[a-z]+/) keeps the former name.
import { readdirSync, readFileSync, realpathSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

/** Old token name -> new token name. Used for both utilities and `--` properties. */
export const TOKEN_RENAMES = {
  "layer-panel": "layer-canvas",
  "layer-inset": "fill-muted",
  "layer-canvas-muted": "layer-sidebar",
  "foreground-strong": "foreground",
  "foreground-icon": "foreground-muted",
  "foreground-placeholder": "foreground-hint",
  "layer-hud-foreground": "foreground-on-hud",
  "line-muted": "line-hairline",
  line: "line-seam",
  "theme-shadow-float": "elevation-float",
  "theme-shadow-lg": "elevation-float",
  "theme-shadow-xl": "elevation-float",
  "theme-shadow-sticker": "elevation-sticker",
  "theme-focus-ring": "focus-ring",
  "soft-signal": "palette-yellow",
  "fill-pressed": "fill-medium",
  "fill-frame-pressed": "fill-frame-medium",
  "fill-row-hover": "fill-subtle",
  "fill-row-open": "fill-subtle",
  "fill-message-hover": "fill-subtle",
  "sticker-pressed": "sticker-medium",
};

/** Families renamed with every step: `primary-soft` -> `brand-soft`. */
export const FAMILY_RENAMES = {
  primary: "brand",
  accent: "attention",
};

/** The brand palette loses the name of a theme family that no longer exists. */
export const PALETTE_COLORS = {
  yellow: "yellow",
  pink: "pink",
  cyan: "cyan",
  lime: "lime",
  orange: "orange",
  red: "red",
  purple: "lavender",
  lavender: "lavender",
  stone: "stone",
  cream: "cream",
};

/** Shadow utilities, which are named apart from their properties. */
export const UTILITY_RENAMES = {
  "shadow-raft-float": "shadow-float",
  "shadow-raft-lg": "shadow-float",
  "shadow-raft-xl": "shadow-float",
  "shadow-raft-sticker": "shadow-sticker",
  "shadow-raft-focus": "shadow-focus",
  "press-overlay": "overlay-medium",
  "press-overlay-sticker": "overlay-sticker-medium",
  "row-hover-overlay": "overlay-subtle",
  "row-open-overlay": "overlay-subtle",
};

const COLOR_UTILITY =
  "(?:bg|text|border(?:-[trblxyse])?|ring|ring-offset|inset-ring|outline|fill|stroke|divide|from|via|to|shadow|inset-shadow|decoration|caret|accent|placeholder)";
const END = "(?![\\w-])";
// A custom property, not a BEM modifier: `var(--primary-soft)` but not `.r-button--primary`.
const VAR = "(?<![\\w-])--";
// A reference, not a declaration: `var(--line)` is renamed, `--line: …` is left alone,
// so the deprecated aliases (`--line: var(--line-seam)`) survive a rerun.
const REF_END = "(?![\\w-])(?!\\s*:)";
const escape = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

function rules() {
  const list = [];
  for (const [from, to] of Object.entries(UTILITY_RENAMES)) {
    list.push([new RegExp(`(?<![\\w-])${escape(from)}${END}`, "g"), to]);
  }
  // Longer names first, so `line-muted` is handled before `line`.
  const tokens = Object.entries(TOKEN_RENAMES).sort(([a], [b]) => b.length - a.length);
  for (const [from, to] of tokens) {
    list.push([new RegExp(`(?<![\\w-])(${COLOR_UTILITY})-${escape(from)}${END}`, "g"), `$1-${to}`]);
    list.push([new RegExp(`${VAR}${escape(from)}${REF_END}`, "g"), `--${to}`]);
    // The Tailwind theme variable of the same token: `var(--color-fill-pressed)`.
    list.push([new RegExp(`${VAR}color-${escape(from)}${REF_END}`, "g"), `--color-${to}`]);
  }
  for (const [from, to] of Object.entries(FAMILY_RENAMES)) {
    list.push([
      new RegExp(`(?<![\\w-])(${COLOR_UTILITY})-${from}((?:-[a-z0-9]+)*)${END}`, "g"),
      `$1-${to}$2`,
    ]);
    list.push([new RegExp(`${VAR}${from}((?:-[a-z0-9]+)*)${REF_END}`, "g"), `--${to}$1`]);
    list.push([
      new RegExp(`${VAR}color-${from}((?:-[a-z0-9]+)*)${REF_END}`, "g"),
      `--color-${to}$1`,
    ]);
  }
  for (const [from, to] of Object.entries(PALETTE_COLORS)) {
    list.push([
      new RegExp(`${VAR}color-brutal-${from}-(\\d+)${REF_END}`, "g"),
      `--palette-${to}-$1`,
    ]);
    list.push([new RegExp(`${VAR}color-brutal-${from}${REF_END}`, "g"), `--color-palette-${to}`]);
    list.push([
      new RegExp(`(?<![\\w-])(${COLOR_UTILITY})-brutal-${from}${END}`, "g"),
      `$1-palette-${to}`,
    ]);
  }
  list.push([new RegExp(`${VAR}color-soft-signal${REF_END}`, "g"), "--color-palette-yellow"]);
  return list;
}

export function renameTokens(source) {
  let out = source;
  for (const [pattern, replacement] of rules()) out = out.replace(pattern, replacement);
  return out;
}

const EXTENSIONS = new Set([".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".css", ".html"]);
const SKIP = new Set(["node_modules", "dist", "build", ".git"]);

function* walk(target) {
  const stat = statSync(target);
  if (stat.isFile()) {
    if (EXTENSIONS.has(path.extname(target))) yield target;
    return;
  }
  for (const name of readdirSync(target)) {
    if (SKIP.has(name) || name.startsWith(".")) continue;
    yield* walk(path.join(target, name));
  }
}

function main(argv) {
  const dry = argv.includes("--dry");
  const targets = argv.filter((arg) => !arg.startsWith("--"));
  if (targets.length === 0) {
    console.error("usage: token-names.mjs <dir-or-file>... [--dry]");
    process.exit(1);
  }
  let changed = 0;
  for (const target of targets) {
    for (const file of walk(target)) {
      const before = readFileSync(file, "utf8");
      const after = renameTokens(before);
      if (after === before) continue;
      changed += 1;
      console.log(`${dry ? "would update" : "updated"} ${file}`);
      if (!dry) writeFileSync(file, after);
    }
  }
  console.log(`${changed} file${changed === 1 ? "" : "s"} ${dry ? "to update" : "updated"}`);
}

// Run only when invoked directly. Compare real paths: pnpm installs packages
// through symlinks, so `process.argv[1]` (the path typed) and this module's
// URL (the resolved file) differ, and a plain comparison silently did nothing.
// When imported (a test, `node -e`), argv[1] may be missing or not a file.
function isInvokedDirectly() {
  try {
    return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
}
if (isInvokedDirectly()) main(process.argv.slice(2));
