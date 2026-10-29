"""Package an ARM64 macOS app with verifiable ad-hoc signatures."""
from pathlib import Path
import plistlib
import subprocess

MACHO_MAGIC = {b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf',
               b'\xfe\xed\xfa\xce', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca',
               b'\xca\xfe\xba\xbf', b'\xbf\xba\xfe\xca'}


def run(args):
    subprocess.run([str(x) for x in args], check=True, capture_output=True)


def output(args):
    result = subprocess.run([str(x) for x in args], check=True, capture_output=True)
    return result.stdout, result.stderr


SPARKLE_FRAMEWORK = Path('Contents/Frameworks/Sparkle.framework')
# Sparkle 2 ships these nested bundles; sandboxed apps need Installer.xpc
# (docs/auto-update.md). They keep their own, reviewed entitlement policy.
SPARKLE_NESTED = {'Installer.xpc', 'Downloader.xpc', 'Updater.app'}
UPDATER_PLIST_KEYS = ('SUEnableInstallerLauncherService',)


def sparkle_bundle(app, path):
    """True for the nested bundles that belong to the embedded Sparkle framework."""
    try:
        relative = path.resolve().relative_to(Path(app).resolve())
    except ValueError:
        return False
    return relative.is_relative_to(SPARKLE_FRAMEWORK) and path.name in SPARKLE_NESTED


def nested_bundles(app):
    """Sparkle's nested bundles, deepest first (signing order: inside out)."""
    app = Path(app).resolve()
    found = {p.resolve() for p in app.rglob('*') if p.is_dir() and sparkle_bundle(app, p)}
    return sorted(found, key=lambda p: len(p.parts), reverse=True)


def inventory(app):
    app = Path(app).resolve()
    if (app / 'Contents/embedded.provisionprofile').exists():
        raise ValueError('Public ad-hoc builds must not include a development provisioning profile')
    binaries = []
    for path in app.rglob('*'):
        if path.is_symlink():
            if not path.resolve().is_relative_to(app):
                raise ValueError('macOS app contains an external symlink')
            continue
        if path.is_dir() and path.suffix in {'.app', '.xpc', '.appex'} and not sparkle_bundle(app, path):
            raise ValueError('Nested executable bundles require an explicit entitlement policy')
        if path.is_file():
            with path.open('rb') as stream:
                if stream.read(4) in MACHO_MAGIC:
                    binaries.append(path)
    if not binaries:
        raise ValueError('macOS app has no native executables')
    return sorted(binaries, key=lambda p: len(p.parts), reverse=True)


def configure_updater(app, public_key):
    """Embed the Sparkle EdDSA public key before signing; empty disables updates."""
    plist = Path(app) / 'Contents/Info.plist'
    info = plistlib.loads(plist.read_bytes())
    if public_key:
        info['SUPublicEDKey'] = public_key
    else:
        info.pop('SUPublicEDKey', None)
    plist.write_bytes(plistlib.dumps(info))


def verify_updater(app, public_key):
    """Keys, launcher service and Sparkle bundles must agree with the build's intent."""
    app = Path(app)
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info.get('SUPublicEDKey', '') != (public_key or ''):
        raise ValueError('macOS update public key differs from the release configuration')
    if public_key:
        if info.get('SUEnableInstallerLauncherService') is not True:
            raise ValueError('Sandboxed Sparkle needs SUEnableInstallerLauncherService')
        names = {p.name for p in nested_bundles(app)}
        if 'Installer.xpc' not in names:
            raise ValueError('Sparkle Installer.xpc is missing from the app bundle')
        for bundle in nested_bundles(app):
            run(['codesign', '--verify', '--strict', bundle])
    return {'enabled': bool(public_key), 'nestedBundles': len(nested_bundles(app))}


