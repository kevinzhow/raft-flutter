import importlib.machinery
import importlib.util
from pathlib import Path
import http.client
import unittest

path = Path(__file__).resolve().parents[1] / 'appimage-update-smoke.py'
loader = importlib.machinery.SourceFileLoader('appimage_update_smoke', str(path))
spec = importlib.util.spec_from_loader('appimage_update_smoke', loader)
smoke = importlib.util.module_from_spec(spec)
loader.exec_module(smoke)


class FakeGitHubTests(unittest.TestCase):
    """The harness's release server must behave like GitHub's download redirect."""

    def get(self, github, target, headers=None):
        host, port = github.origin.removeprefix('http://').split(':')
        connection = http.client.HTTPConnection(host, int(port))
        connection.request('GET', target, headers=headers or {})
        response = connection.getresponse()
        result = response.status, dict(response.getheaders()), response.read()
        connection.close()
        return result

    def test_asset_urls_redirect_to_an_object_that_honours_ranges(self):
        data = bytes(range(256)) * 40
        with smoke.FakeGitHub({'a+b.AppImage': data}) as github:
            for target in ('/kevinzhow/raft-flutter/releases/download/v0.1.0+7/a%2Bb.AppImage',
                           '/kevinzhow/raft-flutter/releases/latest/download/a+b.AppImage'):
                status, headers, _ = self.get(github, target)
                self.assertEqual(status, 302)
                location = headers['Location']
                self.assertTrue(location.startswith('/objects/'))
                status, headers, body = self.get(github, location, {'Range': 'bytes=10-19'})
                self.assertEqual((status, body), (206, data[10:20]))
                self.assertEqual(headers['Content-Range'], f'bytes 10-19/{len(data)}')
            status, _, body = self.get(github, location)
            self.assertEqual((status, body), (200, data))
            status, _, body = self.get(github, location, {'Range': f'bytes={len(data) - 5}-'})
            self.assertEqual((status, body), (206, data[-5:]))
            status, _, _ = self.get(github, location, {'Range': f'bytes={len(data)}-'})
            self.assertEqual(status, 416)
            self.assertEqual(github.bytes_for('a+b.AppImage', ranged=True), 25)
            self.assertEqual(github.bytes_for('a+b.AppImage', ranged=False), len(data))

    def test_unknown_assets_are_404_and_other_repositories_are_not_served(self):
        with smoke.FakeGitHub({'x': b'1'}) as github:
            self.assertEqual(self.get(github, '/kevinzhow/raft-flutter/releases/download/v1/missing')[0], 404)
            self.assertEqual(self.get(github, '/someone/else/releases/download/v1/x')[0], 404)
            self.assertEqual(self.get(github, '/objects/1/missing')[0], 404)


if __name__ == '__main__':
    unittest.main()
