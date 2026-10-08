"""Exercise real publisher code in isolated synthetic filesystem fixtures."""
import ast
import contextlib
import hashlib
import io
import json
import pathlib
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zlib

REPO = pathlib.Path(__file__).resolve().parents[2]
SNAPSHOT = 'a' * 64


def png():
    def chunk(kind, body):
        return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(b'\x00\x00\x00\x00')) + chunk(b'IEND', b''))


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='raft-publisher-test-')
        self.root = pathlib.Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)
        self.evidence = self.root / '.local/native-e2e'
        self.evidence.mkdir(parents=True)
        for platform in ['linux', 'android']:
            metadata = {'platform': platform, 'runId': '2026-10-08T01:00:00.000Z', 'sourceHash': SNAPSHOT, 'completed': True}
            (self.evidence / f'native-{platform}-run.json').write_text(json.dumps(metadata))
            (self.evidence / f'native-{platform}-checkpoints.tsv').write_text(f'{platform}-proof\t2026-10-08T01:00:01Z\t{metadata["runId"]}\n')
            (self.evidence / f'{platform}-proof.png').write_bytes(png())
            filename = 'native-linux-fleet.txt' if platform == 'linux' else 'native-android-test.txt'
            (self.root / '.local' / filename).write_text(f'Native evidence run: {platform} {metadata["runId"]}\nAll tests passed!\n')
        (self.evidence / 'android-os-notification-shade.png').write_bytes(png())
        (self.evidence / 'android-os-notification-click.json').write_text(json.dumps({
            'clicked': True, 'runId': metadata['runId'], 'sourceHash': SNAPSHOT,
        }))
        (self.root / '.local/all-project-tests.txt').write_text('All tests passed!\n')
        (self.root / '.local/analyze-all.txt').write_text('No issues found!\n')
        (self.root / '.local/host-collector-tests.txt').write_text('Ran 12 tests\n\nOK\n')
        (self.root / '.local/engineering-run.json').write_text(json.dumps({
            'completed': True, 'sourceHash': SNAPSHOT,
            'checks': {name: True for name in ['all-project-tests.txt', 'analyze-all.txt', 'host-collector-tests.txt']},
        }))
        (self.root / 'docs').mkdir()
        (self.root / 'docs/feature-parity.csv').write_text('module,linux,android,status\nPreview,PASS,PASS,verified\n')

    def publish(self):
        tree = ast.parse((REPO / 'tool/publish-report').read_text())
        for node in tree.body:
            if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'root' for t in node.targets):
                node.value = ast.Call(func=ast.Attribute(value=ast.Name(id='pathlib', ctx=ast.Load()), attr='Path', ctx=ast.Load()), args=[ast.Constant(str(self.root))], keywords=[])
        output = io.StringIO()
        with patch.object(sys, 'argv', ['publish-report']), patch.object(subprocess, 'check_output', return_value=SNAPSHOT + '\n'), contextlib.redirect_stdout(output):
            exec(compile(ast.fix_missing_locations(tree), str(REPO / 'tool/publish-report'), 'exec'), {'__file__': str(REPO / 'tool/publish-report')})
        return json.loads(output.getvalue())

    def build_gate(self):
        tree = ast.parse((REPO / 'tool/build-deliverables').read_text())
        prefix = []
        for node in tree.body:
            if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'release_env' for t in node.targets):
                break  # Never execute any Flutter build or release staging.
            if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'root' for t in node.targets):
                node.value = ast.Call(func=ast.Attribute(value=ast.Name(id='pathlib', ctx=ast.Load()), attr='Path', ctx=ast.Load()), args=[ast.Constant(str(self.root))], keywords=[])
            prefix.append(node)
        scope = {'__file__': str(REPO / 'tool/build-deliverables')}
        with patch.object(subprocess, 'check_output', return_value=SNAPSHOT + '\n'):
            exec(compile(ast.fix_missing_locations(ast.Module(body=prefix, type_ignores=[])), 'build-deliverables-gates', 'exec'), scope)
        return scope['evidence_receipts']

    def test_build_gate_preserves_current_png_checksums(self):
        receipt = self.build_gate()
        self.assertEqual(receipt['android']['images']['android-proof.png'], hashlib.sha256(png()).hexdigest())
        self.assertEqual(receipt['android']['osNotification']['runId'], receipt['android']['runId'])

    def test_build_gate_rejects_corrupt_png(self):
        data = bytearray(png())
        data[30] ^= 1
        (self.evidence / 'linux-proof.png').write_bytes(data)
        with self.assertRaisesRegex(SystemExit, 'image is incomplete'):
            self.build_gate()

    def test_build_gate_rejects_failed_collector(self):
        path = self.root / '.local/engineering-run.json'
        row = json.loads(path.read_text())
        row['checks']['host-collector-tests.txt'] = False
        path.write_text(json.dumps(row))
        with self.assertRaisesRegex(SystemExit, 'engineering run'):
            self.build_gate()

    def test_build_gate_rejects_missing_os_click(self):
        (self.evidence / 'android-os-notification-click.json').unlink()
        with self.assertRaisesRegex(SystemExit, 'notification evidence is missing'):
            self.build_gate()

    def test_current_complete_evidence_passes_and_preserves_tsv(self):
        result = self.publish()
        self.assertTrue(result['allPassed'])
        report = pathlib.Path(result['report'])
        self.assertEqual((report / 'native-android-checkpoints.tsv').read_bytes(), (self.evidence / 'native-android-checkpoints.tsv').read_bytes())
        self.assertTrue((report / 'host-collector-tests.txt').is_file())

    def test_missing_current_png_cannot_pass(self):
        (self.evidence / 'android-proof.png').unlink()
        self.assertFalse(self.publish()['allPassed'])

    def test_bad_png_crc_cannot_pass(self):
        data = bytearray(png())
        data[30] ^= 1
        (self.evidence / 'linux-proof.png').write_bytes(data)
        self.assertFalse(self.publish()['allPassed'])

    def test_truncated_png_cannot_pass(self):
        (self.evidence / 'android-proof.png').write_bytes(png()[:-1])
        self.assertFalse(self.publish()['allPassed'])

    def test_wrong_platform_checkpoint_cannot_pass(self):
        path = self.evidence / 'native-android-checkpoints.tsv'
        path.write_text(path.read_text().replace('android-proof', 'linux-proof'))
        self.assertFalse(self.publish()['allPassed'])

    def test_stale_tsv_run_cannot_pass(self):
        path = self.evidence / 'native-android-checkpoints.tsv'
        path.write_text(path.read_text().replace('01:00:00.000Z', '00:00:00.000Z'))
        self.assertFalse(self.publish()['allPassed'])

    def test_missing_os_click_evidence_cannot_pass(self):
        (self.evidence / 'android-os-notification-click.json').unlink()
        self.assertFalse(self.publish()['allPassed'])

    def test_stale_os_click_run_cannot_pass(self):
        path = self.evidence / 'android-os-notification-click.json'
        row = json.loads(path.read_text())
        row['runId'] = 'old'
        path.write_text(json.dumps(row))
        self.assertFalse(self.publish()['allPassed'])

    def test_host_collector_failure_cannot_pass(self):
        path = self.root / '.local/engineering-run.json'
        row = json.loads(path.read_text())
        row['checks']['host-collector-tests.txt'] = False
        path.write_text(json.dumps(row))
        self.assertFalse(self.publish()['allPassed'])

    def artifacts(self):
        folder = self.root / 'build/deliverables'
        folder.mkdir(parents=True)
        rows = {}
        for name in ['raft-flutter-android.apk', 'raft-flutter-linux-x64.tar.gz']:
            data = name.encode()
            (folder / name).write_bytes(data)
            rows[name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        (folder / 'build-manifest.json').write_text(json.dumps({'sourceHash': SNAPSHOT, 'artifacts': rows}))
        (folder / 'CHECKSUMS.txt').write_text(''.join(f'{row["sha256"]}  {name}\n' for name, row in rows.items()))
        return folder

    def test_artifacts_require_exact_current_bytes(self):
        folder = self.artifacts()
        (folder / 'raft-flutter-android.apk').write_bytes(b'corrupt')
        with self.assertRaisesRegex(SystemExit, 'bytes do not match'):
            self.publish()

    def test_current_artifacts_publish_with_checksums(self):
        self.artifacts()
        self.assertEqual(len(self.publish()['artifacts']), 4)

    def test_wrong_checksum_inventory_is_blocked(self):
        folder = self.artifacts()
        (folder / 'CHECKSUMS.txt').write_text('stale')
        with self.assertRaisesRegex(SystemExit, 'checksum inventory'):
            self.publish()

    def test_signed_url_log_is_not_exported(self):
        (self.root / '.local/native-linux-fleet.txt').write_text('https://example.invalid/object?X-Amz-Signature=0123456789abcdef')
        with self.assertRaisesRegex(SystemExit, 'credential redaction'):
            self.publish()


if __name__ == '__main__':
    unittest.main(verbosity=2)
