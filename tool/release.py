#!/usr/bin/env python3
"""Hosted CI packaging. Independent of the private native acceptance receipts."""
import argparse
import base64
import hashlib
import importlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile
from urllib.parse import quote, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_notes  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'apps/raft_flutter'
OUT = ROOT / 'build/release'
PLATFORMS = {'windows', 'android', 'linux', 'macos', 'appimage'}
VERSION_PATTERN = r'[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?'


def tool_module(name):
    """Import a sibling tool module regardless of how release.py was loaded."""
    folder = str(Path(__file__).resolve().parent)
    if folder not in sys.path:
        sys.path.insert(0, folder)
    return importlib.import_module(name)


def run(args, **kwargs):
    subprocess.run([str(a) for a in args], check=True, **kwargs)


def capture(args):
    return subprocess.check_output(args, text=True).strip()


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def version_info(text):
    match = re.search(rf'^version:\s*({VERSION_PATTERN})\+(\d+)\s*$', text, re.M)
    if not match or int(match[2]) < 1:
        raise ValueError('App pubspec must have version: X.Y.Z[-prerelease]+positive-build-number')
    return match[1], match[2]


def release_identity(version, number, ref='', event='', run_number=''):
    """Tags select the app version; the workflow run counter supplies build numbers.

    The optional +N distinguishes releases of the same app version, as in Miraa.
    It is deliberately independent of the automatically increasing build number.
    """
    tag = ''
    asset_version = version
    if event == 'push' or ref.startswith('refs/tags/'):
        match = re.fullmatch(rf'refs/tags/v({VERSION_PATTERN})(?:\+([0-9]+))?', ref)
        if not match:
            raise ValueError('Release tag must be vX.Y.Z[-prerelease][+numeric-tag-build]')
        version = match[1]
        tag = ref.removeprefix('refs/tags/')
        asset_version = tag.removeprefix('v')
    if event == 'push' and not run_number:
        raise ValueError('Tag releases require GITHUB_RUN_NUMBER for the automatic build number')
    if run_number:
        if not re.fullmatch(r'[1-9][0-9]*', run_number):
            raise ValueError('GITHUB_RUN_NUMBER must be a positive integer')
        number = run_number
    return {'version': version, 'build_number': number, 'tag': tag, 'asset_version': asset_version}


def server_version(sync=None):
    """The Raft server version this client follows: the pinned Web release.

    Owner decision (Kevin, 2026-10-23): the app version equals the server
    version it is aligned to (`v1.21.23-source.1` -> `1.21.23`); client-only
    changes only add a build (`v1.21.23+2`).
    """
    sync = sync if sync is not None else json.loads((ROOT / 'docs/upstream-sync.json').read_text())
    match = re.fullmatch(r'v([0-9]+\.[0-9]+\.[0-9]+)-source\.[0-9]+', sync['pinned'])
    if not match:
        raise ValueError('docs/upstream-sync.json pinned must look like vX.Y.Z-source.N')
    return match[1]


def check_server_version(version, server):
    """A release's app version (prerelease suffix aside) must be the followed server version."""
    if version.split('-', 1)[0] != server:
        raise ValueError(f'App version {version} must equal the followed server version {server} '
                         '(docs/upstream-sync.json pinned); client-only changes add a build: '
                         f'v{server}+N')


def current_release():
    version, number = version_info((APP / 'pubspec.yaml').read_text(encoding='utf-8'))
    return release_identity(version, number, os.environ.get('GITHUB_REF', ''),
                            os.environ.get('GITHUB_EVENT_NAME', ''), os.environ.get('GITHUB_RUN_NUMBER', ''))


def release_plan(config, selection, event=''):
    if set(config) != PLATFORMS:
        raise ValueError('Platform config must contain windows, android, linux, macos and appimage')
    selected = ([part.strip() for part in selection.split(',')] if selection.strip()
                else [name for name, row in config.items() if row['enabled']])
    if not selected or len(selected) != len(set(selected)) or any(name not in PLATFORMS for name in selected):
        raise ValueError('Select unique known platforms: windows, android, linux, macos, appimage')
    # Pull requests never receive the persistent Android signing key.
    if event == 'pull_request':
        selected = [name for name in selected if name != 'android']
        if not selected:
            raise ValueError('Pull requests require at least one unsigned desktop platform')
    return {'include': [{'platform': name, 'runner': config[name]['runner'],
                         'arch': config[name]['arch']} for name in selected]}


def emit_outputs(values):
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as stream:
            for key, value in values.items():
                stream.write(f'{key}={value}\n')
    print(json.dumps(values, indent=2))


def plan():
    identity = current_release()
    # The first release job stops a tag whose version is not the followed server.
    if identity['tag']:
        check_server_version(identity['version'], server_version())
    matrix = release_plan(json.loads((ROOT / 'tool/release-platforms.json').read_text()),
                          os.environ.get('RELEASE_PLATFORMS', ''), os.environ.get('GITHUB_EVENT_NAME', ''))
    emit_outputs({'matrix': json.dumps(matrix, separators=(',', ':')), **identity})


