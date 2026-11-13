// Prints packages/raft_ui/lib/src/markdown_cjk_ranges.dart's table.
// Usage: node tool/gen-cjk-ranges.mjs <path to get-east-asian-width/index.js>
const { eastAsianWidthType } = await import(process.argv[2]);
const emoji = (uc) => /^\p{Emoji_Presentation}/u.test(String.fromCodePoint(uc));
const hangul = (uc) => /^\p{sc=Hangul}/u.test(String.fromCodePoint(uc));
function cjkOrIvs(uc) {
  if (!uc || uc < 4352) return false;
  switch (eastAsianWidthType(uc)) {
    case 'fullwidth': case 'halfwidth': return true;
    case 'wide': return !emoji(uc);
    case 'narrow': return false;
    case 'ambiguous': return 917760 <= uc && uc <= 917999 ? null : false;
    case 'neutral': return hangul(uc);
  }
}
const ranges = [];
let start = -1;
for (let uc = 0x1100; uc <= 0x10ffff + 1; uc++) {
  const on = uc <= 0x10ffff && !(uc >= 0xd800 && uc <= 0xdfff) && cjkOrIvs(uc) === true;
  if (on && start < 0) start = uc;
  if (!on && start >= 0) { ranges.push([start, uc - 1]); start = -1; }
}
const hex = (n) => '0x' + n.toString(16).toUpperCase().padStart(4, '0');
console.log(ranges.map(([a, b]) => `  ${hex(a)}, ${hex(b)},`).join('\n'));
console.error(ranges.length);
