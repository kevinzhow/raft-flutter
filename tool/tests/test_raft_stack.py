"""tool/raft-stack: multi-config selection, version patches, env and flag SQL."""
import hashlib
import importlib.machinery
import importlib.util
import json
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
_loader = importlib.machinery.SourceFileLoader('raft_stack_cli', str(ROOT / 'tool/raft-stack'))
_spec = importlib.util.spec_from_loader('raft_stack_cli', _loader)
stack = importlib.util.module_from_spec(_spec)
_loader.exec_module(stack)

PATCH_DIR = ROOT / 'tool/reference-patches'


class ArgsTest(unittest.TestCase):
    def test_sync_is_an_action(self):
        self.assertEqual(stack.parse_args(['sync'])[1], 'sync')

    def test_default_config_and_explicit_config(self):
        self.assertEqual(stack.parse_args(['start']), (stack.LOCAL / 'stack.json', 'start'))
        config, action = stack.parse_args(['--config', '/x/y.json', 'flags'])
        self.assertEqual((config, action), (pathlib.Path('/x/y.json'), 'flags'))

    def test_bad_usage_exits(self):
        for argv in ([], ['restart'], ['--config'], ['--config', 'a.json'], ['start', 'stop']):
            with self.assertRaises(SystemExit):
                stack.parse_args(argv)


class PatchSelectionTest(unittest.TestCase):
    def test_legacy_config_keeps_original_patches(self):
        self.assertEqual(stack.select_patches({}), ['seed-history', 'risingwave-memory'])

    def test_version_specific_patch_wins_and_others_fall_back(self):
        names = stack.select_patches({'sourceVersion': 'v1.21.23'})
        self.assertEqual(names, ['seed-history', 'risingwave-memory-v1.21.23'])

    def test_unknown_version_falls_back_and_patches_can_be_narrowed(self):
        self.assertEqual(stack.select_patches({'sourceVersion': 'v9.9.9'}), ['seed-history', 'risingwave-memory'])
        self.assertEqual(stack.select_patches({'patches': ['risingwave-memory']}), ['risingwave-memory'])

    def test_every_patch_manifest_has_matching_patch_and_hashes(self):
        manifests = [m for m in PATCH_DIR.glob('*.json') if m.name.startswith(('risingwave-memory', 'antiproton-local', 'seed-history'))]
        self.assertTrue(any(m.name.startswith('antiproton-local') for m in manifests))
        for manifest in manifests:
            data = json.loads(manifest.read_text())
            self.assertTrue(manifest.with_suffix('.patch').exists(), manifest.name)
            for item in data.get('files') or [data]:
                self.assertEqual(len(item['beforeSHA256']), 64, manifest.name)
                self.assertEqual(len(item['afterSHA256']), 64, manifest.name)
                self.assertNotEqual(item['beforeSHA256'], item['afterSHA256'], manifest.name)

    def test_antiproton_patch_is_selected_by_version_when_requested(self):
        config = {'sourceVersion': 'v1.21.23', 'patches': ['seed-history', 'risingwave-memory', 'antiproton-local']}
        self.assertEqual(stack.select_patches(config), ['seed-history', 'risingwave-memory-v1.21.23', 'antiproton-local-v1.21.23'])
        self.assertEqual(stack.select_patches({'sourceVersion': 'v1.21.23'}), ['seed-history', 'risingwave-memory-v1.21.23'])


class ApplyPatchesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = pathlib.Path(self.tmp.name)
        self.source = base / 'source'
        self.patches = base / 'patches'
        self.source.mkdir()
        self.patches.mkdir()
        subprocess.run(['git', 'init', '-q'], cwd=self.source, check=True)
        self.target = self.source / 'a.txt'
        self.target.write_text('one\ntwo\nthree\n')
        subprocess.run(['git', 'add', 'a.txt'], cwd=self.source, check=True)
        diff = ('--- a/a.txt\n+++ b/a.txt\n@@ -1,3 +1,3 @@\n one\n-two\n+TWO\n three\n')
        (self.patches / 'p.patch').write_text(diff)
        sha = lambda text: hashlib.sha256(text.encode()).hexdigest()
        (self.patches / 'p.json').write_text(json.dumps({
            'path': 'a.txt', 'beforeSHA256': sha('one\ntwo\nthree\n'), 'afterSHA256': sha('one\nTWO\nthree\n')}))

    def test_applies_once_and_is_idempotent(self):
        stack.apply_patches(self.source, ['p'], self.patches)
        self.assertEqual(self.target.read_text(), 'one\nTWO\nthree\n')
        stack.apply_patches(self.source, ['p'], self.patches)
        self.assertEqual(self.target.read_text(), 'one\nTWO\nthree\n')

    def test_refuses_unknown_file_state(self):
        self.target.write_text('something else\n')
        with self.assertRaises(SystemExit):
            stack.apply_patches(self.source, ['p'], self.patches)
        self.assertEqual(self.target.read_text(), 'something else\n')


class ApplyMultiFilePatchTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = pathlib.Path(self.tmp.name)
        self.source, self.patches = base / 'source', base / 'patches'
        self.source.mkdir()
        self.patches.mkdir()
        subprocess.run(['git', 'init', '-q'], cwd=self.source, check=True)
        for name in ('a.txt', 'b.txt'):
            (self.source / name).write_text('one\ntwo\nthree\n')
        subprocess.run(['git', 'add', '.'], cwd=self.source, check=True)
        diff = ''.join(f'--- a/{n}\n+++ b/{n}\n@@ -1,3 +1,3 @@\n one\n-two\n+TWO\n three\n' for n in ('a.txt', 'b.txt'))
        (self.patches / 'm.patch').write_text(diff)
        sha = lambda text: hashlib.sha256(text.encode()).hexdigest()
        item = lambda n: {'path': n, 'beforeSHA256': sha('one\ntwo\nthree\n'), 'afterSHA256': sha('one\nTWO\nthree\n')}
        (self.patches / 'm.json').write_text(json.dumps({'files': [item('a.txt'), item('b.txt')]}))

    def test_applies_all_files_once_and_reports_names(self):
        self.assertEqual(stack.apply_patches(self.source, ['m'], self.patches), ['m'])
        for name in ('a.txt', 'b.txt'):
            self.assertEqual((self.source / name).read_text(), 'one\nTWO\nthree\n')
        self.assertEqual(stack.apply_patches(self.source, ['m'], self.patches), [])

    def test_mixed_state_is_refused_and_nothing_is_touched(self):
        (self.source / 'b.txt').write_text('one\nTWO\nthree\n')
        with self.assertRaises(SystemExit):
            stack.apply_patches(self.source, ['m'], self.patches)
        self.assertEqual((self.source / 'a.txt').read_text(), 'one\ntwo\nthree\n')