def sdk():
    executable = shutil.which('flutter')
    if not executable:
        raise ValueError('Flutter action did not put Flutter on PATH')
    with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as stream:
        stream.write(f'RAFT_FLUTTER_BIN={executable}\n')


def copy_docs(destination):
    for name in ['THIRD_PARTY_NOTICES.md', 'docs/licenses', 'docs/linux-media-runtime.md']:
        source, target = ROOT / name, destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            shutil.copytree(source, target)
        else:
            shutil.copy2(source, target)


def windows_package(stage):
    source = APP / 'build/windows/x64/runner/Release'
    for name in ['raft_flutter.exe', 'flutter_windows.dll', 'data/icudtl.dat',
                 'data/app.so', 'data/flutter_assets', 'raft.ico', 'notification_icon.png',
                 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll']:
        if not (source / name).exists():
            raise ValueError(f'Incomplete Windows bundle: {name}')
    shutil.copytree(source, stage)
    tool_module('windows_dependencies').check(stage)
    copy_docs(stage)
    (stage / 'RUN.txt').write_text(
        'Extract the entire archive, then run raft_flutter.exe. Keep DLLs and data together.\n'
        'This portable build has no Authenticode signature or installer.\n'
        'Notifications use Windows system services; no additional notification runtime is required.\n'
        'Run the app once from its final folder to register notification clicks for the current user.\n',
        encoding='utf-8')


def linux_package(stage, suffix=''):
    shutil.copytree(APP / 'build/linux/x64/release/bundle', stage, symlinks=True)
    for path in stage.rglob('*'):
        if path.is_symlink() and not path.resolve().is_relative_to(stage.resolve()):
            raise ValueError('Linux bundle contains an external symlink')
    manifest_path = stage / 'data/notices/raft-media/manifest.json'
    manifest = json.loads(manifest_path.read_text())
    for record in manifest['libraries']:
        path = stage / 'lib' / record['library']
        notice = manifest_path.parent / (record['package'].replace(':', '_') + '.copyright')
        if not notice.is_file() or digest(path) != record['sha256']:
            raise ValueError('Linux media provenance or notice mismatch')
    elfs = []
    for path in stage.rglob('*'):
        if path.is_file():
            with path.open('rb') as stream:
                if stream.read(4) == b'\x7fELF':
                    elfs.append(path)
    jni = stage / 'lib/libdartjni.so'
    if any('libdartjni.so' in capture(['patchelf', '--print-needed', p]).splitlines() for p in elfs):
        raise ValueError('Unexpected Linux JNI dependency')
    if jni.exists():
        jni.unlink()
        elfs.remove(jni)
    for path in elfs:
        run(['patchelf', '--force-rpath', '--set-rpath', '$ORIGIN/lib' if path.name == 'raft_flutter' else '$ORIGIN', path])
    checks = {}
    env = {k: v for k, v in os.environ.items() if k not in {'LD_LIBRARY_PATH', 'LD_PRELOAD'}}
    for path in [stage / 'raft_flutter', stage / 'lib/libmpv.so.2', stage / 'lib/libmedia_kit_video_plugin.so']:
        listing = subprocess.check_output(['ldd', str(path)], text=True, env=env)
        if 'not found' in listing:
            raise ValueError('Incomplete relocated Linux dependency closure')
        for resolved in re.findall(r'=> (/\S+)', listing):
            target = Path(resolved).resolve()
            if target.is_relative_to(ROOT) and not target.is_relative_to(stage.resolve()):
                raise ValueError('Linux library resolves into the build tree')
        checks[str(path.relative_to(stage))] = listing
    for row in manifest['libraries']:
        row['preparedSha256'] = row['sha256']
        row['sha256'] = digest(stage / 'lib' / row['library'])
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    (stage / 'linux-dependency-checks.json').write_text(json.dumps(checks, indent=2) + '\n')
    desktop = stage / f'data/applications/app.raft.raft_flutter{suffix}.desktop'
    desktop.write_text(re.sub(r'^Exec=.*$', 'Exec=raft_flutter %u', desktop.read_text(), flags=re.M))
    copy_docs(stage)
    (stage / 'RUN.txt').write_text(
        'Run ./raft_flutter from this directory. Ubuntu 26.04 x86_64; requires compatible glibc, GTK and graphics drivers.\n'
        'PDF preview requires installed poppler-utils. Media notices/source versions are in data/notices/raft-media.\n'
        'For desktop registration put raft_flutter on PATH or adjust data/applications/app.raft.raft_flutter.desktop.\n'
        'Other distributions and full-app acceptance on this CI build have not been verified.\n')


def zip_folder(stage, destination):
    with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(stage.rglob('*')):
            if path.is_file():
                archive.write(path, path.relative_to(stage.parent))


def verify_android(apk, keystore, env, version, number):
    sdk_root = env.get('ANDROID_HOME') or env.get('ANDROID_SDK_ROOT')
    if not sdk_root:
        raise ValueError('Android SDK path is missing')
    tools = Path(sdk_root) / 'build-tools/37.0.0'
    badging = subprocess.check_output([str(tools / 'aapt'), 'dump', 'badging', str(apk)],
                                     text=True, env=env)
    identity = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging, re.M)
    # Pinned Flutter adds 2000 to the build number for split ARM64 APKs.
    if (not identity or identity[1] != 'app.raft.raft_flutter'
            or int(identity[2]) != int(number) + 2000 or identity[3] != version):
        raise ValueError('Android APK package or compiled version differs from the release plan')
    if re.search(r'^application-debuggable(?:\s|$)', badging, re.M):
        raise ValueError('Debuggable Android APK cannot be released')
    with zipfile.ZipFile(apk) as archive:
        abis = sorted({name.split('/')[1] for name in archive.namelist()
                       if name.startswith('lib/') and name.endswith('.so')})
    if abis != ['arm64-v8a']:
        raise ValueError('Android release must contain only ARM64 native libraries')
    cert = subprocess.check_output([
        'keytool', '-exportcert', '-keystore', str(keystore), '-alias', env['RAFT_ANDROID_KEY_ALIAS'],
        '-storepass:env', 'RAFT_ANDROID_STORE_PASSWORD',
    ], env=env, stderr=subprocess.PIPE)
    expected = hashlib.sha256(cert).hexdigest()
    signatures = subprocess.check_output([
        str(tools / 'apksigner'), 'verify', '--print-certs', str(apk),
    ], text=True, env=env)
    actual = sorted(set(value.lower() for value in re.findall(
        r'^(?:Signer #\d+|V[234](?:\.\d+)? Signer(?: #\d+)?):? certificate SHA-256 digest: ([0-9a-fA-F]{64})$', signatures, re.M)))
    if actual != [expected]:
        raise ValueError('Android APK signature differs from the configured release certificate')
    return {'package': identity[1], 'versionCode': int(identity[2]), 'versionName': identity[3],
            'abis': abis, 'certificateSHA256': expected}


