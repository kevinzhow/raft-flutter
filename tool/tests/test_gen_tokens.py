"""tool/gen-tokens: colour science, CSS resolution, oracle parity, freshness."""
import importlib.machinery
import importlib.util
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
_loader = importlib.machinery.SourceFileLoader('gen_tokens', str(ROOT / 'tool/gen-tokens'))
_spec = importlib.util.spec_from_loader('gen_tokens', _loader)
gen = importlib.util.module_from_spec(_spec)
sys.modules['gen_tokens'] = gen  # dataclasses resolve their module by name
_loader.exec_module(gen)

# Oracle tokens whose 8-bit value differs by exactly 1 from round(exact sRGB).
# All three exact channel values sit within 0.02 of a .5 rounding boundary, so
# Chrome's float32 skcms transfer-function approximation lands on the other
# side. Listed with the exact value so a real regression cannot hide here.
NEAR_TIE_EXCEPTIONS = {
    ('elegantLight', 'warning-soft'): 222.484,   # oklch(0.95 0.03 44.33) blue
    ('elegantLight', 'info-strong'): 9.501,      # oklch(0.441 0.078 221.2) red
    ('elegantDark', 'line-strong'): 238.503,     # oklch(0.95 0.003 106.42) red
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
        self.assertAlmostEqual(lab[0], 0.5, places=9)
        self.assertAlmostEqual((lab[1] ** 2 + lab[2] ** 2) ** 0.5, 0.1, places=9)

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


class OracleParity(unittest.TestCase):
    def test_generated_matches_browser_oracle(self):
        rows = gen.oracle_report()
        self.assertFalse([r for r in rows if r.get('status') == 'missing'])
        compared = [r for r in rows if 'rawDelta' in r]
        self.assertEqual(len(compared), 78)
        for r in compared:
            key = (r['theme'], r['token'])
            with self.subTest(token=key):
                self.assertEqual(r['alphaByteDelta'], 0)
                # Translucent oracle entries are canvas readbacks (premultiplied
                # 8-bit); compare after simulating that storage.
                self.assertLessEqual(r['readbackDelta'], 1)
                if r['readbackDelta'] == 1:
                    self.assertIn(key, NEAR_TIE_EXCEPTIONS)
                    exact = NEAR_TIE_EXCEPTIONS[key]
                    self.assertIn(exact, r['srgb255'])
                    self.assertLess(abs(exact % 1 - 0.5), 0.02)
                if r['alpha'] == 1:
                    self.assertEqual(r['rawDelta'], r['readbackDelta'])


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


if __name__ == '__main__':
    unittest.main()
