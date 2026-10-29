"""tool/parity-ui: the specimen list, the generated manifest and the host renderers stay in step."""
import importlib.machinery
import importlib.util
import json
import pathlib
import re
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
UI = ROOT / 'tool/parity-ui'


def load_run(out):
    import os
    os.environ['PARITY_UI_OUT'] = out
    loader = importlib.machinery.SourceFileLoader('parity_ui_run_under_test', str(UI / 'run'))
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
    loader.exec_module(module)
    return module


class ParityUiTest(unittest.TestCase):
    def test_manifest_has_every_specimen_in_every_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            run = load_run(tmp)
            _, cases = run.build_manifest()
        spec = json.loads((UI / 'specimens.json').read_text())
        ids = [c['id'] for c in cases]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(len(ids), len(spec['specimens']) * len(spec['modes']))
        for c in cases:
            self.assertTrue(c['id'].startswith('components.raft-ui.'))
            self.assertEqual(c['captureType'], 'component-fixture')
            self.assertTrue(c['capture']['selector'] and c['tolerance']['pixelRatio'])

    def test_every_specimen_has_a_renderer(self):
        spec = json.loads((UI / 'specimens.json').read_text())
        source = (UI / 'host/src/specimens.tsx').read_text()
        registered = set(re.findall(r'^\s+"([a-z-]+\.[a-z-]+)": \w+,$', source, re.M))
        self.assertEqual({s['id'] for s in spec['specimens']}, registered)

    def test_raft_ui_version_is_pinned_everywhere(self):
        spec = json.loads((UI / 'specimens.json').read_text())
        pkg = json.loads((UI / 'host/package.json').read_text())
        self.assertEqual(pkg['dependencies']['@botiverse/raft-ui'], spec['raftUi'])
        for name, version in pkg['dependencies'].items():
            self.assertRegex(version, r'^\d+\.\d+\.\d+$', f'{name} must be an exact version')
        self.assertIn(f"'@botiverse/raft-ui@{spec['raftUi']}", (UI / 'host/pnpm-lock.yaml').read_text())


if __name__ == '__main__':
    unittest.main()