def isolation_suffix(platform, environ):
    """The application-id suffix of an isolated Linux test build, or ''.

    RAFT_APPLICATION_ID_SUFFIX=.isolated gives the build another application
    id (apps/raft_flutter/linux/CMakeLists.txt, tool/appimage.py) so it shares
    no data, keyring entry or single-instance name with the real app. Release
    CI never sets it.
    """
    suffix = environ.get('RAFT_APPLICATION_ID_SUFFIX', '')
    if not suffix:
        return ''
    if platform not in {'linux', 'appimage'}:
        raise ValueError('RAFT_APPLICATION_ID_SUFFIX applies to the Linux builds only')
    if not re.fullmatch(r'(?:\.[a-z][a-z0-9_]*)+', suffix):
        raise ValueError('RAFT_APPLICATION_ID_SUFFIX must look like .isolated')
    return suffix


def isolated_version(version, suffix):
    """Mark the shown version, e.g. 0.1.0 -> 0.1.0-isolated."""
    if not suffix:
        return version
    label = suffix.strip('.').replace('.', '-').replace('_', '-')
    return f'{version}{"." if "-" in version else "-"}{label}'


# The official API and the Web app that serves it. Release builds bake both in
# (RAFT_ORIGIN, RAFT_FRONTEND_ORIGIN) so a missing define can never turn Web links
# (public page, invites, message links) into API-origin links. The pair must equal
# an entry of ContentLinks.officialWebOrigins (checked by tool/tests/test_release.py).
OFFICIAL_API_ORIGIN = 'https://api.raft.build'
OFFICIAL_WEB_ORIGIN = 'https://app.raft.build'
RELEASE_REQUIRED_DEFINES = ('RAFT_APP_VERSION', 'RAFT_BUILD_NUMBER', 'RAFT_ORIGIN',
                            'RAFT_FRONTEND_ORIGIN', 'RAFT_DEPLOYMENT_ENV', 'RAFT_COMMIT_SHA')


def commit_sha(environ):
    """The commit being built: GITHUB_SHA in CI, otherwise the checkout's HEAD."""
    value = environ.get('GITHUB_SHA', '').strip()
    if not value:
        value = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    return value


def release_defines(shown_version, number, environ, tag=''):
    """Every compile-time define a formal release build passes, validated.

    Required: version, build number, API origin, Web origin, deployment
    environment and commit. RAFT_FEEDBACK_EXPORT_URL is optional: it is the
    repository Actions variable of the feedback export worker and, when unset,
    the Report Issue entry is hidden (as on the Web without
    VITE_FEEDBACK_EXPORT_URL). RAFT_RELEASE_TAG (the release tag, when there is
    one) lets the app list the release notes between its own release and an
    offered update.
    """
    defines = {
        'RAFT_APP_VERSION': shown_version,
        # The update check compares this with the manifest's buildNumber.
        'RAFT_BUILD_NUMBER': number,
        'RAFT_ORIGIN': OFFICIAL_API_ORIGIN,
        'RAFT_FRONTEND_ORIGIN': OFFICIAL_WEB_ORIGIN,
        'RAFT_DEPLOYMENT_ENV': 'production',
        'RAFT_COMMIT_SHA': commit_sha(environ),
    }
    if tag:
        defines['RAFT_RELEASE_TAG'] = tag
    feedback = environ.get('RAFT_FEEDBACK_EXPORT_URL', '').strip()
    if feedback:
        defines['RAFT_FEEDBACK_EXPORT_URL'] = feedback
    return validate_release_defines(defines)


