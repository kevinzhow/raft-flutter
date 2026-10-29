import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

import reference_contract as policy


class ThemeContractTests(unittest.TestCase):
    def test_current_web_defaults_to_raft_even_for_historical_case_names(self):
        env = {}
        self.assertEqual(policy.configure_theme(frozen=False, env=env), 'raft-case')
        self.assertEqual(env['PARITY_THEME_OVERRIDE'], 'raft-case')
        self.assertEqual(policy.expected_theme(self.case('brutal-light'), 'raft-case'), 'raft-light')
        self.assertEqual(policy.expected_theme(self.case('elegant-dark'), 'raft-case'), 'raft-dark')

    @staticmethod
    def case(theme):
        return {'id': 'real-entry.' + theme, 'variants': [{'props': {'parityTheme': theme}}]}

    def test_legacy_look_cannot_be_scored_against_current_web(self):
        for look in ['brutal-light', 'elegant-dark', 'elegant-case']:
            with self.subTest(look=look), self.assertRaises(policy.InvalidComparison):
                policy.configure_theme(frozen=False, env={'PARITY_THEME_OVERRIDE': look})

    def test_frozen_mode_preserves_its_existing_selection(self):
        env = {}
        self.assertIsNone(policy.configure_theme(frozen=True, env=env))
        self.assertEqual(env, {})
        self.assertEqual(policy.configure_theme(frozen=True, env={'PARITY_THEME_OVERRIDE': 'elegant-dark'}), 'elegant-dark')

    def test_modern_override_cannot_be_applied_to_frozen_reference(self):
        with self.assertRaises(policy.InvalidComparison):
            policy.configure_theme(frozen=True, env={'PARITY_THEME_OVERRIDE': 'raft-case'})

    def test_metadata_context_rejects_the_actual_wrong_look_regression(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            case = self.case('brutal-light')
            (root / (case['id'] + '.png')).write_bytes(b'capture placeholder')
            meta = {'source': 'flutter', 'caseId': case['id'], 'theme': 'brutal-light'}
            (root / (case['id'] + '.metadata.json')).write_text(json.dumps(meta))
            result = policy.validate_flutter_metadata([case], root, 'raft-case')
            self.assertEqual(result['status'], 'INADMISSIBLE')
            self.assertEqual(len(result['errors']), 1)

    def test_valid_context_does_not_hide_a_product_geometry_failure(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            case = self.case('elegant-dark')
            (root / (case['id'] + '.png')).write_bytes(b'capture placeholder')
            meta = {'source': 'flutter', 'caseId': case['id'], 'theme': 'raft-dark', 'crop': {'rect': {'width': 1}}}
            (root / (case['id'] + '.metadata.json')).write_text(json.dumps(meta))
            result = policy.validate_flutter_metadata([case], root, 'raft-case')
            self.assertEqual(result['status'], 'VALIDATED')
            self.assertEqual(result['checkedImages'], 1)

    def test_png_without_metadata_is_inadmissible(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); case = self.case('brutal-light')
            (root / (case['id'] + '.png')).write_bytes(b'capture placeholder')
            self.assertEqual(policy.validate_flutter_metadata([case], root, 'raft-case')['status'], 'INADMISSIBLE')

    def test_absent_images_do_not_produce_a_vacuous_context_pass(self):
        with tempfile.TemporaryDirectory() as name:
            result = policy.validate_flutter_metadata([self.case('brutal-light')], Path(name), 'raft-case')
            self.assertEqual(result['status'], 'NOT_RUN')
            self.assertEqual(result['checkedImages'], 0)


class SourceContractTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / 'reference'; self.root.mkdir()
        self.web = self.root / 'packages/web'; self.web.mkdir(parents=True)
        (self.web / 'src').mkdir(); (self.web / 'src/entry.tsx').write_text('export const source = 1;\n')
        (self.web / 'package.json').write_text(json.dumps({'version': '1.21.23'}))
        self.pkg = self.web / 'node_modules/@botiverse/raft-ui'; (self.pkg / 'dist').mkdir(parents=True)
        (self.pkg / 'package.json').write_text(json.dumps({'version': '0.7.0'}))
        (self.pkg / 'dist/index.mjs').write_text('export const recipe = 1;\n')
        (self.root / '.gitignore').write_text('node_modules/\n')
        def git(*args):
            return subprocess.check_output(['git', *args], cwd=self.root, text=True, stderr=subprocess.DEVNULL).strip()
        git('init', '-q'); git('config', 'user.name', 'Reference fixture'); git('config', 'user.email', 'fixture@example.invalid')
        git('add', '.'); git('-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixed source fixture')
        self.contract = {'webCommit': git('rev-parse', 'HEAD'), 'webVersion': '1.21.23', 'raftUIVersion': '0.7.0',
                         'raftUIFiles': {'dist/index.mjs': hashlib.sha256((self.pkg / 'dist/index.mjs').read_bytes()).hexdigest()}}

    def test_symlink_input_resolves_to_the_canonical_vite_path(self):
        alias = Path(self.tmp.name) / 'alias'; alias.symlink_to(self.root, target_is_directory=True)
        self.assertEqual(policy.validate_reference(alias, self.contract)['sourceRoot'], str(self.root))

    def test_wrong_web_commit_is_rejected(self):
        with self.assertRaisesRegex(policy.InvalidComparison, 'Web commit'):
            policy.validate_reference(self.root, {**self.contract, 'webCommit': 'old-reference'})

    def test_wrong_installed_package_version_is_rejected(self):
        (self.pkg / 'package.json').write_text(json.dumps({'version': '0.5.27'}))
        with self.assertRaisesRegex(policy.InvalidComparison, 'UI version'):
            policy.validate_reference(self.root, self.contract)

    def test_modified_published_chunk_is_rejected_even_if_version_matches(self):
        (self.pkg / 'dist/index.mjs').write_text('export const recipe = 2;\n')
        with self.assertRaisesRegex(policy.InvalidComparison, 'UI published files'):
            policy.validate_reference(self.root, self.contract)

    def test_unreviewed_extra_published_chunk_is_rejected(self):
        (self.pkg / 'dist/extra.mjs').write_text('export const hidden = 1;\n')
        with self.assertRaisesRegex(policy.InvalidComparison, 'UI published files'):
            policy.validate_reference(self.root, self.contract)

    def test_tracked_web_changes_are_rejected(self):
        (self.web / 'src/entry.tsx').write_text('export const source = 2;\n')
        with self.assertRaisesRegex(policy.InvalidComparison, 'tracked Web source changes'):
            policy.validate_reference(self.root, self.contract)


if __name__ == '__main__':
    unittest.main()
