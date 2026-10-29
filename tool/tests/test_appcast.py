"""Appcast generation and signing, using throwaway keys created inside each test."""
import base64
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
import unittest.mock
from xml.etree import ElementTree

SPEC = importlib.util.spec_from_file_location('appcast', Path(__file__).resolve().parents[1] / 'appcast.py')
appcast = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(appcast)

SPARKLE = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
RFC8032_SEED = bytes.fromhex('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60')
RFC8032_PUBLIC = 'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'
RFC8032_EMPTY_SIGNATURE = (
    'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46b'
    'd25bf5f0595bbe24655141438e7a100b')


class Ed25519Tests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def file(self, data, name='archive.bin'):
        path = self.root / name
        path.write_bytes(data)
        return path

    def test_matches_rfc_8032_vector(self):
        self.assertEqual(appcast.public_key(RFC8032_SEED).hex(), RFC8032_PUBLIC)
        signature, length = appcast.sign_file(RFC8032_SEED, self.file(b''))
        self.assertEqual((signature.hex(), length), (RFC8032_EMPTY_SIGNATURE, 0))

    def test_agrees_with_openssl_backed_library_when_installed(self):
        try:
            from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
        except ImportError:
            self.skipTest('cryptography is not installed')
        seed = os.urandom(32)
        data = os.urandom(3 * (1 << 20) + 17)  # crosses the 1 MiB streaming chunk
        reference = Ed25519PrivateKey.from_private_bytes(seed)
        signature, length = appcast.sign_file(seed, self.file(data))
        self.assertEqual(signature, reference.sign(data))
        self.assertEqual(length, len(data))
        reference.public_key().verify(signature, data)

    def test_verify_rejects_changed_bytes_and_wrong_key(self):
        seed = os.urandom(32)
        path = self.file(b'update archive')
        signature, _ = appcast.sign_file(seed, path)
        pub = appcast.public_key(seed)
        self.assertTrue(appcast.verify_file(pub, signature, path))
        self.assertFalse(appcast.verify_file(pub, signature, self.file(b'tampered archive', 'other.bin')))
        self.assertFalse(appcast.verify_file(appcast.public_key(os.urandom(32)), signature, path))
        self.assertFalse(appcast.verify_file(pub, signature[:-1], path))

    def test_sparkle_key_text_validation(self):
        seed = os.urandom(32)
        self.assertEqual(appcast.decode_seed(base64.b64encode(seed).decode() + '\n'), seed)
        with self.assertRaisesRegex(ValueError, 'Legacy 96-byte'):
            appcast.decode_seed(base64.b64encode(os.urandom(96)).decode())
        with self.assertRaisesRegex(ValueError, '32-byte'):
            appcast.decode_seed(base64.b64encode(os.urandom(31)).decode())
        with self.assertRaisesRegex(ValueError, 'base64'):
            appcast.decode_seed('not base64!!')
        with self.assertRaisesRegex(ValueError, 'public key'):
            appcast.decode_public_key(base64.b64encode(os.urandom(31)).decode())
        # The error text must never echo the key material.
        try:
            appcast.decode_seed('secret-looking-value!')
        except ValueError as error:
            self.assertNotIn('secret-looking-value', str(error))

    def test_public_key_comes_only_from_the_actions_variable(self):
        pub = appcast.public_key_text(os.urandom(32))
        self.assertEqual(appcast.read_public_key({'SPARKLE_ED_PUBLIC_KEY': f' {pub}\n'}), pub)
        self.assertEqual(appcast.read_public_key({}), '')
        self.assertEqual(appcast.read_public_key({'SPARKLE_ED_PUBLIC_KEY': '  '}), '')
        with self.assertRaises(ValueError):
            appcast.read_public_key({'SPARKLE_ED_PUBLIC_KEY': 'AAAA'})


class AppcastTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.seed = os.urandom(32)
        self.fields = dict(repo='kevinzhow/raft-flutter', tag='v0.1.1+2', version='0.1.1',
                           build_number='47', published='2026-10-13T08:00:00+00:00')

    def render(self, platform, name):
        archive = self.root / name
        archive.write_bytes(b'archive bytes ' * 100)
        return archive, appcast.signed_appcast(seed=self.seed, archive=archive, platform=platform, **self.fields)

    def item(self, xml):
        root = ElementTree.fromstring(xml)
        return root.find('channel/item')

    def test_macos_item_uses_build_number_and_signed_release_asset(self):
        archive, xml = self.render('macos', 'raft-flutter-0.1.1+2-macos-arm64.zip')
        item = self.item(xml)
        self.assertEqual(item.find(f'{SPARKLE}version').text, '47')
        self.assertEqual(item.find(f'{SPARKLE}shortVersionString').text, '0.1.1')
        self.assertEqual(item.find(f'{SPARKLE}minimumSystemVersion').text, '12.0')
        enclosure = item.find('enclosure')
        self.assertEqual(enclosure.get('url'), 'https://github.com/kevinzhow/raft-flutter/releases/download/'
                         'v0.1.1%2B2/raft-flutter-0.1.1%2B2-macos-arm64.zip')
        self.assertEqual(enclosure.get('length'), str(archive.stat().st_size))
        signature = base64.b64decode(enclosure.get(f'{SPARKLE}edSignature'))
        self.assertTrue(appcast.verify_file(appcast.public_key(self.seed), signature, archive))
        self.assertIsNone(enclosure.get(f'{SPARKLE}os'))
        self.assertEqual(item.find('pubDate').text, 'Tue, 13 Oct 2026 08:00:00 +0000')

    def test_windows_item_targets_the_installer_with_silent_arguments(self):
        archive, xml = self.render('windows', 'raft-flutter-0.1.1+2-windows-x64-setup.exe')
        enclosure = self.item(xml).find('enclosure')
        self.assertEqual(enclosure.get(f'{SPARKLE}os'), 'windows-x64')
        self.assertIn('/SILENT', enclosure.get(f'{SPARKLE}installerArguments'))
        self.assertTrue(enclosure.get('url').endswith('windows-x64-setup.exe'))
        self.assertIsNone(self.item(xml).find(f'{SPARKLE}minimumSystemVersion'))

    def test_output_is_deterministic_for_idempotent_publish_retries(self):
        _, first = self.render('macos', 'a.zip')
        archive = self.root / 'a.zip'
        second = appcast.signed_appcast(seed=self.seed, archive=archive, platform='macos', **self.fields)
        self.assertEqual(first, second)

    def test_feed_url_matches_what_the_app_uses(self):
        self.assertEqual(appcast.feed_url('kevinzhow/raft-flutter', 'macos'),
                         'https://github.com/kevinzhow/raft-flutter/releases/latest/download/appcast-macos.xml')

    def test_rejects_unsupported_platform_bad_build_number_and_bad_signature(self):
        archive, _ = self.render('macos', 'a.zip')
        signature = base64.b64encode(bytes(64)).decode()
        base = dict(repo='o/r', tag='v1.0.0', version='1.0.0', archive_name='a.zip', length=1,
                    signature=signature, published='2026-10-13T00:00:00Z')
        with self.assertRaises(ValueError):
            appcast.build_appcast(platform='linux', build_number='1', **base)
        with self.assertRaises(ValueError):
            appcast.build_appcast(platform='macos', build_number='0', **base)
        with self.assertRaises(ValueError):
            appcast.build_appcast(platform='macos', build_number='1', **{**base, 'signature': 'AAAA'})
        with self.assertRaises(ValueError):
            appcast.build_appcast(platform='macos', build_number='1', **{**base, 'published': '2026-10-13T00:00:00'})


class CommandLineTests(unittest.TestCase):
    def test_keygen_then_sign_produces_a_verifiable_appcast_without_printing_the_key(self):
        import contextlib
        import io
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                appcast.main(['keygen', '--out', str(root / 'keys')])
            private = root / 'keys/private-key.txt'
            self.assertEqual(private.stat().st_mode & 0o777, 0o600)
            secret = private.read_text().strip()
            self.assertNotIn(secret, output.getvalue())
            public = output.getvalue().split('public key: ')[1].strip()
            archive = root / 'a.zip'
            archive.write_bytes(b'zip')
            with unittest.mock.patch.dict(os.environ, {'SPARKLE_ED_PRIVATE_KEY': secret}), \
                    contextlib.redirect_stdout(io.StringIO()):
                appcast.main(['sign', '--archive', str(archive), '--platform', 'macos', '--tag', 'v1.0.0',
                              '--version', '1.0.0', '--build', '3', '--published', '2026-01-01T00:00:00Z',
                              '--url', 'http://localhost:8000/a.zip', '--output', str(root / 'appcast.xml')])
            enclosure = ElementTree.parse(root / 'appcast.xml').find('channel/item/enclosure')
            self.assertEqual(enclosure.get('url'), 'http://localhost:8000/a.zip')
            signature = base64.b64decode(enclosure.get(f'{SPARKLE}edSignature'))
            self.assertTrue(appcast.verify_file(appcast.decode_public_key(public), signature, archive))


if __name__ == '__main__':
    unittest.main()