def validate_release_defines(defines):
    """Refuse a release whose defines would silently fall back to dev defaults."""
    missing = [key for key in RELEASE_REQUIRED_DEFINES if not str(defines.get(key, '')).strip()]
    if missing:
        raise ValueError(f'Release build is missing required defines: {", ".join(missing)}')
    if not re.fullmatch(r'[1-9][0-9]*', str(defines['RAFT_BUILD_NUMBER'])):
        raise ValueError('RAFT_BUILD_NUMBER must be a positive integer')
    if not re.fullmatch(r'[0-9a-f]{40}', str(defines['RAFT_COMMIT_SHA'])):
        raise ValueError('RAFT_COMMIT_SHA must be a 40-character lowercase hex commit id')
    if defines['RAFT_DEPLOYMENT_ENV'] != 'production':
        raise ValueError('RAFT_DEPLOYMENT_ENV must be production in a release build')
    for key, official in (('RAFT_ORIGIN', OFFICIAL_API_ORIGIN), ('RAFT_FRONTEND_ORIGIN', OFFICIAL_WEB_ORIGIN)):
        if defines[key] != official:
            raise ValueError(f'{key} must be {official} in a release build, got {defines[key]!r}')
    tag = defines.get('RAFT_RELEASE_TAG')
    if tag is not None and not re.fullmatch(r'v[0-9A-Za-z.+\-]+', str(tag)):
        raise ValueError('RAFT_RELEASE_TAG must be a release tag like v1.2.3+4')
    feedback = defines.get('RAFT_FEEDBACK_EXPORT_URL')
    if feedback is not None:
        parsed = urlsplit(feedback)
        if (parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password
                or parsed.query or parsed.fragment or re.search(r'\s', feedback)):
            raise ValueError('RAFT_FEEDBACK_EXPORT_URL must be a plain https URL')
    return defines


