import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool'))
import gen_l10n_index  # noqa: E402


def write(path, text):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


class L10nIndexTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = pathlib.Path(self.tmp.name)
        write(self.dir / 'zh_b.dart', "const Map<String, String> zhCatalogB = <String, String>{'a': 'b'};\n")
        write(self.dir / 'zh_a.dart', "// c\nconst Map<String, String> zhCatalogA = {\n  'x': 'y',\n};\n")
        write(self.dir / 'zh_index.g.dart', 'old')
        write(self.dir / 'other.dart', "const Map<String, String> zhCatalogOther = {};\n")

    def tearDown(self):
        self.tmp.cleanup()

    def test_discovers_zh_files_only_sorted_and_ignores_the_generated_index(self):
        self.assertEqual(gen_l10n_index.discover(self.dir), [('zh_a.dart', 'zhCatalogA'), ('zh_b.dart', 'zhCatalogB')])

    def test_render_merges_and_lists_every_catalog(self):
        text = gen_l10n_index.render(gen_l10n_index.discover(self.dir))
        for needle in ("import 'zh_a.dart' show zhCatalogA;", '  ...zhCatalogB,', "'zhCatalogA': zhCatalogA,",
                       'const zhCatalogAll', 'const zhCatalogParts'):
            self.assertIn(needle, text)

    def test_write_only_changes_the_file_when_content_differs(self):
        out = self.dir / 'out.g.dart'
        self.assertTrue(gen_l10n_index.write(out, self.dir))
        self.assertFalse(gen_l10n_index.write(out, self.dir))
        write(self.dir / 'zh_c.dart', "const Map<String, String> zhCatalogC = {};\n")
        self.assertTrue(gen_l10n_index.write(out, self.dir))

    def test_catalog_without_a_declaration_is_an_error(self):
        write(self.dir / 'zh_bad.dart', "final x = 1;\n")
        with self.assertRaises(SystemExit):
            gen_l10n_index.discover(self.dir)

    def test_repo_catalogs_are_discovered(self):
        names = {n for _, n in gen_l10n_index.discover()}
        self.assertTrue({'zhCatalogSweep', 'zhCatalogFeedback', 'zhCatalogWeb1'} <= names)


if __name__ == '__main__':
    unittest.main()
