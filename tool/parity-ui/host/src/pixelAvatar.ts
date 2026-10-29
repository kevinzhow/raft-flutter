// The agent pixel avatars the product draws (8x8 sprite, ONE <img> with an SVG
// data URL, background baked in) for the three docs examples: robot is the
// default, crown is Wug, mushroom is Bugen. Sprites and palette are copied from
// raft-source packages/web/assets/avatars/pixelAvatars.json (the same data as
// packages/raft_ui/lib/src/avatar_pixel_data.dart).
const PALETTE: Record<string, string> = {
  K: "#141111", W: "#FFFFFF", P: "#FE7DA8", O: "#F8A16F", Y: "#FFD440", L: "#A9D877",
  C: "#27CCF3", V: "#BBAFE6", B: "#576574", R: "#F97264", G: "#9DCAAA", D: "#B07A4E",
};

const AVATARS: Record<string, { bg: string; grid: string[] }> = {
  robot: { bg: "C", grid: ["_KKKKKK_", "KCKWWKCK", "KWKWWKWK", "KKKKKKKK", "_KWKKWK_", "_KKKKKK_", "_KK__KK_", "_KK__KK_"] },
  crown: { bg: "Y", grid: ["________", "_K_KK_K_", "_KKKKKK_", "_KYYYYK_", "_KYYYYK_", "KKKKKKKK", "KYYYYYYK", "KKKKKKKK"] },
  mushroom: { bg: "P", grid: ["__KKKK__", "_KRWWRK_", "KRRWWRRK", "KRRRRRRK", "_KKKKKK_", "__KWWK__", "__KWWK__", "_KKKKKK_"] },
};

export type PixelAvatarKey = keyof typeof AVATARS;

export function pixelAvatarUrl(key: PixelAvatarKey): string {
  const { bg, grid } = AVATARS[key];
  const rects = grid.flatMap((row, y) =>
    [...row].flatMap((letter, x) =>
      letter === "_" ? [] : [`<rect x="${x}" y="${y}" width="1" height="1" fill="${PALETTE[letter]}"/>`],
    ),
  );
  const svg =
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 8 8" shape-rendering="crispEdges">` +
    `<rect width="8" height="8" fill="${PALETTE[bg]}"/>${rects.join("")}</svg>`;
  return `data:image/svg+xml,${encodeURIComponent(svg)}`;
}
