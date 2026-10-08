"""tool/gen-tokens: colour science, CSS resolution, oracle parity, freshness."""
import importlib.machinery
import importlib.util
import json
import pathlib
import re
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
_loader = importlib.machinery.SourceFileLoader('gen_tokens', str(ROOT / 'tool/gen-tokens'))
_spec = importlib.util.spec_from_loader('gen_tokens', _loader)
gen = importlib.util.module_from_spec(_spec)
sys.modules['gen_tokens'] = gen  # dataclasses resolve their module by name
_loader.exec_module(gen)

# Translucent swatches whose Chrome bytes no non-negative Flutter source-over
# reproduces (Chrome truncates the destination term; the dark accent edge is
# out of gamut). Mirrors _fitExceptions in packages/raft_ui/test/design_tokens_test.dart.
FIT_EXCEPTIONS = {
    ('elegantDark', 'layer-backdrop', 'canvas'),
    ('elegantDark', 'field-inset-top', 'canvas'),
    ('elegantDark', 'button-accent-edge', 'canvas'),
    ('elegantDark', 'button-accent-edge', 'black'),
}


class ColourScience(unittest.TestCase):
    def rgb(self, css):
        return gen.parse_color(css).bytes()

    def test_achromatic_endpoints(self):
        self.assertEqual(self.rgb('oklch(1 0 0)'), (255, 255, 255))
        self.assertEqual(self.rgb('oklch(0 0 0)'), (0, 0, 0))
        # Mid grey: L=0.5 is linear 0.125 -> sRGB 99.
        self.assertEqual(self.rgb('oklch(0.5 0 0)'), (99, 99, 99))

    def test_reference_primaries(self):
        # CSS Color 4 published OKLCH coordinates of the sRGB primaries.
        self.assertEqual(self.rgb('oklch(0.627955 0.257683 29.2339)'), (255, 0, 0))
        self.assertEqual(self.rgb('oklch(0.86644 0.294827 142.4953)'), (0, 255, 0))
        self.assertEqual(self.rgb('oklch(0.452014 0.313214 264.052)'), (0, 0, 255))

    def test_round_trip_through_oklab(self):
        lab = gen.linear_srgb_to_oklab(gen.oklch_to_linear_srgb(0.5, 0.1, 40))
        # float32 pipeline: ~1e-7 round-trip error.
        self.assertAlmostEqual(lab[0], 0.5, places=6)
        self.assertAlmostEqual((lab[1] ** 2 + lab[2] ** 2) ** 0.5, 0.1, places=6)

    def test_out_of_gamut_clips_per_channel_like_chrome(self):
        c = gen.parse_color('oklch(0.44 0.09 91.39)')  # --primary-strong
        self.assertFalse(c.in_gamut())
        self.assertLess(c.srgb()[2], 0)  # blue < 0 before clipping
        self.assertEqual(c.bytes(), (101, 80, 0))  # browser oracle value
        # No CSS Color 4 chroma reduction: red/green keep their unmapped values.
        self.assertEqual(self.rgb('oklch(0.52 0.215 359.77)'), (192, 0, 100))

    def test_alpha_is_exact(self):
        c = gen.parse_color('oklch(0.985 0.004 106.42 / 0.1)')
        self.assertEqual(c.alpha, 0.1)
        self.assertEqual(gen.dart_color(c), 'Color.fromRGBO(250, 250, 247, 0.1)')
        self.assertEqual(gen.parse_color('oklch(0 0 0 / 65%)').alpha, 0.65)

    def test_hex_and_rgb(self):
        self.assertEqual(self.rgb('#27CCF3'), (39, 204, 243))
        self.assertEqual(self.rgb('#fff'), (255, 255, 255))
        self.assertEqual(gen.parse_color('rgb(20 17 17 / 35%)').alpha, 0.35)
        self.assertEqual(gen.parse_color('rgba(0, 0, 0, 0.08)').alpha, 0.08)

    def test_color_mix_srgb_linear(self):
        # 50% white + black in linear light = 0.5 linear = 188 in sRGB.
        self.assertEqual(self.rgb('color-mix(in srgb-linear, white 50%, black)'), (188, 188, 188))
        # Premultiplied: a transparent partner only scales alpha.
        c = gen.parse_color('color-mix(in srgb-linear, oklch(0.52 0.215 359.77) 28%, transparent)')
        self.assertEqual(c.bytes(), (192, 0, 100))
        self.assertAlmostEqual(c.alpha, 0.28)
        # Unequal alphas: result alpha is the weighted sum, channels premultiplied.
        c = gen.parse_color('color-mix(in srgb-linear, rgb(255 0 0 / 0.16) 78%, rgb(0 0 255))')
        self.assertAlmostEqual(c.alpha, 0.78 * 0.16 + 0.22)
        self.assertAlmostEqual(c.r, 0.78 * 0.16 / c.alpha)

    def test_color_mix_oklch(self):
        c = gen.parse_color('color-mix(in oklch, oklch(0.21 0.006 106.42 / 0.04), oklch(1 0 0))')
        self.assertEqual(c.bytes(), (245, 245, 245))
        self.assertAlmostEqual(c.alpha, 0.52)

    def test_shadow_parsing(self):
        layers = gen.parse_shadows('inset 0 1px 0 oklch(0.985 0.004 106.42 / 0.06), 0 10px 20px -6px oklch(0 0 0 / 0.45)')
        self.assertTrue(layers[0].inset)
        self.assertEqual((layers[0].x, layers[0].y, layers[0].blur, layers[0].spread), (0, 1, 0, 0))
        self.assertEqual((layers[1].y, layers[1].blur, layers[1].spread), (10, 20, -6))
        self.assertFalse(layers[1].inset)