class ServerEnvTest(unittest.TestCase):
    CONFIG = {'environment': 'e', 'antiprotonUrl': 'http://localhost:18921/'}
    SERVER = '0530fbb6-4480-47ec-9e0b-7be783818f39'

    def test_values_are_generated_once_and_keep_minted_tokens(self):
        first = stack.server_env_values(self.CONFIG, {}, self.SERVER)
        self.assertEqual(first['ANTIPROTON_BASE_URL_OVERRIDE'], 'http://localhost:18921')
        self.assertEqual(first['RAFTBENCH_LOCAL_SERVER_ID'], self.SERVER)
        self.assertEqual(len(__import__('base64').b64decode(first['SLOCK_PROVIDER_CREDENTIAL_KEY'])), 32)
        self.assertEqual(len(__import__('base64').b64decode(first['RAFT_APP_WEBHOOK_ENCRYPTION_KEY'])), 32)
        again = stack.server_env_values(self.CONFIG, dict(first, ANTIPROTON_PROVISIONING_TOKEN='t'), self.SERVER)
        self.assertEqual(again['SLOCK_PROVIDER_CREDENTIAL_KEY'], first['SLOCK_PROVIDER_CREDENTIAL_KEY'])
        self.assertEqual(again['ANTIPROTON_PROVISIONING_TOKEN'], 't')

    def test_drops_stale_canary_settings_and_waits_for_fixture_id(self):
        values = stack.server_env_values(self.CONFIG, {'RAFTBENCH_CANARY_SERVER_ID': 'x', 'ANTIPROTON_CANARY_PROVISIONING_TOKEN': 'y'}, None)
        self.assertNotIn('RAFTBENCH_CANARY_SERVER_ID', values)
        self.assertNotIn('ANTIPROTON_CANARY_PROVISIONING_TOKEN', values)
        self.assertNotIn('RAFTBENCH_LOCAL_SERVER_ID', values)

    def test_env_file_is_private_and_linked_into_the_server_package(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = pathlib.Path(tmp)
            source = base / 'src'
            (source / 'packages/server').mkdir(parents=True)
            (source / '.dev-env-e.json').write_text(json.dumps({'server': {'id': self.SERVER}}))
            config = dict(self.CONFIG, serverEnvFile=str(base / 'private' / 'server.env'))
            self.assertTrue(stack.prepare_server_env(config, source))
            env_file = base / 'private' / 'server.env'
            self.assertEqual(env_file.stat().st_mode & 0o777, 0o600)
            link = source / 'packages/server/.env'
            self.assertTrue(link.is_symlink())
            self.assertEqual(pathlib.Path(os.readlink(link)), env_file)
            self.assertFalse(stack.prepare_server_env(config, source))
            link.unlink()
            link.write_text('FOREIGN=1\n')
            with self.assertRaises(SystemExit):
                stack.prepare_server_env(config, source)
            self.assertEqual(link.read_text(), 'FOREIGN=1\n')

    def test_antiproton_url_is_required_with_env_file(self):
        with self.assertRaises(SystemExit):
            stack.prepare_server_env({'environment': 'e', 'serverEnvFile': '/tmp/x'}, pathlib.Path('/nonexistent'))
        self.assertFalse(stack.prepare_server_env({'environment': 'e'}, pathlib.Path('/nonexistent')))


class EnvTest(unittest.TestCase):
    CONFIG = {'toolchain': {'binDir': '/opt/node/bin', 'env': {'COREPACK_HOME': '~/cp', 'COREPACK_ENABLE_DOWNLOAD_PROMPT': '0'}}}

    def test_env_strips_npm_config_and_sets_local_only_flags(self):
        env = stack.build_env(self.CONFIG, {'PATH': '/usr/bin', 'npm_config_call': 'x', 'NPM_CONFIG_package': 'y', 'HOME': '/h'})
        self.assertNotIn('npm_config_call', env)
        self.assertNotIn('NPM_CONFIG_package', env)
        self.assertTrue(env['PATH'].startswith('/opt/node/bin' + os.pathsep))
        self.assertEqual((env['SLOCKDEV_TUNNEL'], env['SLOCKDEV_IDLE_TTL_SECONDS'], env['SLOCKDEV_TRACE_OBSERVE']), ('0', '0', '0'))
        self.assertIn('@sha256:', env['RAFTDEV_RISINGWAVE_IMAGE'])
        self.assertEqual(env['COREPACK_HOME'], os.path.expanduser('~/cp'))

    def test_wrapper_dir_exports_env_for_tmux_windows(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = stack.write_wrapper_dir(self.CONFIG, pathlib.Path(tmp) / 'w')
            script = (directory / 'pnpm').read_text()
            self.assertIn('export COREPACK_ENABLE_DOWNLOAD_PROMPT=0', script)
            self.assertIn('exec /opt/node/bin/pnpm "$@"', script)
            self.assertTrue(os.access(directory / 'pnpm', os.X_OK))
            env = stack.build_env(self.CONFIG, {'PATH': '/usr/bin'}, directory)
            self.assertTrue(env['PATH'].startswith(str(directory) + os.pathsep + '/opt/node/bin'))

    def test_no_wrapper_without_toolchain_env(self):
        self.assertIsNone(stack.write_wrapper_dir({'toolchain': {'binDir': '/opt/node/bin'}}, pathlib.Path('/nonexistent/w')))


class FlagSqlTest(unittest.TestCase):
    SERVER = '0530fbb6-4480-47ec-9e0b-7be783818f39'

    def test_sql_is_idempotent_and_scoped_to_server(self):
        sql = stack.feature_flag_sql(['raftbench_overview_v0'], self.SERVER)
        self.assertIn('ON CONFLICT (key) DO NOTHING', sql)
        self.assertIn('WHERE NOT EXISTS', sql)
        self.assertIn("default_enabled", sql)
        self.assertIn(self.SERVER, sql)
        self.assertTrue(sql.startswith('BEGIN;') and sql.rstrip().endswith('COMMIT;'))

    def test_plan_sql_is_scoped_and_validated(self):
        self.assertEqual(stack.fixture_plan_sql('founder', self.SERVER),
                         f"UPDATE servers SET plan = 'founder' WHERE id = '{self.SERVER}';\n")
        with self.assertRaises(SystemExit):
            stack.fixture_plan_sql("pro'; DROP TABLE servers;--", self.SERVER)
        with self.assertRaises(SystemExit):
            stack.fixture_plan_sql('pro', "x' OR '1'='1")

    def test_rejects_unsafe_input(self):
        with self.assertRaises(SystemExit):
            stack.feature_flag_sql(["x'; DROP TABLE feature_flags;--"], self.SERVER)
        with self.assertRaises(SystemExit):
            stack.feature_flag_sql(['ok_flag'], "x' OR '1'='1")


if __name__ == '__main__':
    unittest.main()
