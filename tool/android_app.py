"""Android deployment safety. Never uninstall, clear data or retry an install."""
import hashlib
from contextlib import contextmanager
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
PACKAGE = 'app.raft.raft_flutter'
LAB_PACKAGE = PACKAGE + '.linkperf'


class SafetyError(RuntimeError):
    pass


def local_dev_version(root=ROOT):
    """Identify the actual local source tree, including pre-existing dirty files."""
    match = re.search(r'^version:\s*([^+\s]+)\+\d+\s*$',
                      (root / 'apps/raft_flutter/pubspec.yaml').read_text(), re.M)
    if not match:
        raise SafetyError('App pubspec must contain a version and build number.')
    commit = subprocess.check_output(['git', 'rev-parse', '--short=7', 'HEAD'],
                                     cwd=root, text=True).strip()
    dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True).strip())
    return f'{match[1]}-dev.{commit}' + ('.dirty' if dirty else '')


def build_local_android(build_number, root=ROOT, run_build=None):
    """Compile only; update/launch still require the separate guarded installer.

    Use a sufficient build number: ARM64 split APKs add an ABI offset, and the
    installer checks the actual APK version code before an update.
    """
    if not isinstance(build_number, int) or isinstance(build_number, bool) or build_number < 1:
        raise SafetyError('Local Android builds require a positive build number.')
    version = local_dev_version(root)
    command = [sys.executable, str(root / 'tool/flutter'), 'build', 'apk',
               '--release', '--target=lib/main.dart', '--split-per-abi',
               '--target-platform=android-arm64', f'--build-number={build_number}',
               f'--build-name={version}', f'--dart-define=RAFT_APP_VERSION={version}']
    (run_build or subprocess.run)(command, cwd=root / 'apps/raft_flutter', check=True)
    return {'versionName': version, 'buildNumber': build_number,
            'apk': str(root / 'apps/raft_flutter/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk')}


@contextmanager
def update_lock(serial, directory=ROOT / '.local/android-installs'):
    try:
        import fcntl
    except ImportError as error:
        raise SafetyError('Android installer locking requires a macOS/Linux host.') from error
    directory.mkdir(parents=True, exist_ok=True)
    name = hashlib.sha256(serial.encode()).hexdigest()[:24]
    with (directory / f'device-{name}.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise SafetyError('Another update/preflight is running for this device. Stop; no automatic retry.') from error
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def call(argv):
    try:
        result = subprocess.run([str(a) for a in argv], capture_output=True, text=True, timeout=180)
    except subprocess.TimeoutExpired as error:
        raise SafetyError(f'{Path(str(argv[0])).name} timed out; no retry.') from error
    if result.returncode:
        raise SafetyError(f'{Path(str(argv[0])).name} failed: {result.stdout.strip()} {result.stderr.strip()}')
    return result.stdout


def sdk_tools():
    local = ROOT / 'apps/raft_flutter/android/local.properties'
    match = re.search(r'^sdk.dir=(.+)$', local.read_text(), re.M) if local.exists() else None
    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or (match[1] if match else ''))
    versions = sorted((sdk / 'build-tools').glob('*'),
                      key=lambda p: tuple(int(n) for n in re.findall(r'\d+', p.name)), reverse=True)
    tools = next((p for p in versions if (p / 'aapt').is_file() and (p / 'apksigner').is_file()), None)
    adb = sdk / 'platform-tools/adb'
    if tools is None or not adb.is_file():
        raise SafetyError('Android SDK tools not found; set ANDROID_HOME or android/local.properties.')
    return adb, tools / 'aapt', tools / 'apksigner'