def build(platform):
    identity = current_release()
    version, number = identity['version'], identity['build_number']
    if os.environ.get('RELEASE_VERSION', version) != version or os.environ.get('RELEASE_BUILD_NUMBER', number) != number:
        raise ValueError('Build version differs from the planned version')
    suffix = isolation_suffix(platform, os.environ)
    shown_version = isolated_version(version, suffix)
    OUT.mkdir(parents=True, exist_ok=True)
    config = json.loads((ROOT / 'tool/release-platforms.json').read_text())[platform]
    arch = config['arch']
    name = f'raft-flutter-{isolated_version(identity["asset_version"], suffix)}-{platform}-{arch}'
    # No test entry points, inherited Dart defines or private local fixtures in hosted CI.
    # The only defines supplied here are release_defines() (version, build number,
    # official API/Web origins, deployment, commit, optional feedback worker) and
    # the updater/Linux-isolation ones below.
    env = dict(os.environ)
    env.pop('DART_DEFINES', None)
    android = None
    update_archive = None
    appcast = tool_module('appcast')
    # In-app updates exist only for macOS, Windows and the Linux AppImage and
    # only when the repo variable SPARKLE_ED_PUBLIC_KEY is set; otherwise the
    # build ships without an updater key and the app falls back to opening the
    # release page. One Ed25519 key pair serves all three.
    public_key = appcast.read_public_key(env) if platform in {'macos', 'windows', 'appimage'} else ''
    command = [sys.executable, ROOT / 'tool/flutter', 'build', 'apk' if platform == 'android' else 'linux' if platform == 'appimage' else platform,
               '--release', '--target=lib/main.dart', f'--build-name={shown_version}', f'--build-number={number}',
               *[f'--dart-define={key}={value}' for key, value in release_defines(shown_version, number, env, identity['tag']).items()]]
    if suffix:
        # Same value as the CMake environment variable: id, keyring, no raft:// handler.
        command.append(f'--dart-define=RAFT_LINUX_APPLICATION_ID_SUFFIX={suffix}')
    if public_key:
        command.append('--dart-define=RAFT_AUTO_UPDATE=true')
        if platform in {'windows', 'appimage'}:  # macOS reads SUPublicEDKey from Info.plist, set while packaging
            command.append(f'--dart-define=RAFT_SPARKLE_ED_PUBLIC_KEY={public_key}')
    extra_artifacts = []
    with tempfile.TemporaryDirectory(prefix='raft-release-') as temporary:
        work = Path(temporary)
        if platform == 'android':
            required = ['RAFT_ANDROID_KEYSTORE_BASE64', 'RAFT_ANDROID_STORE_PASSWORD',
                        'RAFT_ANDROID_KEY_PASSWORD', 'RAFT_ANDROID_KEY_ALIAS']
            if any(not env.get(key) for key in required):
                raise ValueError('Android CI requires all four RAFT_ANDROID signing secrets; debug signing is forbidden')
            keystore = work / 'release.jks'
            keystore.write_bytes(base64.b64decode(env.pop('RAFT_ANDROID_KEYSTORE_BASE64'), validate=True))
            keystore.chmod(0o600)
            env['RAFT_ANDROID_KEYSTORE_PATH'] = str(keystore)
            env['RAFT_ANDROID_SIGNING_REQUIRED'] = 'true'
            command += ['--split-per-abi', '--target-platform=android-arm64']
        run(command, cwd=APP, env=env)
        stage = work / name
        if platform == 'windows':
            windows_package(stage)
            artifact = OUT / f'{name}.zip'
            zip_folder(stage, artifact)
            signing = 'unsigned portable Windows bundle'
            # WinSparkle cannot unpack a ZIP; it downloads and runs this installer.
            setup = tool_module('windows_installer').build(stage, OUT, identity['asset_version'], version, number, arch)
            extra_artifacts.append(setup)
            update_archive = setup
        elif platform in {'linux', 'appimage'}:
            linux_package(stage, suffix)
            if platform == 'appimage':
                import appimage
                artifact = OUT / f'{name}.AppImage'
                appimage_checks = appimage.package(stage, artifact, ROOT, run, capture, digest)
                if appimage_checks['updateInformation']:
                    # The delta-update control file is published next to the AppImage
                    # (and checksummed with it); the app's in-place update needs both.
                    zsync = appimage.make_zsync(artifact)
                    extra_artifacts.append(zsync)
                    fields = appimage.zsync_control(zsync)
                    appimage_checks['zsync'] = {
                        'name': zsync.name, 'blockSize': int(fields['Blocksize']),
                        'hashLengths': fields['Hash-Lengths'], 'sha1': fields['SHA-1']}
                signing = 'unsigned AppImage; static runtime with bundled FUSE 3'
                # The in-place update checks the publisher's Ed25519 signature of
                # these exact bytes (added to the manifest at publish time).
                update_archive = artifact
            else:
                artifact = OUT / f'{name}.tar.gz'
                with tarfile.open(artifact, 'w:gz') as archive:
                    archive.add(stage, arcname=name)
                signing = 'not signed; Ubuntu 26.04 amd64 runtime'
        elif platform == 'macos':
            import macos_release
            apps = list((APP / 'build/macos/Build/Products/Release').glob('*.app'))
            if len(apps) != 1:
                raise ValueError('Expected one macOS app bundle')
            artifact = OUT / f'{name}.zip'
            entitlements = APP / 'macos/Runner/Release.entitlements'
            macos_checks = macos_release.package(apps[0], stage, entitlements, version, number, arch, public_key)
            copy_docs(stage)
            # ditto preserves app symlinks, executable permissions and metadata.
            run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', stage, artifact])
            macos_release.verify_archive(artifact, work / 'extracted', apps[0].name,
                                         entitlements, version, number, arch, public_key)
            update_archive = artifact
            signing = 'ad-hoc; no Developer ID or notarization'
        else:
            artifact = OUT / f'{name}.apk'
            shutil.copy2(APP / 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk', artifact)
            android = verify_android(artifact, keystore, env, version, number)
            signing = 'release keystore from GitHub secrets'
    receipt = {'platform': platform, 'arch': arch, 'version': version, 'buildNumber': number,
               'releaseTag': identity['tag'],
               'commit': capture(['git', 'rev-parse', 'HEAD']),
               'flutter': json.loads((ROOT / '.fvmrc').read_text())['flutter'],
               'signing': signing, 'nativeAcceptance': 'not performed by hosted build CI',
               'artifact': artifact.name, 'sha256': digest(artifact), 'bytes': artifact.stat().st_size}
    if android is not None:
        receipt['android'] = android
    if suffix:
        receipt['applicationId'] = 'app.raft.raft_flutter' + suffix
        receipt['shownVersion'] = shown_version
    if platform == 'appimage':
        receipt['appimage'] = appimage_checks
    if platform == 'macos':
        receipt['macos'] = macos_checks
    if extra_artifacts:
        receipt['extraArtifacts'] = [{'name': path.name, 'sha256': digest(path), 'bytes': path.stat().st_size}
                                     for path in extra_artifacts]
    if platform in {'macos', 'windows', 'appimage'}:
        # The publisher signs `archive` with the CI secret: macOS and Windows get
        # an appcast; the AppImage gets `edSignature` in its build manifest.
        if not public_key:
            receipt['autoUpdate'] = {'enabled': False}
        else:
            receipt['autoUpdate'] = {'enabled': True, 'publicKey': public_key, 'archive': update_archive.name}
            if platform != 'appimage':
                receipt['autoUpdate']['feed'] = f'appcast-{platform}.xml'
    (OUT / f'{name}.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    (OUT / f'{name}.sha256').write_text(f"{receipt['sha256']}  {artifact.name}\n", encoding='utf-8')
    print(json.dumps(receipt, indent=2))


def verify_artifacts(directory, matrix, version, commit, build_number=None, tag=None):
    expected = {row['platform'] for row in matrix['include']}
    if not expected or len(expected) != len(matrix['include']):
        raise ValueError('Invalid release platform inventory')
    receipts = [json.loads(p.read_text()) for p in directory.glob('*.json')]
    if len(receipts) != len(expected) or {r['platform'] for r in receipts} != expected:
        raise ValueError('Missing or duplicate platform receipts')
    files, checksums = [], []
    for row in receipts:
        name = row['artifact']
        if Path(name).name != name or '/' in name or '\\' in name:
            raise ValueError('Unsafe artifact filename')
        artifact = directory / name
        spec = next(r for r in matrix['include'] if r['platform'] == row['platform'])
        if (row['version'] != version or row['commit'] != commit or row['arch'] != spec['arch']
                or artifact.stat().st_size != row['bytes'] or digest(artifact) != row['sha256']
                or (build_number is not None and row.get('buildNumber') != build_number)
                or (tag is not None and row.get('releaseTag') != tag)):
            raise ValueError('Artifact version, build number, tag, source, architecture or checksum mismatch')
        files.append(artifact)
        checksums.append(f"{row['sha256']}  {name}\n")
        for extra in row.get('extraArtifacts', []):
            extra_name = extra['name']
            if Path(extra_name).name != extra_name or '/' in extra_name or '\\' in extra_name:
                raise ValueError('Unsafe artifact filename')
            path = directory / extra_name
            if path.stat().st_size != extra['bytes'] or digest(path) != extra['sha256']:
                raise ValueError('Artifact version, build number, tag, source, architecture or checksum mismatch')
            files.append(path)
            checksums.append(f"{extra['sha256']}  {extra_name}\n")
    return receipts, files, ''.join(sorted(checksums))


def tag_release():
    if os.environ.get('GITHUB_EVENT_NAME') != 'push':
        raise ValueError('Publishing is permitted only for a version-tag push')
    return current_release(), capture(['git', 'rev-parse', 'HEAD'])


def repository():
    name = os.environ.get('GITHUB_REPOSITORY', '')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', name):
        raise ValueError('Publishing requires a valid GITHUB_REPOSITORY')
    return name


def read_release(tag, *, missing_ok=False):
    command = ['gh', 'api', f'repos/{repository()}/releases/tags/{quote(tag, safe="")}']
    result = subprocess.run(command, text=True, capture_output=True)
    if result.returncode:
        try:
            error = json.loads(result.stdout)
        except ValueError:
            error = {}
        if str(error.get('status')) == '404':
            # The tag endpoint returns published releases only. An authenticated
            # list includes drafts; paginate so older drafts are not missed.
            lookup = ['gh', 'api', '--paginate', '--slurp',
                      f'repos/{repository()}/releases?per_page=100']
            listed = subprocess.run(lookup, text=True, capture_output=True)
            if listed.returncode:
                raise subprocess.CalledProcessError(listed.returncode, lookup,
                                                    output=listed.stdout, stderr=listed.stderr)
            matches = [remote for page in json.loads(listed.stdout) for remote in page
                       if remote.get('tag_name') == tag]
            if len(matches) > 1:
                raise ValueError('Multiple releases use this tag; refusing ambiguous publication')
            if matches:
                return matches[0]
            if missing_ok:
                return None
        raise subprocess.CalledProcessError(result.returncode, command,
                                            output=result.stdout, stderr=result.stderr)
    return json.loads(result.stdout)


def release_metadata(identity, commit, matrix):
    return {'tag': identity['tag'], 'version': identity['version'],
            'buildNumber': identity['build_number'], 'commit': commit,
            'platforms': [{'platform': row['platform'], 'arch': row['arch']}
                          for row in matrix['include']]}


def checked_release(remote, identity, commit, matrix=None):
    match = re.search(r'<!-- raft-release:(.*?) -->', remote.get('body') or '', re.S)
    if not match:
        raise ValueError('Existing release lacks this pipeline provenance; use a new tag')
    metadata = json.loads(match[1])
    if (remote.get('tag_name') != identity['tag'] or
            any(metadata.get(key) != value for key, value in {
                'tag': identity['tag'], 'version': identity['version'],
                'buildNumber': identity['build_number'], 'commit': commit,
            }.items()) or
            matrix is not None and metadata != release_metadata(identity, commit, matrix)):
        raise ValueError('Existing release tag, source, build number or platform plan differs')
    return metadata


def prepare():
    """Create one shared draft; the first successful platform publishes it."""
    identity, commit = tag_release()
    matrix = json.loads(os.environ['RELEASE_MATRIX'])
    config = json.loads((ROOT / 'tool/release-platforms.json').read_text())
    selected = ','.join(row['platform'] for row in matrix['include'])
    if matrix != release_plan(config, selected):
        raise ValueError('Release matrix differs from the checked-in platform configuration')
    remote = read_release(identity['tag'], missing_ok=True)
    if remote is not None:
        checked_release(remote, identity, commit, matrix)
        if remote.get('immutable'):
            raise ValueError('Independent platform uploads require a mutable release')
        print(f'Reusing prepared release {identity["tag"]}; existing assets remain unchanged')
        return
    OUT.mkdir(parents=True, exist_ok=True)
    version, number, tag = identity['version'], identity['build_number'], identity['tag']
    metadata = release_metadata(identity, commit, matrix)
    # The client's own release notes: written once here (the only creator of the
    # draft), so concurrent platform publishers never touch it. Fails before any
    # platform build starts when docs/release-notes/<tag>.md is missing. The same
    # notes head the GitHub release page.
    client_notes = OUT / 'release-notes.json'
    document = release_notes.write(client_notes, tag)
    notes = OUT / 'release-notes.md'
    notes.write_text(f'Raft Flutter {tag}\n\n' + release_notes.markdown(document, tag) + '\n'
                     f'App version: {version}. Build number: {number}.\n'
                     f'Source: `{commit}`. Flutter {json.loads((ROOT / ".fvmrc").read_text())["flutter"]}.\n\n'
                     'Each successful platform publishes independently. Assets arrive as its build '
                     'and platform checks finish; a missing platform may still be running or have failed.\n\n'
                     + '\n'.join(f'- {r["platform"]} {r["arch"]}' for r in metadata['platforms'])
                     + '\n\nEach platform has its own `CHECKSUMS-PLATFORM-ARCH.txt` and '
                     '`build-manifest-PLATFORM-ARCH.json` for source and SHA-256 provenance. '
                     'Hosted CI compiles and packages; platform functional acceptance is separate.\n'
                     '\nWindows requires Windows App Runtime 1.7 x64; extract the whole ZIP. '
                     'macOS ARM64 builds have ad-hoc signatures and are not notarized; '
                     'see READ-ME-FIRST.txt in the ZIP for first-launch instructions. '
                     'Linux tar.gz requires compatible Ubuntu 26.04 runtime dependencies; '
                     'AppImage has an Ubuntu 24.04 ABI baseline.\n\n'
                     '<!-- raft-release:' + json.dumps(metadata, sort_keys=True, separators=(',', ':')) + ' -->\n',
                     encoding='utf-8')
    command = ['gh', 'release', 'create', tag, client_notes, '--verify-tag', '--draft', '--target', commit,
               '--title', f'Raft Flutter {tag}', '--notes-file', notes, '--latest=false']
    if '-' in version:
        command.append('--prerelease')
    run(command)


def update_signing_seed(update):
    """The Ed25519 seed from the CI secret, checked against the key built into the app.

    The secret is only read from SPARKLE_ED_PRIVATE_KEY and never printed or logged.
    """
    appcast = tool_module('appcast')
    secret = os.environ.get('SPARKLE_ED_PRIVATE_KEY', '')
    if not secret.strip():
        raise ValueError('This build embeds an update public key but the SPARKLE_ED_PRIVATE_KEY secret '
                         'is empty; add the secret and rerun this publisher')
    seed = appcast.decode_seed(secret)
    if appcast.public_key_text(seed) != update['publicKey']:
        raise ValueError('SPARKLE_ED_PRIVATE_KEY does not match the public key built into the app')
    return seed


def appimage_signature(receipt, artifacts):
    """Base64 Ed25519 signature of the AppImage's bytes, or None without an updater key.

    Same scheme as Sparkle's `sparkle:edSignature` (signature over the whole file,
    the same key pair as macOS and Windows). Deterministic, so publisher retries
    on different hosts write identical manifests.
    """
    update = receipt.get('autoUpdate') or {'enabled': False}
    if not update.get('enabled'):
        return None
    appcast = tool_module('appcast')
    seed = update_signing_seed(update)
    archive = next((path for path in artifacts if path.name == update.get('archive')), None)
    if archive is None or archive.name != receipt['artifact']:
        raise ValueError('Auto-update archive is not the AppImage of this release')
    signature, length = appcast.sign_file(seed, archive)
    if length != receipt['bytes'] or not appcast.verify_file(appcast.public_key(seed), signature, archive):
        raise ValueError('The AppImage signature did not verify against its own public key')
    return base64.b64encode(signature).decode('ascii')


def write_appcast(receipt, identity, commit, platform, artifacts, directory):
    """Sign the update archive with the CI secret and render appcast-<platform>.xml.

    Returns [] when this build ships without an updater key. The private key is
    only read from SPARKLE_ED_PRIVATE_KEY and never printed or logged.
    """
    update = receipt.get('autoUpdate') or {'enabled': False}
    if not update.get('enabled') or platform == 'appimage':  # the AppImage has no appcast
        return []
    appcast = tool_module('appcast')
    seed = update_signing_seed(update)
    archive = next((path for path in artifacts if path.name == update['archive']), None)
    if archive is None or update.get('feed') != f'appcast-{platform}.xml':
        raise ValueError('Auto-update archive is not part of this platform release')
    published = capture(['git', 'show', '-s', '--format=%cI', commit])  # deterministic across retries
    xml = appcast.signed_appcast(
        seed=seed, archive=archive, platform=platform, repo=repository(), tag=identity['tag'],
        version=identity['version'], build_number=identity['build_number'], published=published)
    feed = directory / update['feed']
    feed.write_text(xml, encoding='utf-8', newline='\n')
    return [feed]


def asset_matches(tag, asset, path):
    if asset.get('state') != 'uploaded' or asset.get('size') != path.stat().st_size:
        return False
    expected = digest(path)
    if asset.get('digest'):
        return asset['digest'] == f'sha256:{expected}'
    # Older assets can lack a server digest. Compare their actual bytes.
    with tempfile.TemporaryDirectory(prefix='raft-release-compare-') as temporary:
        folder = Path(temporary)
        run(['gh', 'release', 'download', tag, '--pattern', path.name, '--dir', folder])
        downloaded = folder / path.name
        return downloaded.is_file() and digest(downloaded) == expected


def publish(platform):
    """Verify and append only this platform, without waiting for sibling jobs."""
    identity, commit = tag_release()
    remote = read_release(identity['tag'])
    metadata = checked_release(remote, identity, commit)
    config = json.loads((ROOT / 'tool/release-platforms.json').read_text())
    matrix = release_plan(config, platform)
    spec = {'platform': platform, 'arch': matrix['include'][0]['arch']}
    if spec not in metadata['platforms']:
        raise ValueError('This platform is not in the prepared release plan')
    receipts, artifacts, checksums = verify_artifacts(
        OUT, matrix, identity['version'], commit, identity['build_number'], identity['tag'])
    arch = spec['arch']
    if not re.fullmatch(r'[A-Za-z0-9_-]+', arch):
        raise ValueError('Unsafe platform architecture')
    extension = {'windows': 'zip', 'macos': 'zip', 'android': 'apk',
                 'linux': 'tar.gz', 'appimage': 'AppImage'}[platform]
    expected_name = f'raft-flutter-{identity["asset_version"]}-{platform}-{arch}.{extension}'
    # The primary artifact comes first; extras (e.g. the Windows installer) follow.
    extras = {extra['name'] for extra in receipts[0].get('extraArtifacts', [])}
    if (not artifacts or artifacts[0].name != expected_name
            or {path.name for path in artifacts[1:]} != extras):
        raise ValueError('Artifact name does not belong to this platform and release')
    if platform == 'appimage' and extras - {f'{expected_name}.zsync'}:
        raise ValueError('The AppImage release may only carry its own .zsync control file')
    with tempfile.TemporaryDirectory(prefix='raft-release-publish-') as temporary:
        auxiliary = Path(temporary)
        checksum = auxiliary / f'CHECKSUMS-{platform}-{arch}.txt'
        manifest = auxiliary / f'build-manifest-{platform}-{arch}.json'
        # Publishers on different hosts must produce identical auxiliary bytes.
        checksum.write_text(checksums, encoding='utf-8', newline='\n')
        # The AppImage's signature travels in its manifest, next to the SHA-256 the
        # in-place update already reads (an unsigned build publishes none).
        ed_signature = appimage_signature(receipts[0], artifacts) if platform == 'appimage' else None
        if ed_signature:
            receipts[0]['edSignature'] = ed_signature
        manifest.write_text(json.dumps(receipts, indent=2) + '\n', encoding='utf-8', newline='\n')
        feed = write_appcast(receipts[0], identity, commit, platform, artifacts, auxiliary)
        assets = {asset['name']: asset for asset in remote.get('assets', [])}
        missing = []
        for path in [*artifacts, checksum, manifest, *feed]:
            existing = assets.get(path.name)
            if existing is None:
                missing.append(path)
            elif not asset_matches(identity['tag'], existing, path):
                raise ValueError(f'Published asset differs; refusing to overwrite {path.name}')
        if missing:
            if remote.get('immutable'):
                raise ValueError('Independent platform uploads require a mutable release')
            # No shared manifest and no --clobber: sibling assets stay untouched.
            run(['gh', 'release', 'upload', identity['tag'], *missing])
        if remote.get('draft'):
            run(['gh', 'release', 'edit', identity['tag'], '--draft=false',
                 f'--prerelease={str("-" in identity["version"]).lower()}',
                 f'--latest={str("-" not in identity["version"]).lower()}'])
    print(f'Published {platform} independently to {identity["tag"]}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['plan', 'sdk', 'build', 'prepare', 'publish'])
    parser.add_argument('platform', nargs='?', choices=sorted(PLATFORMS))
    args = parser.parse_args()
    if args.action in {'build', 'publish'}:
        if not args.platform:
            parser.error(f'{args.action} requires a platform')
        {'build': build, 'publish': publish}[args.action](args.platform)
    else:
        {'plan': plan, 'sdk': sdk, 'prepare': prepare}[args.action]()


if __name__ == '__main__':
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f'Release stopped: {error}')