def verify(app, entitlements, version, number, arch='arm64', public_key=''):
    app = Path(app)
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if (info.get('CFBundleIdentifier') != 'app.raft.raftFlutter'
            or info.get('CFBundleShortVersionString') != version
            or str(info.get('CFBundleVersion')) != str(number)):
        raise ValueError('macOS identity/version differs from the release plan')
    binaries = inventory(app)
    main = app / 'Contents/MacOS' / info['CFBundleExecutable']
    main_archs = output(['lipo', '-archs', main])[0].decode().split()
    if main_archs != [arch]:
        raise ValueError('macOS main executable differs from the planned architecture')
    for binary in binaries:
        if arch not in output(['lipo', '-archs', binary])[0].decode().split():
            raise ValueError(f'macOS dependency lacks {arch}: {binary.relative_to(app)}')
        run(['codesign', '--verify', '--strict', binary])
    run(['codesign', '--verify', '--deep', '--strict', app])
    signature = output(['codesign', '-d', '-vv', app])[1].decode()
    if 'Signature=adhoc' not in signature or 'Authority=' in signature:
        raise ValueError('macOS public release must have an ad-hoc signature')
    actual = plistlib.loads(output(['codesign', '-d', '--entitlements', ':-', app])[0])
    expected = plistlib.loads(Path(entitlements).read_bytes())
    if actual != expected:
        raise ValueError('macOS release entitlements differ from the reviewed configuration')
    return {'signature': 'ad-hoc', 'architecture': arch, 'nativeCodeItems': len(binaries),
            'bundleIdentifier': info['CFBundleIdentifier'], 'entitlementsVerified': True,
            'updater': verify_updater(app, public_key)}


def package(source, stage, entitlements, version, number, arch='arm64', public_key=''):
    source, stage = Path(source), Path(stage)
    stage.mkdir()
    app = stage / source.name
    run(['ditto', source, app])
    configure_updater(app, public_key)
    # Sign code inside out, preserving distinct root entitlements. Never use
    # --deep for signing: that applies root permissions to nested code too.
    for binary in inventory(app):
        run(['codesign', '--force', '--sign', '-', '--timestamp=none', binary])
    # Sparkle's nested bundles are sealed as bundles, deepest first. Its XPC
    # services keep their own entitlements; no hardened runtime, so there is no
    # library validation to reject ad-hoc Sparkle (docs/auto-update.md).
    for bundle in nested_bundles(app):
        preserve = ['--preserve-metadata=entitlements'] if bundle.suffix == '.xpc' else []
        run(['codesign', '--force', '--sign', '-', '--timestamp=none', *preserve, bundle])
    for framework in sorted(app.rglob('*.framework'), key=lambda p: len(p.parts), reverse=True):
        if not framework.is_symlink():
            run(['codesign', '--force', '--sign', '-', '--timestamp=none', framework])
    run(['codesign', '--force', '--sign', '-', '--timestamp=none', '--entitlements', entitlements, app])
    checks = verify(app, entitlements, version, number, arch, public_key)
    (stage / 'READ-ME-FIRST.txt').write_text(
        'Raft for macOS 12 or newer, Apple Silicon (ARM64).\n'
        'Extract the ZIP and move Raft.app to Applications (in-app updates cannot replace\n'
        'an app that is still running from Downloads or the extracted ZIP).\n'
        'This build has an ad-hoc signature and is not notarized by Apple.\n'
        'macOS may block the first launch. If you trust this download, try opening it,\n'
        'then use System Settings > Privacy & Security > Open Anyway and confirm.\n'
        'Managed Macs may not permit this exception.\n'
        'Keep existing development installations backed up: this public signing identity\n'
        'does not grant access to a development-signed installation\'s Keychain session.\n',
        encoding='utf-8')
    return checks


def verify_archive(artifact, work, app_name, entitlements, version, number, arch='arm64', public_key=''):
    work = Path(work)
    work.mkdir()
    run(['ditto', '-x', '-k', artifact, work])
    apps = list(work.glob(f'*/{app_name}'))
    if len(apps) != 1:
        raise ValueError('macOS ZIP must contain exactly one packaged app')
    return verify(apps[0], entitlements, version, number, arch, public_key)
