#!/usr/bin/env bash
# Link the offline JS dependencies used by the recipe pipeline into
# tool/recipes/node_modules (gitignored). The pnpm store defaults to the one of
# the pinned raft-source checkout (tool/raft-source path); override it with
# RAFT_PNPM_STORE=/path/to/node_modules/.pnpm.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${RAFT_PNPM_STORE:-}" ]]; then
  source_dir="$(python3 "$here/../raft-source" path --need node_modules/.pnpm)"
  RAFT_PNPM_STORE="$source_dir/node_modules/.pnpm"
fi
store="$RAFT_PNPM_STORE"
# Directory-name globs inside the pnpm store; the newest match wins, so a
# raft-source revision that bumps tailwindcss / postcss / acorn needs no edit.
declare -A deps=(
  [typescript]="typescript@*/node_modules/typescript"
  [acorn]="acorn@*/node_modules/acorn"
  [postcss]="postcss@*/node_modules/postcss"
  [tailwind-variants]="tailwind-variants@*/node_modules/tailwind-variants"
  [tailwind-merge]="tailwind-merge@*/node_modules/tailwind-merge"
  [cnfast]="cnfast@*/node_modules/cnfast"
  [esbuild]="esbuild@0.28.2/node_modules/esbuild"
  [@botiverse/ricons]="@botiverse+ricons@0.1.1_*/node_modules/@botiverse/ricons"
)
# Match the compiler pinned by Web v1.24; flat selectors are parsed by the
# selector adapter. Never silently select a different compiler version.
tailwind_store="${RAFT_TAILWIND_STORE:-$store}"
mkdir -p "$here/node_modules"
tw="$tailwind_store/tailwindcss@4.3.3/node_modules/tailwindcss"
[[ -d "$tw" ]] || { echo "missing tailwindcss@4.3.3 under $tailwind_store (set RAFT_TAILWIND_STORE)" >&2; exit 1; }
ln -sfn "$tw" "$here/node_modules/tailwindcss"
for name in "${!deps[@]}"; do
  target="$(compgen -G "$store/${deps[$name]}" | sort -V | tail -n 1 || true)"
  [[ -n "$target" && -d "$target" ]] || { echo "missing dependency $name under $store (${deps[$name]})" >&2; exit 1; }
  mkdir -p "$(dirname "$here/node_modules/$name")"
  ln -sfn "$target" "$here/node_modules/$name"
done
