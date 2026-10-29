"""tool/antiproton-local: generated Worker config, secret handling and the local-Raft patch manifest."""
import importlib.machinery
import importlib.util
import json
import os
import pathlib
import re
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
_loader = importlib.machinery.SourceFileLoader('antiproton_local_cli', str(ROOT / 'tool/antiproton-local'))
_spec = importlib.util.spec_from_loader('antiproton_local_cli', _loader)
ap = importlib.util.module_from_spec(_spec)
_loader.exec_module(ap)

PATCH_DIR = ROOT / 'tool/reference-patches'


class WorkerConfigTest(unittest.TestCase):
    def setUp(self):
        self.config = ap.wrangler_config('/src/antiproton', 18921, '/run/entry.ts')

    def test_local_only_bindings_without_routes_crons_or_secrets(self):
        self.assertNotIn('routes', self.config)
        self.assertNotIn('triggers', self.config)
        self.assertEqual(self.config['main'], '/run/entry.ts')
        self.assertEqual(self.config['d1_databases'][0]['migrations_dir'], '/src/antiproton/cf/migrations')
        text = json.dumps(self.config)
        self.assertNotIn('antiproton.ai', text.replace('https://api.deepseek.com', ''))
        for secret_name in ('AUTOMATION_TOKEN', 'SECRET_KEK'):
            self.assertNotIn(secret_name, self.config['vars'])
        self.assertEqual(self.config['vars']['DEEPSEEK_BASE_URL'], 'https://api.deepseek.com')

    def test_hook_origin_follows_the_port_and_only_deepseek_is_offered(self):
        self.assertEqual(self.config['vars']['HOOK_ORIGIN'], 'http://localhost:18921')
        self.assertEqual([p['id'] for p in self.config['vars']['MODEL_PROVIDERS']], ['deepseek'])
        self.assertEqual([m['id'] for m in self.config['vars']['USER_MODELS']], ['deepseek-flash'])

    def test_entry_module_exports_only_handler_and_classes(self):
        text = ap.entry_module('/src/antiproton')
        self.assertEqual(text, 'export { default, AgentDO, SandboxTools } from "/src/antiproton/cf/src/index.ts";\n')


class SecretsTest(unittest.TestCase):
    def test_reads_the_ref_under_refs_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / 'creds.yaml'
            path.write_text('version: 1\nrecords:\n  DEEPSEEK_API_KEY:\n    kind: x\nrefs:\n  OTHER: nope\n  DEEPSEEK_API_KEY: "sk-test-value"\n')
            self.assertEqual(ap.read_yaml_ref(path, 'DEEPSEEK_API_KEY'), 'sk-test-value')
            self.assertIsNone(ap.read_yaml_ref(path, 'MISSING'))

    def test_env_files_are_written_mode_600_and_round_trip(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / 'sub' / 'vars'
            ap.write_env_file(path, {'A': '1', 'B': 'x=y'})
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(ap.read_env_file(path), {'A': '1', 'B': 'x=y'})
            ap.write_env_file(path, {'A': '2'})
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_usage_and_config_errors_exit(self):
        for argv in ([], ['setup'], ['--config', 'x.json'], ['--config', 'x.json', 'bogus']):
            with self.assertRaises(SystemExit):
                ap.parse_args(argv)
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(SystemExit):
                ap.load_config(pathlib.Path(tmp) / 'missing.json')


class LocalRaftPatchTest(unittest.TestCase):
    def test_manifest_lists_exactly_the_files_the_patch_touches(self):
        manifest = json.loads((PATCH_DIR / 'antiproton-local-v1.21.23.json').read_text())
        touched = set(re.findall(r'^diff --git a/(\S+) b/', (PATCH_DIR / 'antiproton-local-v1.21.23.patch').read_text(), re.M))
        self.assertEqual({item['path'] for item in manifest['files']}, touched)
        self.assertFalse(any(path.startswith('scripts/') for path in touched))

    def test_patch_is_inert_without_the_override(self):
        patch = (PATCH_DIR / 'antiproton-local-v1.21.23.patch').read_text()
        self.assertIn('DEPLOYMENT_ENV?.trim() !== "slockdev"', patch)
        self.assertIn('ANTIPROTON_BASE_URL_OVERRIDE', patch)


if __name__ == '__main__':
    unittest.main()
