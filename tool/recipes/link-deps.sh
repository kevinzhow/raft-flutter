#!/usr/bin/env bash
# Link the offline JS dependencies used by the recipe pipeline into
# tool/recipes/node_modules (gitignored). Override the pnpm store with
# RAFT_PNPM_STORE=/path/to/node_modules/.pnpm.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
store="${RAFT_PNPM_STORE:-/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source/node_modules/.pnpm}"
# Directory-name globs inside the pnpm store; the newest match wins, so a
# raft-source revision that bumps tailwindcss / postcss / acorn needs no edit.
declare -A deps=(
  [typescript]="typescript@*/node_modules/typescript"
  [acorn]="acorn@*/node_modules/acorn"
  [postcss]="postcss@*/node_modules/postcss"
  [tailwind-variants]="tailwind-variants@*/node_modules/tailwind-variants"
  [tailwind-merge]="tailwind-merge@*/node_modules/tailwind-merge"
  [cnfast]="cnfast@*/node_modules/cnfast"
)
# The class compiler stays on Tailwind 4.2.x on purpose: 4.3 serialises
# nested variants as flat selectors (`:is(.cls *)[attr]`) instead of nested
# `&` rules, which tool/recipes/lib/selector.mjs does not read. The class ->
# declaration mapping is the same, and the design tokens still come from the
# 4.3.x theme.css vendored by tool/gen-tokens. RAFT_TAILWIND_STORE points at a
# pnpm store that holds tailwindcss@4.2.x (default: the same store).
tailwind_store="${RAFT_TAILWIND_STORE:-$store}"
mkdir -p "$here/node_modules"
tw="$(compgen -G "$tailwind_store/tailwindcss@4.2.*/node_modules/tailwindcss" | sort -V | tail -n 1 || true)"
[[ -n "$tw" && -d "$tw" ]] || { echo "missing tailwindcss@4.2.x under $tailwind_store (set RAFT_TAILWIND_STORE)" >&2; exit 1; }
ln -sfn "$tw" "$here/node_modules/tailwindcss"
for name in "${!deps[@]}"; do
  target="$(compgen -G "$store/${deps[$name]}" | sort -V | tail -n 1 || true)"
  [[ -n "$target" && -d "$target" ]] || { echo "missing dependency $name under $store (${deps[$name]})" >&2; exit 1; }
  ln -sfn "$target" "$here/node_modules/$name"
done
