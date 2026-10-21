#!/usr/bin/env python3
"""Check that tool/p2-score.mjs measures what it claims.

The scorer must return exactly 100% when an image is compared against itself. A
scorer that quietly rescaled, cropped or alpha-blended differently between the two
sides would still produce plausible-looking numbers, so this pins the one result
that has a known answer.

It also fails if the baseline images or their metadata are missing, because "no
rows" would otherwise read as success.

  python3 tool/tests/test_p2_score.py
"""

from __future__ import annotations

import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCORER = ROOT / 'tool' / 'p2-score.mjs'
# The P2 baseline lives outside the repository; the test skips when it is absent
# so a checkout without the data disk can still run the suite.
BASELINE = pathlib.Path('/mnt/data/theme-baseline/p2-a57b9dab'
                        '/ext-desktop/pass-1/visual-testing-results/android')


def node() -> str | None:
    return shutil.which('node')


@unittest.skipIf(node() is None, 'node is not installed')
class P2ScoreSelfCheck(unittest.TestCase):
    def run_scorer(self, baseline: pathlib.Path, current: pathlib.Path,
                   out: pathlib.Path) -> dict:
        result = subprocess.run(
            [node(), str(SCORER), str(baseline), str(current), str(out)],
            capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(out.read_text())

    @unittest.skipUnless(BASELINE.is_dir(), 'P2 baseline images not available')
    def test_baseline_against_itself_scores_exactly_100_percent(self):
        # Take a handful of real cases rather than all 438: the property is about
        # the metric, not about coverage.
        with tempfile.TemporaryDirectory() as temporary:
            sample = pathlib.Path(temporary) / 'sample'
            sample.mkdir()
            names = sorted(p.name for p in BASELINE.glob('*.png'))[:5]
            self.assertTrue(names, 'baseline has no png files')
            for name in names:
                shutil.copy(BASELINE / name, sample / name)
                meta = BASELINE / name.replace('.png', '.metadata.json')
                shutil.copy(meta, sample / meta.name)

            out = pathlib.Path(temporary) / 'scores.json'
            scores = self.run_scorer(sample, sample, out)
            self.assertEqual(len(scores['rows']), len(names))
            for row in scores['rows']:
                self.assertEqual(row['pixelPerfectSimilarity'], 1,
                                 f"{row['case']} self-compare is not 100%")
                self.assertAlmostEqual(row['rgbSimilarity'], 1.0, places=9)

    @unittest.skipUnless(BASELINE.is_dir(), 'P2 baseline images not available')
    def test_a_changed_pixel_lowers_the_score(self):
        # The complement of the check above: the metric must actually notice a
        # difference, or a 100% result would be meaningless.
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            base = root / 'base'
            cur = root / 'cur'
            base.mkdir()
            cur.mkdir()
            name = sorted(p.name for p in BASELINE.glob('*.png'))[0]
            shutil.copy(BASELINE / name, base / name)
            meta = BASELINE / name.replace('.png', '.metadata.json')
            shutil.copy(meta, base / meta.name)

            # Re-encode through the same sharp/libvips pipeline the scorer uses, so
            # the only difference is one painted pixel rather than codec noise.
            script = root / 'mutate.mjs'
            script.write_text(
                'import { createRequire } from "node:module";\n'
                'const require = createRequire(import.meta.url);\n'
                'const sharp = require(process.argv[2]);\n'
                'const [src, dst] = process.argv.slice(3);\n'
                'const img = sharp(src);\n'
                'const { width, height } = await img.metadata();\n'
                'const raw = await img.ensureAlpha().raw().toBuffer();\n'
                'for (let i = 0; i < 400; i += 4) { raw[i] = 0; raw[i+1] = 0; raw[i+2] = 0; }\n'
                'await sharp(raw, { raw: { width, height, channels: 4 } }).png()'
                '.toFile(dst);\n')
            # Same resolution the scorer itself uses, via PARITY_RAFT_SOURCE.
            source = pathlib.Path(os.environ.get(
                'PARITY_RAFT_SOURCE',
                '/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab'
                '/work/raft-source'))
            sharp = source / 'packages/visual-testing/node_modules/sharp'
            result = subprocess.run(
                [node(), str(script), str(sharp), str(base / name), str(cur / name)],
                capture_output=True, text=True, check=False)
            if result.returncode != 0:
                self.skipTest(f'could not mutate the image: {result.stderr[:200]}')

            out = root / 'scores.json'
            scores = self.run_scorer(base, cur, out)
            self.assertEqual(len(scores['rows']), 1)
            self.assertLess(scores['rows'][0]['pixelPerfectSimilarity'], 1)


if __name__ == '__main__':
    unittest.main()
