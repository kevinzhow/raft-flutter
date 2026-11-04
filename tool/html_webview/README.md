# Portable Linux HTML runtime

The desktop adapter uses the maintained `flutter_inappwebview_linux` 0.1.0-beta.1
texture renderer. This folder adapts **paths**, rather than implementing a web
engine. It does not add a document-to-application JavaScript channel.

The reviewed engine is [WPE WebKit 2.54.2](https://wpewebkit.org/release/wpewebkit-2.54.2.html).
Its source SHA256 is
`f3284e19e47fcb5ac8c63c2e1c113dbd65b2423eb8a545f5b345707829004f56`.
The upstream source remains an immutable input; `wpe-relocation.patch` and
`raft_wpe_runtime_paths.h` are separate, reviewable adapter inputs. A version
update must review the current [security advisory](https://webkitgtk.org/security.html)
and source authentication before changing this pin. A distribution's older WPE
package is not a security-supported substitute.

## Preparing source

Run inside the dedicated Ubuntu 24.04 build environment. Download the archive
through the project's reviewed source-provenance process, then prepare a **new**
directory:

```sh
python3 tool/html_webview/prepare_source.py \
  --archive /inputs/wpewebkit-2.54.2.tar.xz --destination /work/wpe-source
```

The tool checks the archive SHA, safely extracts it, applies the patch and
records exact source/header/patch hashes. It never installs packages, compiles
an engine, reuses a failed directory or changes the original archive. Preserve
the source receipt and patch log with the engine payload.

Configure a production Release WPE 2.0 build with Bubblewrap/seccomp enabled,
modern WPEPlatform + headless enabled, GPU process enabled and `lib` as the
installation library directory. Documentation, introspection, test programs
and MiniBrowser are unnecessary. Do not enable developer mode to obtain
environment-selected helper paths. The Flutter plugin also links `wpe-1.0`,
even with the engine's legacy API disabled; supply that compatible dependency
separately. Compiler, dependency and package provenance belong in the build
receipt, along with the actual configuration.

Compile only in a coordinated bounded slot: at most two CPUs and the shared
native-check lock on shared machines. Engine compilation is substantial; this
source-preparation command is not a build or runtime acceptance result.

## One runtime layout

The relocatable payload has this structure, relative to the canonical loaded
engine library's parent prefix:

```text
lib/libWPEWebKit-2.0.so.1
lib/wpe-webkit-2.0/injected-bundle/libWPEInjectedBundle.so
libexec/wpe-webkit-2.0/WPEWebProcess
libexec/wpe-webkit-2.0/WPENetworkProcess
libexec/wpe-webkit-2.0/WPEGPUProcess
libexec/raft-html-webview/xdg-dbus-proxy
share/raft-html-webview/runtime.marker
```

The three WebKit helpers, injected bundle and matching DBus proxy are required
together. Package their complete ELF dependency closure and resources;
the Flutter plugin's `.so` export alone does not make a usable runtime. Retain
the source, licenses, package versions and SHA256 manifest. Validate the whole
payload against the Ubuntu 24.04 GLIBC 2.39 ceiling, using the existing AppImage
packager's ELF checks. Do not include a replacement libc or device driver.

After validating the payload, the packager writes **exactly** these marker bytes
(substitute `aarch64` for that architecture):

```text
raft-html-wpe-runtime-v1
wpewebkit=2.54.2
source-sha256=f3284e19e47fcb5ac8c63c2e1c113dbd65b2423eb8a545f5b345707829004f56
relocation=raft-v1
arch=x86_64
```

The final newline is required. The marker validates identity/layout; artifact
SHA manifests and release signing establish package integrity. The marker is
not a substitute signature or protection against an owner rewriting their
installed application.

The resolver uses the loaded library's canonical location, rejects a mismatched
SONAME location, requires the exact marker, rejects marker symlinks/special
files and checks every required helper/resource remains inside that payload.
It never searches PATH, an environment override or system WebKit helpers.
Invalid identity/layout returns an invalid launch identifier through WebKit's
existing failed-launch path, instead of aborting the host or executing a
fallback helper. Validated paths are shared by helper launching, injected-bundle
loading and the existing **read-only** sandbox bindings. Bubblewrap, seccomp,
permission policy and CSP are retained.

### System sandbox prerequisite

Bubblewrap is the one intentional system executable: **only `/usr/bin/bwrap`**.
Some distributions authorize user namespaces through an AppArmor profile bound
to that exact path. Relocating identical bytes into an application bundle can
therefore prevent sandbox creation. Do not bundle a replacement, add setuid,
install a policy or turn off the sandbox to make a probe pass.

The native resolver requires this canonical non-symlink native ELF and every
parent directory to be root-owned and not writable by group/others. The file
must be readable/executable without setuid/setgid. If it is missing or invalid,
the in-app renderer fails closed. A copied, environment-selected or PATH-selected
helper is never used. A distribution-installed Bubblewrap package is a runtime
prerequisite; its absence is not permission for an automatic system install.

Run the read-only deployment check on the **runtime host**, separately from
the build container:

```sh
python3 tool/html_webview/check_system_bwrap.py --probe
```

It records the exact helper SHA/version, verifies the executable against the
installed `bubblewrap` package through dpkg/RPM, and optionally tests read-only
namespace creation. Stripped package documentation is reported separately.
That probe does not establish the actual WebKit sandbox or HTML behavior. A
container may deny user namespaces even when the native runtime host supports
them. Retain the failed probe; do not change its security configuration.

The outer Bubblewrap launcher uses host loader libraries: it clears
`LD_LIBRARY_PATH`, `LD_PRELOAD` and `LD_AUDIT` for that one trusted executable.
The sandboxed WebKit child still receives the explicit read-only bundled library
path through upstream's existing `--setenv` argument. No policy is weakened.

`python3 tool/tests/test_html_webview_runtime.py` compiles only a tiny resolver
fixture and tests relocation, invalid identities, missing files, symlink escape,
special files, traversal and trusted-system-helper checks. Root-owned negative
fixtures can be supplied by the dedicated build container; the tests never
modify the real system helper. They do not compile WebKit, launch helpers or prove
renderer, sandbox, AppImage or HTML behavior. Native acceptance remains required.