def manifest_launch_activity(text, package):
    """Read compiled aapt xmltree, including launcher aliases omitted by badging."""
    root = ET.Element('dump')
    stack = []
    for line in text.splitlines():
        element = re.match(r'^(\s*)E: ([\w-]+)(?:\s|$)', line)
        if element:
            indent = len(element[1])
            while stack and stack[-1][0] >= indent:
                stack.pop()
            node = ET.SubElement(stack[-1][1] if stack else root, element[2])
            stack.append((indent, node))
        elif stack:
            attribute = re.match(r'^\s*A: ([\w:]+)(?:\([^)]*\))?=(.*)$', line)
            if not attribute:
                continue
            value = attribute[2]
            quoted = re.match(r'^"([^"]*)"', value)
            boolean = re.fullmatch(r'\(type 0x12\)0x([\da-fA-F]+)', value)
            stack[-1][1].set(attribute[1], quoted[1] if quoted else
                            str(int(boolean[1], 16) != 0).lower() if boolean else value)
    manifests = root.findall('manifest')
    if len(manifests) != 1 or manifests[0].get('package') != package:
        raise SafetyError('Compiled Manifest package is missing or inconsistent.')
    applications = manifests[0].findall('application')
    if len(applications) != 1 or applications[0].get('android:enabled', 'true') != 'true':
        raise SafetyError('Compiled Manifest has no enabled application.')
    app = applications[0]

    def name(value):
        if not value:
            return None
        return package + value if value.startswith('.') else package + '.' + value if '.' not in value else value

    def accepts(node, category):
        return any(any(child.get('android:name') == 'android.intent.action.MAIN'
                       for child in intent.findall('action')) and
                   any(child.get('android:name') == category for child in intent.findall('category'))
                   for intent in node.findall('intent-filter'))

    activities = {name(node.get('android:name')): node for node in app.findall('activity')}
    launchers, info = [], []
    for node in app:
        if node.tag not in ('activity', 'activity-alias'):
            continue
        component = name(node.get('android:name'))
        if not component or node.get('android:enabled', 'true') != 'true' or node.get('android:exported') != 'true':
            continue
        if node.tag == 'activity-alias':
            target = activities.get(name(node.get('android:targetActivity')))
            if target is None or target.get('android:enabled', 'true') != 'true':
                continue
        if accepts(node, 'android.intent.category.LAUNCHER'):
            launchers.append(component)
        if accepts(node, 'android.intent.category.INFO'):
            info.append(component)
    if len(launchers) != 1 or len(info) > 1:
        raise SafetyError('Expected one enabled exported launcher and at most one INFO entry.')
    # Match Android getLaunchIntentForPackage: prefer the permanent INFO owner.
    return info[0] if info else launchers[0]


def apk_metadata(apk, aapt, run=call):
    text = run([aapt, 'dump', 'badging', apk])
    package = re.search(r"^package: name='([^']+)' versionCode='(\d+)'", text, re.M)
    target = re.search(r"^targetSdkVersion:'(\d+)'", text, re.M)
    activity = re.search(r"^launchable-activity: name='([^']+)'", text, re.M)
    if not package or not target:
        raise SafetyError('APK identity or target SDK is missing.')
    launch_activity = activity[1] if activity else manifest_launch_activity(
        run([aapt, 'dump', 'xmltree', apk, 'AndroidManifest.xml']), package[1])
    try:
        with zipfile.ZipFile(apk) as archive:
            abis = sorted({name.split('/')[1] for name in archive.namelist() if name.startswith('lib/') and name.endswith('.so')})
    except zipfile.BadZipFile as error:
        raise SafetyError('Invalid APK archive.') from error
    return dict(package=package[1], version=int(package[2]), target=int(target[1]), activity=launch_activity, abis=abis)


def certificate(apk, apksigner, run=call):
    text = run([apksigner, 'verify', '--print-certs', apk])
    certificates = sorted(set(re.findall(r'^(?:Signer #\d+|V[234](?:\.\d+)? Signer(?: #\d+)?):? certificate SHA-256 digest: ([0-9a-fA-F]{64})$', text, re.M)))
    if not certificates:
        raise SafetyError('APK signing certificate could not be verified.')
    return [value.lower() for value in certificates]