class CascadeResolution(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = gen.Model()

    def test_elegant_dark_inherits_root_hover_formula_with_dark_ink(self):
        # --primary-active is declared only in the root block; it must mix the
        # dark --ink (near white), so it is lighter than --primary-400.
        dark = self.m.color('elegantDark', '--primary-active').bytes()
        base = self.m.color('elegantDark', '--primary-400').bytes()
        self.assertGreater(sum(dark), sum(base))
        self.assertEqual(self.m.declared_in['--primary-active'], ['brutal'])

    def test_every_theme_resolves_every_semantic_name(self):
        for theme in gen.THEMES:
            for name in self.m.semantic_color_names():
                self.m.color(theme, name)

    def test_product_overrides_win_over_raft_ui_aliases(self):
        self.assertEqual(self.m.color('brutal', '--color-brutal-cyan').bytes(), (39, 204, 243))
        self.assertEqual(self.m.color('brutal', '--color-brutal-cyan-400').bytes(), (40, 204, 243))
        self.assertEqual(self.m.color('elegantDark', '--color-code-surface').bytes(), (10, 12, 16))

    def test_metrics(self):
        scope = self.m.scopes['elegantLight']
        self.assertEqual(scope.resolve('--field-font-size'), '14px')
        self.assertEqual(scope.resolve('--card-title-line-height'), '22px')


class ChromeOracle(unittest.TestCase):
    """tool/design-source/chrome-oracle.json: bytes painted by the parity Chromium."""

    @classmethod
    def setUpClass(cls):
        cls.m = gen.Model()
        cls.oracle = cls.m.oracle

    def test_oracle_matches_sources_and_browser(self):
        self.assertEqual(self.oracle['chromium'], '147.0.7727.15')
        self.assertEqual(self.oracle['args'], gen.CHROMIUM_ARGS)
        manifest = json.loads((gen.SRC / 'manifest.json').read_text())['files']
        for key, rel in gen.SOURCES.items():
            self.assertEqual(self.oracle['sources'][key], manifest[rel]['sha256'], 're-run --sample-chrome')

    def test_opaque_tokens_equal_chrome_bytes(self):
        compared = 0
        for theme, samples in self.oracle['themes'].items():
            for key, sample in samples.items():
                c = self.m.color(theme, '--' + key)
                if c.alpha < 1:
                    continue
                with self.subTest(theme=theme, token=key):
                    self.assertEqual(list(c.bytes()), sample['white'])
                compared += 1
        self.assertEqual(compared, 657)

    def test_spec_pipeline_is_off_by_one_on_known_tokens(self):
        # The rule that makes the difference: without the Chromium D50 path the
        # CSS sample-code maths rounds these to the neighbouring byte.
        old = gen.PIPELINE
        try:
            gen.PIPELINE = 'spec'
            self.assertEqual(gen.parse_color('oklch(0.714 0.176 153.079)').bytes(), (32, 193, 107))
        finally:
            gen.PIPELINE = old
        self.assertEqual(gen.parse_color('oklch(0.714 0.176 153.079)').bytes(), (31, 193, 107))

    def test_translucent_fits_composite_to_chrome_bytes(self):
        misses, compared = set(), 0
        for theme, samples in self.oracle['themes'].items():
            backs = self.m.backdrop_bytes(theme)
            for key, sample in samples.items():
                fit = self.m.chrome_fit(theme, '--' + key)
                if fit is None:
                    continue
                a, chans = fit
                for b in gen.FIT_BACKDROPS:
                    compared += 1
                    got = [gen.flutter_over(chans[i], a, backs[b][i]) for i in range(3)]
                    if got != sample[b]:
                        misses.add((theme, key, b))
        self.assertEqual(compared, 216)
        self.assertEqual(misses, FIT_EXCEPTIONS)

    def test_recipe_opaque_literals_equal_chrome_bytes(self):
        literals = self.oracle['literals']
        compared = 0
        for path in sorted(gen.RECIPES_DIR.glob('*.g.dart')):
            for argb, src in re.findall(r"CssColor\(0x([0-9A-Fa-f]{8}), '([^']+)'", path.read_text()):
                v = int(argb, 16)
                if v >> 24 != 255:
                    continue
                with self.subTest(literal=src):
                    self.assertEqual([(v >> 16) & 255, (v >> 8) & 255, v & 255], literals[src]['brutal']['white'])
                compared += 1
        self.assertGreaterEqual(compared, 77)


class LegacyReadbackOracle(unittest.TestCase):
    """docs/theme-tokens/*.json: earlier canvas getImageData() readbacks
    (premultiplied 8-bit storage, simulated before comparing)."""

    def test_generated_matches_readback_oracle(self):
        rows = gen.oracle_report()
        self.assertFalse([r for r in rows if r.get('status') == 'missing'])
        compared = [r for r in rows if 'rawDelta' in r]
        self.assertEqual(len(compared), 78)
        for r in compared:
            with self.subTest(token=(r['theme'], r['token'])):
                self.assertEqual(r['alphaByteDelta'], 0)
                self.assertEqual(r['readbackDelta'], 0)


class Freshness(unittest.TestCase):
    def test_vendored_sources_match_manifest(self):
        gen.verify_manifest()

    def test_generated_dart_is_up_to_date(self):
        files = gen.render()
        for name, text in files.items():
            with self.subTest(file=name):
                self.assertEqual((gen.OUT / name).read_text(), text, 'run tool/gen-tokens')
        on_disk = {p.name for p in gen.OUT.glob('*.g.dart')}
        self.assertEqual(on_disk, set(files))
        self.assertEqual(gen.LITERAL_FITS.read_text(), gen.literal_fits(gen.Model()), 'run tool/gen-tokens')


if __name__ == '__main__':
    unittest.main()
