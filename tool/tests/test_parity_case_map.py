import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool'))
import parity_case_map  # noqa: E402


def write(path, text):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


class CaseMapGeneratorTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.cases = pathlib.Path(self.tmp.name) / 'cases'
        write(self.cases / 'ext_b.dart', "final Map<String, ParityCase> extBCases = {};\n"
              "final Map<String, ParityCase> _private = {};\n"
              "final Map<String, ParityUncovered> extBUncovered = {};\n")
        write(self.cases / 'ext_a.dart', "final Map<String, ParityCase> extACases = () {\n  return {};\n}();\n"
              "  final Map<String, ParityCase> indented = {};\n")  # not top level
        write(self.cases / 'ext_a_keys.g.dart', "final Map<String, ParityCase> generatedCases = {};\n")
        write(self.cases / 'sub/more.dart', "const Map<String, ParityCase>   moreCases = {};\n")

    def tearDown(self):
        self.tmp.cleanup()

    def test_discovers_public_top_level_maps_sorted(self):
        found = parity_case_map.discover(self.cases)
        self.assertEqual(found['cases'], [('ext_a.dart', 'extACases'), ('ext_b.dart', 'extBCases'),
                                          ('sub/more.dart', 'moreCases')])
        self.assertEqual(found['uncovered'], [('ext_b.dart', 'extBUncovered')])

    def test_render_imports_and_merges_every_map(self):
        text = parity_case_map.render(parity_case_map.discover(self.cases))
        for needle in ("import 'cases/ext_a.dart' show extACases;", "import 'cases/ext_b.dart' show extBCases, extBUncovered;",
                       "import 'cases/sub/more.dart' show moreCases;", "MapEntry('extACases', extACases),",
                       "MapEntry('extBUncovered', extBUncovered),"):
            self.assertIn(needle, text)
        self.assertNotIn('_private', text)
        self.assertNotIn('generatedCases', text)
        self.assertIn('is declared by both', text)  # duplicate ids fail loudly at startup

    def test_write_only_changes_the_file_when_content_differs(self):
        out = pathlib.Path(self.tmp.name) / 'case_map.g.dart'
        self.assertTrue(parity_case_map.write(out, self.cases))
        self.assertFalse(parity_case_map.write(out, self.cases))
        write(self.cases / 'ext_c.dart', "final Map<String, ParityCase> extCCases = {};\n")
        self.assertTrue(parity_case_map.write(out, self.cases))
        self.assertIn('extCCases', out.read_text())

    def test_repo_case_files_are_all_discovered(self):
        found = parity_case_map.discover()
        names = {n for _, n in found['cases']}
        self.assertTrue({'uiPrimitiveCases', 'extShellCases', 'extMembersPagesChannelCases'} <= names)
        self.assertIn('extAuthPagesUncovered', {n for _, n in found['uncovered']})
        # the committed entry point only re-exports the generated file
        entry = (ROOT / 'apps/raft_flutter/test/parity/case_map.dart').read_text()
        self.assertIn("export 'case_map.g.dart';", entry)
        self.assertNotIn('import ', entry)


if __name__ == '__main__':
    unittest.main()