def package_state(text):
    version = re.search(r'\bversionCode=(\d+)\b', text)
    user = re.search(r'^\s*User 0: (.+)(?:\n(?!\s*User \d+:).*)*', text, re.M)
    if not version or not user or not re.search(r'\binstalled=true\b', user[0]):
        raise SafetyError('Existing user-0 App not found. Update aborted; never replace a missing installation silently.')
    fields = dict(version=int(version[1]))
    for name in ('ceDataInode', 'deDataInode', 'firstInstallTime'):
        match = re.search(r'\b' + name + r'=([^\n ]+(?: [^\n ]+)?)', user[0]) if name == 'firstInstallTime' else re.search(r'\b' + name + r'=(\d+)', user[0])
        if not match or (name != 'firstInstallTime' and int(match[1]) == 0):
            raise SafetyError(f'Cannot establish data preservation: {name} unavailable.')
        fields[name] = match[1].strip()
    return fields


def installed_apk(adb_command, run=call):
    paths = run([*adb_command, 'shell', 'pm', 'path', '--user', '0', PACKAGE]).splitlines()
    if len(paths) != 1 or not re.fullmatch(r'package:/data/app/[A-Za-z0-9_+=.~/-]+\.apk', paths[0]):
        raise SafetyError('Expected one installed base APK; split installations need an explicit migration.')
    return paths[0][8:]


def protected_state(serial, tools=None, run=call):
    adb = (tools or sdk_tools())[0]
    text = run([adb, '-s', serial, 'shell', 'dumpsys', 'package', PACKAGE])
    # Only a named emulator may start without the official App installed.
    if serial.startswith('emulator-') and 'Unable to find package:' in text:
        return None
    return package_state(text)


