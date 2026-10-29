import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('signpath_test', ROOT / 'tool/signpath_test.py')
signpath = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signpath)


def pe():
    data = bytearray(1024)
    data[:2] = b'MZ'
    struct.pack_into('<I', data, 0x3c, 128)
    data[128:132] = b'PE\0\0'
    struct.pack_into('<HH', data, 132, 0x8664, 1)
    struct.pack_into('<HH', data, 148, 240, 2)
    struct.pack_into('<H', data, 152, 0x20b)
    struct.pack_into('<I', data, 212, 512)
    struct.pack_into('<I', data, 260, 16)
    struct.pack_into('<II', data, 408, 512, 512)
    data[512:] = b'A' * 512
    return data


def signed(original):
    data = bytearray(original)
    # A structural fixture, deliberately not a cryptographic signature.
    certificate = struct.pack('<IHH', 12, 0x200, 2) + b'CMS!' + b'\0' * 4
    struct.pack_into('<I', data, 216, 123)
    struct.pack_into('<II', data, 296, len(data), len(certificate))
    return data + certificate


class SignPathTest(unittest.TestCase):
    def test_only_fresh_canonical_manual_source_can_pass(self):
        args = [signpath.REPOSITORY, 'workflow_dispatch', signpath.REF, 'a' * 40, '1']
        signpath.guard(*args)
        for index, value in [(0, 'fork/raft-flutter'), (1, 'pull_request_target'),
                             (2, 'refs/tags/v1.2.3'), (2, 'refs/heads/other'),
                             (3, '0' * 40), (4, '2')]:
            bad = list(args)
            bad[index] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                signpath.guard(*bad)

    def test_configuration_rejects_placeholders_and_production_policy(self):
        env = {
            'SIGNPATH_TEST_ORGANIZATION_ID': '00000000-0000-0000-0000-000000000001',
            'SIGNPATH_TEST_PROJECT_SLUG': 'approved-project',
            'SIGNPATH_TEST_POLICY_SLUG': 'test-signing',
            'SIGNPATH_TEST_ARTIFACT_SLUG': 'windows-runner-test',
            'SIGNPATH_TEST_CERTIFICATE_SHA1': 'a' * 40,
        }
        signpath.settings(env)
        for key, value in [('SIGNPATH_TEST_ORGANIZATION_ID', '0' * 32),
                           ('SIGNPATH_TEST_POLICY_SLUG', 'release-signing'),
                           ('SIGNPATH_TEST_ARTIFACT_SLUG', '*.exe'),
                           ('SIGNPATH_TEST_CERTIFICATE_SHA1', '0' * 40)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                signpath.settings({**env, key: value})

    def test_stage_omits_vendor_and_microsoft_runtimes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / 'raft_flutter.exe'
            source.write_bytes(pe())
            for name in ['vcruntime140.dll', 'msvcp140.dll', 'flutter_windows.dll', 'WinSparkle.dll']:
                (root / name).write_bytes(b'do not sign')
            signpath.stage(source, root / 'payload', root / 'unsigned.json')
            self.assertEqual([p.name for p in (root / 'payload').iterdir()], ['raft_flutter.exe'])
            self.assertEqual(source.read_bytes(), pe())
            self.assertEqual(json.loads((root / 'unsigned.json').read_text())['size'], 1024)
            with self.assertRaises(ValueError):
                signpath.stage(source, root / 'payload', root / 'unsigned.json')

    def test_wrong_type_unsigned_and_symbolic_inputs_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / 'raft_flutter.exe'
            for data in [b'MZ', b'not a PE', signed(pe())]:
                source.write_bytes(data)
                with self.subTest(data=data[:2]), self.assertRaises(ValueError):
                    signpath.stage(source, root / 'payload', root / 'unsigned.json')
            real = root / 'other.exe'
            real.write_bytes(pe())
            source.unlink()
            source.symlink_to(real)
            with self.assertRaises(ValueError):
                signpath.stage(source, root / 'payload', root / 'unsigned.json')

    def test_only_authenticode_header_changes_and_one_certificate_are_allowed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'before').write_bytes(pe())
            good = signed(pe())
            (root / 'after').write_bytes(good)
            signpath.inspect_return(root / 'before', root / 'after', root / 'proof')
            self.assertEqual((root / 'proof/signature.p7b').read_bytes(), b'CMS!')
            for mutation in ['payload', 'certificate-type', 'trailing-data']:
                bad = bytearray(good)
                if mutation == 'payload':
                    bad[600] ^= 1
                elif mutation == 'certificate-type':
                    bad[1030] = 1
                else:
                    bad += b'extra'
                (root / 'after').write_bytes(bad)
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    signpath.inspect_return(root / 'before', root / 'after', root / 'proof')

    def test_policy_selects_exact_owned_pe_and_workflow_has_no_release_trigger(self):
        ns = {'s': 'http://signpath.io/artifact-configuration/v1'}
        config = ET.parse(ROOT / 'tool/signpath/windows-runner-test.xml')
        selected = config.findall('.//s:pe-file', ns)
        self.assertEqual(len(selected), 1)
        self.assertEqual(selected[0].get('path'), 'raft_flutter.exe')
        self.assertEqual(selected[0].get('product-name'), 'Raft')
        self.assertEqual(selected[0].get('company-name'), 'app.raft')
        self.assertEqual(len(config.findall('.//s:authenticode-sign', ns)), 1)
        workflow = (ROOT / '.github/workflows/signpath-test.yml').read_text()
        self.assertNotIn('contents: write', workflow)
        self.assertNotIn('pull_request', workflow)
        self.assertNotIn('release.py publish', workflow)
        self.assertNotIn('SPARKLE_ED_PRIVATE_KEY', workflow)
        self.assertIn('steps.unsigned.outputs.artifact-id', workflow)
        self.assertIn('persist-credentials: false', workflow)


if __name__ == '__main__':
    unittest.main()
