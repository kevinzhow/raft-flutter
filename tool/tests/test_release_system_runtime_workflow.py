"""Exercise real Linux planning and retain independent signed release gates."""
import json
import os
from pathlib import Path
import re
import tempfile
import textwrap
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def job(text, name):
    start = text.index('\n  ' + name + ':\n')
    next_job = re.search(r'\n  [a-z][a-z-]*:\n', text[start + 1:])
    return text[start:start + 1 + next_job.start()] if next_job else text[start:]


class SystemReleaseWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.normal = (ROOT / '.github/workflows/release.yml').read_text()
        self.platform = (ROOT / '.github/workflows/release-platform.yml').read_text()
        self.backfill = (ROOT / '.github/workflows/release-backfill.yml').read_text()

    def test_real_planner_does_not_enable_unselected_linux_or_wait_for_browser_sdk(self):
        source = self.normal.split("          python - <<'PY'\n", 1)[1].split('\n          PY', 1)[0]
        source = textwrap.dedent(source)
        for selected in [[{'platform': 'windows', 'arch': 'x64', 'runner': 'windows-latest'}],
                         [{'platform': 'appimage', 'arch': 'x64', 'runner': 'ubuntu-26.04'}],
                         [{'platform': 'macos', 'arch': 'arm64', 'runner': 'macos-15'},
                          {'platform': 'appimage', 'arch': 'x64', 'runner': 'ubuntu-24.04'}]]:
            with self.subTest(selected=selected), tempfile.TemporaryDirectory() as folder:
                output = Path(folder) / 'output'
                with patch.dict(os.environ, {'RELEASE_MATRIX': json.dumps({'include': selected}),
                                             'GITHUB_OUTPUT': str(output)}):
                    exec(compile(source, 'actual-platform-plan', 'exec'), {})
                values = dict(line.split('=', 1) for line in output.read_text().splitlines())
                independent = json.loads(values['independent_matrix'])['include']
                linux = json.loads(values['linux_matrix'])['include']
                self.assertEqual([r['platform'] for r in independent + linux],
                                 [r['platform'] for r in selected])
                self.assertEqual(values['has_linux'], str(bool(linux)).lower())
                self.assertTrue(all(r['runner'] == 'ubuntu-24.04' for r in linux))
        for text in [self.normal, self.platform, self.backfill]:
            for forbidden in ['html-sdk', 'html_sdk_', 'tool.html_webview',
                              'prepare-media-appimage', 'RAFT_HTML_WEBVIEW_SDK',
                              'wpewebkit.org', 'html_webview/Dockerfile']:
                self.assertNotIn(forbidden, text)

    def test_each_platform_keeps_tag_only_signing_and_does_not_wait_for_other_platforms(self):
        for name in ['platform', 'linux-platform']:
            text = job(self.normal, name)
            self.assertIn('needs: [plan, prepare-release]', text)
            self.assertIn("needs.prepare-release.result == 'success'", text)
            self.assertIn("publish: ${{ github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v') }}", text)
            self.assertIn("SPARKLE_ED_PRIVATE_KEY: ${{ github.event_name == 'push' && secrets.SPARKLE_ED_PRIVATE_KEY || '' }}", text)
            self.assertIn('fail-fast: false', text)
        build = job(self.platform, 'build')
        self.assertIn('contents: read', build)
        self.assertNotIn('${{ secrets.SPARKLE_ED_PRIVATE_KEY }}', build)
        publish = job(self.platform, 'publish')
        self.assertIn('needs: [build, appimage-compatibility]', publish)
        self.assertIn("github.event_name == 'push'", publish)
        self.assertIn("needs.build.result == 'success'", publish)
        self.assertIn("needs.appimage-compatibility.result == 'success'", publish)
        self.assertIn('SPARKLE_ED_PRIVATE_KEY: ${{ secrets.SPARKLE_ED_PRIVATE_KEY }}', publish)
        self.assertIn('python tool/release.py publish ${{ inputs.platform }}', publish)

    def test_distribution_install_and_four_real_native_gates_remain_mandatory(self):
        for text in [self.platform, self.backfill]:
            self.assertIn('sudo apt-get update', text)
            self.assertIn('libwebkit2gtk-4.1-dev', text)
            self.assertIn('libmpv2 libmpv-dev', text)
            self.assertNotIn('--allow-unauthenticated', text)
            self.assertIn('glib-networking', text)
            self.assertIn('gstreamer1.0-plugins-good', text)
            self.assertIn('--mode direct', text)
            self.assertIn('--mode extract', text)
            self.assertIn('fedora:44 bash /source/tool/appimage-fedora-test.sh', text)
        fedora = (ROOT / 'tool/appimage-fedora-test.sh').read_text()
        self.assertIn('dnf --repo=fedora --setopt=allow_downgrade=True install', fedora)
        for required in ['gtk3 webkit2gtk4.1 libsoup3 libsecret mpv-libs poppler-utils',
                         'glib-networking librsvg2', 'gstreamer1-plugins-base gstreamer1-plugins-good',
                         "--mode extract", 'appimage-wayland-smoke.py', '6.6.4', '6.10.2']:
            self.assertIn(required, fedora)
        self.assertNotIn('--nogpgcheck', fedora)
        smoke = (ROOT / 'tool/appimage-smoke.py').read_text()
        self.assertIn("linux_system_runtime.inventory(payload)", smoke)
        self.assertIn("shutil.which(name) for name in ('pdfinfo', 'pdftoppm')", smoke)
        self.assertIn("if colors < 2:", smoke)
        self.assertIn("--appimage-extract-and-run", smoke)
        self.assertIn("width < 1000 or height < 600 or colors < 32", smoke)

    def test_retired_tag_is_refused_before_flutter_or_apt_setup(self):
        build = job(self.backfill, 'build')
        guard = build.index('Reject legacy private-engine AppImage backfills before setup')
        self.assertLess(guard, build.index('subosito/flutter-action@v2'))
        self.assertLess(guard, build.index('sudo apt-get update'))
        self.assertIn('backfill.checked_source(source, tag, commit)', build)
        self.assertIn("backfill.validate_release(backfill.existing_release(tag), tag, commit, number, 'appimage')", build)
        self.assertIn('backfill.require_system_source(source)', build)

    def test_top_level_cmake_never_copies_a_system_abi_or_applies_old_wpe_adapter(self):
        source = (ROOT / 'apps/raft_flutter/linux/CMakeLists.txt').read_text()
        self.assertIn('pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)', source)
        for forbidden in ['RAFT_MEDIA_BUNDLE', 'RAFT_HTML_WEBVIEW_SDK', 'raft_wpe_compat',
                          'PKG_CONFIG_PATH', '-rpath-link', 'media-linux/bundle']:
            self.assertNotIn(forbidden, source)
        self.assertFalse((ROOT / 'tool/html_webview/sdk.py').exists())
        self.assertIn('if(TARGET raft_system_webview_extension)', source)
        self.assertIn('LIBRARY DESTINATION "${INSTALL_BUNDLE_LIB_DIR}/raft-webview"', source)
        self.assertLess(source.index('file(REMOVE_RECURSE'),
                        source.index('install(TARGETS raft_system_webview_extension'))


if __name__ == '__main__':
    unittest.main()
