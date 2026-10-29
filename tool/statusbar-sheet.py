#!/usr/bin/env python3
"""Compose per-theme contact sheets from the crops written by
apps/raft_flutter/test/statusbar_audit_test.dart (top 120dp of each page, the
simulated 40dp status bar inset marked by a magenta line).

  tool/flutter test apps/raft_flutter/test/statusbar_audit_test.dart  # crops
  tool/statusbar-sheet.py                                            # sheets
"""
import pathlib
import sys

from PIL import Image, ImageDraw

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                    pathlib.Path(__file__).resolve().parent.parent / '.local/statusbar')
cols, scale, label_h = 2, 0.5, 22
for theme_dir in sorted((root / 'crops').iterdir()):
    files = sorted(theme_dir.glob('*.png'))
    if not files:
        continue
    thumbs = []
    for f in files:
        im = Image.open(f).convert('RGB')
        im = im.resize((int(im.width * scale), int(im.height * scale)))
        thumbs.append((f.stem, im))
    w, h = thumbs[0][1].size
    per = 16
    for part, start in enumerate(range(0, len(thumbs), per), 1):
        chunk = thumbs[start:start + per]
        rows = -(-len(chunk) // cols)
        sheet = Image.new('RGB', (cols * (w + 8) + 8, rows * (h + label_h + 8) + 8), '#888')
        draw = ImageDraw.Draw(sheet)
        for i, (name, im) in enumerate(chunk):
            x, y = 8 + (i % cols) * (w + 8), 8 + (i // cols) * (h + label_h + 8)
            draw.text((x, y + 4), name, fill='white')
            sheet.paste(im, (x, y + label_h))
        out = root / f'sheet-{theme_dir.name}-{part}.png'
        sheet.save(out)
        print(out)