def sha256(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def require_absent_package(adb_command, run=call):
    # Include retained/uninstalled packages; never treat a different user or
    # missing data-directory metadata as permission for a fresh installation.
    packages = run([*adb_command, 'shell', 'pm', 'list', 'packages', '-u', PACKAGE])
    state = run([*adb_command, 'shell', 'dumpsys', 'package', PACKAGE])
    # Android's package filter is a substring search, so the isolated lab
    # package also appears. Require valid output, then match the exact identity.
    rows = [line.strip() for line in packages.splitlines() if line.strip()]
    if any(not re.fullmatch(r'package:[A-Za-z0-9_.]+', line) for line in rows):
        raise SafetyError('Cannot verify package absence from unrecognized package listing.')
    if f'package:{PACKAGE}' in rows or state.strip() != f'Unable to find package: {PACKAGE}':
        raise SafetyError('First installation requires a completely absent package, including retained data and other users.')


def update(apk, serial, tools, record, *, check_only=False, launch=False, first_install=False, run=call):
    # Freeze the artifact so a parallel build cannot replace it during install.
    with tempfile.TemporaryDirectory(prefix='raft-install-artifact-') as temporary:
        staged = Path(temporary) / 'candidate.apk'
        shutil.copyfile(apk, staged)
        return _update(staged, serial, tools, record, check_only=check_only, launch=launch,
                       first_install=first_install, run=run)


def _update(apk, serial, tools, record, *, check_only=False, launch=False, first_install=False, run=call):
    adb, aapt, apksigner = tools
    adb_command = [adb, '-s', serial]
    metadata = apk_metadata(apk, aapt, run)
    if metadata['package'] != PACKAGE or metadata['abis'] != ['arm64-v8a'] or metadata['target'] < 37:
        raise SafetyError('Only the official ARM64 APK targeting Android 37 or later can be updated here.')
    apk_hash = sha256(apk)
    if first_install:
        require_absent_package(adb_command, run)
        before = None
    else:
        before = package_state(run([*adb_command, 'shell', 'dumpsys', 'package', PACKAGE]))
    if before is not None and metadata['version'] < before['version']:
        raise SafetyError(f"Version downgrade {before['version']} -> {metadata['version']} blocked. Rebuild with a sufficient build number.")
    with tempfile.TemporaryDirectory(prefix='raft-apk-check-') as temporary:
        snapshot = Path(temporary) / 'installed.apk'
        cert = certificate(apk, apksigner, run)
        if before is not None:
            run([*adb_command, 'pull', installed_apk(adb_command, run), snapshot])
            if cert != certificate(snapshot, apksigner, run):
                raise SafetyError('Signing certificate mismatch. Install blocked; no uninstall fallback.')
        report = dict(apk=metadata, sha256=apk_hash, certificate=cert, before=before,
                      mode='first-install' if first_install else 'update', status='preflight-passed')
        record(report)
        if check_only:
            return report
        # Detect a concurrent local build or changed device installation before mutation.
        if sha256(apk) != apk_hash:
            raise SafetyError('APK or installed App changed during preflight; restart the workflow.')
        if first_install:
            require_absent_package(adb_command, run)
        elif package_state(run([*adb_command, 'shell', 'dumpsys', 'package', PACKAGE])) != before:
            raise SafetyError('APK or installed App changed during preflight; restart the workflow.')
        try:
            report['status'] = 'installing'
            record(report)
            output = run([*adb_command, 'install', *([] if first_install else ['-r']), '--user', '0', apk])
            if not re.search(r'^Success\s*$', output, re.M):
                raise SafetyError('ADB did not confirm success.')
            after = package_state(run([*adb_command, 'shell', 'dumpsys', 'package', PACKAGE]))
            report['after'] = after
            if before is not None and any(before[field] != after[field] for field in ('firstInstallTime', 'ceDataInode', 'deDataInode')):
                raise SafetyError('Installation/data identity changed. Stop; do not launch or retry.')
            if after['version'] != metadata['version']:
                raise SafetyError('Installed version does not match the requested APK.')
            run([*adb_command, 'pull', installed_apk(adb_command, run), snapshot])
            if sha256(snapshot) != apk_hash:
                raise SafetyError('Installed APK hash does not match the requested artifact.')
            report['status'] = 'verified'
            record(report)
            if launch:
                output = run([*adb_command, 'shell', 'am', 'start', '-W', '--user', '0', '-n', f"{PACKAGE}/{metadata['activity']}"])
                if re.search(r'^Error:', output, re.M):
                    raise SafetyError('App launch failed after verified update.')
            return report
        except SafetyError as error:
            report.update(status='failed', error=str(error))
            record(report)
            raise


def flutter_guard(arguments, cwd=None, tools=None, run=call):
    command = next((arg for arg in arguments if arg in ('run', 'drive', 'test', 'install')), None)
    if command is None:
        return
    device = None
    for index, arg in enumerate(arguments):
        if arg in ('-d', '--device-id') and index + 1 < len(arguments):
            device = arguments[index + 1]
        elif arg.startswith('--device-id='):
            device = arg.split('=', 1)[1]
    # Widget tests without a device do not install applications.
    if command == 'test' and device is None:
        return
    if device in ('macos', 'linux', 'windows', 'chrome', 'edge', 'web-server'):
        return
    if command != 'drive':
        raise SafetyError('Android run/test installation is blocked. Build with FVM and use tool/android-install; use an isolated prebuilt APK for drive.')
    if '--keep-app-running' not in arguments or '--no-keep-app-running' in arguments:
        raise SafetyError('Android drive must use --keep-app-running to disable automatic uninstall.')
    binaries = [arg.split('=', 1)[1] for arg in arguments if arg.startswith('--use-application-binary=')]
    for index, arg in enumerate(arguments[:-1]):
        if arg == '--use-application-binary':
            binaries.append(arguments[index + 1])
    if len(binaries) != 1:
        raise SafetyError('Android drive requires one prebuilt, identity-verified test APK; source namespace is not proof of isolation.')
    apk = (Path(cwd or Path.cwd()) / binaries[0]).resolve()
    metadata = apk_metadata(apk, (tools or sdk_tools())[1], run)
    if metadata['package'] != LAB_PACKAGE:
        raise SafetyError(f'Android drive accepts only {LAB_PACKAGE}, never the official App.')
