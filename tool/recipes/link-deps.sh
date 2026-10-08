#!/usr/bin/env bash
# Link the offline JS dependencies used by the recipe pipeline into
# tool/recipes/node_modules (gitignored). Override the pnpm store with
# RAFT_PNPM_STORE=/path/to/node_modules/.pnpm.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
store="${RAFT_PNPM_STORE:-/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source/node_modules/.pnpm}"
declare -A deps=(
  [acorn]="acorn@8.18.0/node_modules/acorn"
  [postcss]="postcss@8.5.8/node_modules/postcss"
  [tailwindcss]="tailwindcss@4.2.2/node_modules/tailwindcss"
  [tailwind-variants]="tailwind-variants@3.3.1_tailwind-merge@3.7.0_tailwindcss@4.2.2/node_modules/tailwind-variants"
  [tailwind-merge]="tailwind-merge@3.7.0/node_modules/tailwind-merge"
  [cnfast]="cnfast@0.2.0/node_modules/cnfast"
)
mkdir -p "$here/node_modules"
for name in "${!deps[@]}"; do
  target="$store/${deps[$name]}"
  [[ -d "$target" ]] || { echo "missing dependency $name at $target" >&2; exit 1; }
  ln -sfn "$target" "$here/node_modules/$name"
done
