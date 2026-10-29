import base64
from contextlib import redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    'android_release_signing', Path(__file__).resolve().parents[1] / 'android-release-signing.py')
signing = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(signing)


class AndroidReleaseSigningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name) / 'signing'
        self.addCleanup(patch.stopall)
        patch.object(signing, 'DIRECTORY', self.directory).start()
        patch.dict(signing.os.environ, {}, clear=True).start()

    def fixture(self):
        self.directory.mkdir(mode=0o700)
        self.keystore = self.directory / 'release.jks'
        self.keystore.write_bytes(b'fixture key bytes')
        self.values = dict(zip(signing.SECRET_NAMES[1:], ['store-password', 'raft-release', 'key-password']))
        signing.private_write(self.directory / 'credentials.json', json.dumps(self.values))

    def test_existing_identity_is_never_replaced(self):
        self.fixture()
        with patch.object(signing, 'keytool', return_value='keytool'), \
                patch.object(signing.subprocess, 'run') as run:
            with self.assertRaises(FileExistsError):
                signing.create()
            run.assert_not_called()
        self.assertEqual(signing.export_values()['RAFT_ANDROID_STORE_PASSWORD'], 'store-password')
        self.assertEqual(self.keystore.read_bytes(), b'fixture key bytes')

    def test_private_export_is_exclusive_and_owner_only(self):
        target = Path(self.temp.name) / 'secrets.json'
        signing.private_write(target, 'original')
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)
        with self.assertRaises(FileExistsError):
            signing.private_write(target, 'replacement')
        self.assertEqual(target.read_text(), 'original')

    def test_export_has_the_four_ci_names_and_exact_keystore_bytes(self):
        self.fixture()
        values = signing.export_values()
        self.assertEqual(set(values), set(signing.SECRET_NAMES))
        self.assertEqual(base64.b64decode(values['RAFT_ANDROID_KEYSTORE_BASE64'], validate=True),
                         self.keystore.read_bytes())
        self.assertEqual({key: values[key] for key in self.values}, self.values)

    def test_corrupt_credentials_and_empty_keystore_are_rejected(self):
        self.fixture()
        self.keystore.write_bytes(b'')
        with self.assertRaisesRegex(ValueError, 'Empty keystore'):
            signing.export_values()
        (self.directory / 'credentials.json').write_text('{"wrong": "secret"}')
        with self.assertRaisesRegex(ValueError, 'Invalid signing credentials'):
            signing.export_values()

    def test_ci_cannot_generate_or_export_private_material(self):
        self.fixture()
        for name in ['CI', 'GITHUB_ACTIONS']:
            with self.subTest(name=name), patch.dict(signing.os.environ, {name: 'true'}):
                output = io.StringIO()
                with redirect_stdout(output), self.assertRaisesRegex(ValueError, 'local-only'):
                    signing.export_values()
                self.assertEqual(output.getvalue(), '')
                with patch.object(signing, 'keytool') as keytool, self.assertRaises(ValueError):
                    signing.create()
                keytool.assert_not_called()

    def test_keytool_passwords_are_environment_references_and_init_output_is_public(self):
        def generate(command, **kwargs):
            self.assertNotIn(kwargs['env']['RAFT_ANDROID_STORE_PASSWORD'], command)
            self.assertNotIn(kwargs['env']['RAFT_ANDROID_KEY_PASSWORD'], command)
            self.assertIn('-storepass:env', command)
            self.assertIn('-keypass:env', command)
            (self.directory / 'release.jks').write_bytes(b'key bytes')

        output = io.StringIO()
        with patch.object(signing, 'keytool', return_value='keytool'), \
                patch.object(signing.subprocess, 'run', side_effect=generate), \
                patch.object(signing.subprocess, 'check_output', return_value=b'certificate bytes'), \
                redirect_stdout(output):
            signing.create()
        self.assertEqual(self.directory.stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.directory / 'release.jks').stat().st_mode & 0o777, 0o600)
        values = signing.export_values()
        for name in ['RAFT_ANDROID_STORE_PASSWORD', 'RAFT_ANDROID_KEY_PASSWORD', 'RAFT_ANDROID_KEYSTORE_BASE64']:
            self.assertNotIn(values[name], output.getvalue())


if __name__ == '__main__':
    unittest.main()
