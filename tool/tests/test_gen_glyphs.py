"""tool/gen-glyphs: vendored Lucide data, naming/provenance rules, freshness."""
import importlib.machinery
import importlib.util
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
_loader = importlib.machinery.SourceFileLoader('gen_glyphs', str(ROOT / 'tool/gen-glyphs'))
_spec = importlib.util.spec_from_loader('gen_glyphs', _loader)
gen = importlib.util.module_from_spec(_spec)
sys.modules['gen_glyphs'] = gen
_loader.exec_module(gen)


class GenGlyphs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = gen.load_vendor()
        entries, cls.used = gen.build_model(cls.doc)
        cls.by = {e['name']: e for e in entries}

    def test_generated_dart_is_fresh(self):
        self.assertEqual(gen.OUT.read_text(), gen.render(self.doc),
                         'glyphs.g.dart is stale; run tool/gen-glyphs')

    def test_every_web_and_raft_ui_import_has_a_glyph(self):
        for build in ('web', 'raftUi'):
            for export in self.doc['usages'][build]:
                name = gen.lower_camel(export)
                self.assertTrue(name in self.by or name + 'RaftUi' in self.by, f'{build} {export}')

    def test_provenance(self):
        icons = self.doc['icons']
        self.assertEqual(icons[self.by['checkSquare']['key']]['icon'], 'square-check-big')
        self.assertEqual(icons[self.by['home']['key']]['icon'], 'house')
        self.assertEqual(self.by['checkCircle2']['key'], 'circle-check@0.575.0')
        self.assertEqual(self.by['checkCircle2RaftUi']['key'], 'circle-check@1.48.0')
        self.assertEqual(self.by['minus']['key'], 'minus@1.48.0')  # only raft-ui imports Minus
        self.assertTrue(self.by['bookmarkFilled']['filled'])
        # Web names always carry the Web (0.575.0) build.
        for e in self.by.values():
            if e['web']:
                self.assertTrue(e['key'].endswith('@' + gen.WEB_LUCIDE), e['name'])

    def test_legacy_names_still_exist(self):
        for name in gen.LEGACY + list(gen.FILLED):
            self.assertIn(name, self.by)

    def test_node_emission(self):
        rect = {'tag': 'rect', 'attrs': {'width': '18', 'height': '18', 'x': '3', 'y': '3', 'rx': '2'}}
        self.assertEqual(gen.dart_node(rect), '_LucideNode(_LucideKind.rect, [3.0, 3.0, 18.0, 18.0, 2.0, 2.0])')
        dot = {'tag': 'circle', 'attrs': {'cx': '13.5', 'cy': '6.5', 'r': '.5'}, 'fill': 'currentColor'}
        self.assertEqual(gen.dart_node(dot), '_LucideNode(_LucideKind.circle, [13.5, 6.5, 0.5], fill: true)')
        poly = {'tag': 'polyline', 'attrs': {'points': '22 12 16 12 14 15'}}
        self.assertIn('[22.0, 12.0, 16.0, 12.0, 14.0, 15.0]', gen.dart_node(poly))

    def test_js_literal_reader(self):
        text = 'const __iconNode = [\n  ["path", { d: "M12 20h.01", key: "abc" }],\n  ["circle", { cx: "12", cy: "12", r: "1", fill: "currentColor", key: "x" }]\n];'
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / 'probe.js'
            path.write_text(text)
            nodes = gen.read_icon_nodes(path)
        self.assertEqual(nodes[0], {'tag': 'path', 'attrs': {'d': 'M12 20h.01'}})
        self.assertEqual(nodes[1]['fill'], 'currentColor')

    def test_import_scan_handles_aliases_and_types(self):
        src = 'import {\n  Image as ImageIcon,\n  type LucideIcon,\n  X,\n} from "lucide-react";\nimport type { LucideProps } from "lucide-react";\n'
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / 'probe.tsx'
            path.write_text(src)
            found = list(gen.scan_imports(path, 'probe.tsx'))
        self.assertEqual(found, [('Image', 'probe.tsx:2'), ('X', 'probe.tsx:4')])


if __name__ == '__main__':
    unittest.main()
