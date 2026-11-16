#!/usr/bin/env python3
"""Regenerate the generated block of packages/raft_ui/lib/src/avatar_pixel_data.dart
from Web's shared pixelAvatars.json (v3: series, reserved keys, ottie).

usage: tool/gen_avatar_pixel_data.py <pixelAvatars.json> [--source-label TEXT]
The block between the GENERATED markers is replaced; the seeded generator
below it is hand-ported from packages/shared/src/pixelAvatarGenerator.ts.
"""
import json
import pathlib
import sys

OUT = pathlib.Path(__file__).resolve().parents[1] / "packages/raft_ui/lib/src/avatar_pixel_data.dart"
BEGIN = "// GENERATED-BEGIN (tool/gen_avatar_pixel_data.py)"
END = "// GENERATED-END"


def block(d):
    pal = d["palette"]
    o = [BEGIN]
    o.append(f"// pixelAvatars.json version {d['version']}.")
    o.append("const raftPixelAvatarPalette = <String, String>{")
    for k, v in pal.items():
        o.append(f"  '{k}': '{v}',")
    o.append("};")
    o.append("const raftPixelAvatarPresets = <String, RaftPixelAvatarData>{")
    for k, a in d["avatars"].items():
        bg = a["bg"] if a["bg"].startswith("#") else pal[a["bg"]]
        o.append(f"  '{k}': RaftPixelAvatarData('{bg}', [")
        for r in a["grid"]:
            assert len(r) == 8
            o.append(f"    '{r}',")
        o.append("  ]),")
    o.append("};")
    o.append("/// Reserved keys: never picked at random or listed in the picker.")
    o.append("const raftReservedPixelAvatarKeys = <String>[" + ", ".join(f"'{k}'" for k in d["reservedKeys"]) + "];")
    o.append("/// The picker's themed sets of eight, in picker order.")
    o.append("const raftPixelAvatarSeries = <(String, List<String>)>[")
    for s in d["series"]:
        assert len(s["avatars"]) == 8
        o.append(f"  ('{s['key']}', [" + ", ".join(f"'{k}'" for k in s["avatars"]) + "]),")
    o.append("];")
    o.append(f"const raftDefaultPixelAvatarKey = '{d['defaultKey']}';")
    o.append(END)
    return "\n".join(o)


def main():
    d = json.load(open(sys.argv[1]))
    text = OUT.read_text()
    if BEGIN in text:
        pre, rest = text.split(BEGIN, 1)
        post = rest.split(END, 1)[1]
    else:
        pre = text[: text.index("const raftDefaultPixelAvatarKey")]
        post = text[text.index("};\n", text.index("const raftPixelAvatarPresets")) + 3 :]
    OUT.write_text(pre + block(d) + post)


main()
