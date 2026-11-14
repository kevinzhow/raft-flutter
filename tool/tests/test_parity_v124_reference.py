"""The reference tooling accepts a Web v1.24 checkout: repairs bound to v1.21.23 retire, fonts are self-hosted."""
import importlib.machinery
import importlib.util
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool'))
import parity_baseline_repairs as repairs  # noqa: E402


def load_parity():
    loader = importlib.machinery.SourceFileLoader('parity_v124_probe', str(ROOT / 'tool/parity'))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class ReferenceV124(unittest.TestCase):
    def test_repairs_apply_only_to_their_own_commit(self):
        pinned = repairs.repair_definition(ROOT)
        same = repairs.repair_definition_for(ROOT, pinned['sourceCommit'])
        self.assertTrue(same['cases'])
        other = repairs.repair_definition_for(ROOT, '1d689caf34442247cab70580d7feac1b8c302d60')
        self.assertEqual((other['cases'], other['additionalRepairs'], other['markdownCases']), ([], [], []))
        self.assertEqual(other['retiredFor'], '1d689caf34442247cab70580d7feac1b8c302d60')

    def test_self_hosted_spec_is_detected(self):
        parity = load_parity()
        self.assertTrue(parity.self_hosted_fonts('function visualFontFile(pathname: string) {'))
        self.assertFalse(parity.self_hosted_fonts('const GOOGLE_FONT_CSS_URL = "x";'))
        self.assertEqual(len(parity.SPEC_PATCHES_SELF_HOSTED), 6)


if __name__ == '__main__':
    unittest.main()
