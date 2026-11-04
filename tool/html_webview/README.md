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

`wpe-build-order.patch` adds only the WPE JavaScriptCore JIT target's dependency
on its generated public/private headers. The upstream 2.54.2 graph can otherwise
start the JIT precompiled header before those headers exist. It changes build
ordering; compiler options, JIT behavior and security features are unchanged.

`wpe-network-data-order.patch` gives the split WPE NetworkProcess target its
generated directory-listing resource header as a source dependency. The same
upstream resource generator still produces the header and implementation; this
only prevents the split target from compiling before the header exists. Its
hash is part of source preparation and SDK identity, so an earlier SDK without
this adapter cannot silently satisfy the new pin.

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
the Flutter plugin's `.so` export alone does not make a usable runtime. Include
the matching GIO TLS module and its dependencies in the AppImage's configured
`lib/gio/modules` directory: an empty directory there prevents HTTPS document
loads even if a loopback HTTP fixture works. Generate the matching module cache
with the packaged GLib tools; never load arbitrary host modules into bundled GLib.
Retain the source, licenses, package versions and SHA256 manifest. Validate the whole
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

## Reusing the SDK and runtime

A completed engine build can be staged once as a reusable SDK. Preserve the
`include`, `lib`, `libexec` and `share` trees together. Add compatible libwpe
headers/library, the full reviewed runtime dependency closure, and the matching
GIO GnuTLS backend/cache. Rewrite the four required `.pc` files (WPE WebKit,
WPEPlatform, headless WPEPlatform and libwpe) to use:

```text
prefix=${pcfiledir}/../..
libdir=${prefix}/lib
includedir=${prefix}/include
```

Include the matching `gio-launch-desktop` helper under `libexec/raft-html-webview`,
and the GStreamer scanner under `libexec/gstreamer-1.0`. Stage the reviewed media
plugins under `lib/gstreamer-1.0`, including core elements; every plugin needs its
package/archive/notice record and ELF closure. Supported media formats are the
ones in this reviewed plugin set, not whichever plugins happen to exist on the
host. Native format acceptance remains separate from CSS/JavaScript/canvas.

Under `share/raft-html-webview`, retain `source-inputs.json`, the actual generated
`cmakeconfig.h`, `runtime.marker`, package/source notices in `licenses/`, and
`packages.json`. The latter has an `artifacts` array. Every entry names `name`,
`version`, HTTPS source/package `url`, exact archive `sha256`, relative `notice`
under `licenses/`, and `files` (the relative binaries supplied by that artifact).
Every ELF file must have such a source/package record. These records describe
the authenticated build inputs; they do not replace the signed repository/source
authentication receipts or native acceptance. Keep those receipts alongside
the staged SDK. Files must have no group/world write or setuid/setgid bits.

From the repository root, seal the complete staged prefix:

```sh
python3 -m tool.html_webview.payload seal --prefix /work/raft-html-wpe-sdk
```

This creates `share/raft-html-webview/payload.json` and prints its SHA256. It checks
the current source/adapter pins, required helpers/TLS/cache/headers/pkg-config,
production sandbox configuration, all file hashes/modes and ELF architecture /
GLIBC ceiling. It refuses a previous manifest and never changes an installed
runtime. It does **not** establish full dependency closure or HTML behavior; run
native acceptance before reviewing this manifest as a release input.

Archive the four top-level trees together after that review and record the
whole archive's actual SHA256. There is no automatic download, unknown binary
hash, remote publication or privileged installation in this workflow. Restore
only a reviewed archive into a new directory:

```sh
python3 -m tool.html_webview.payload restore \
  --archive /inputs/reviewed-wpe-sdk.tar.xz --sha256 REVIEWED_ARCHIVE_SHA256 \
  --destination /work/restored-wpe-sdk
```

Restore verifies the caller's archive pin before creating a destination, bounds
the archive, rejects unsafe entries and verifies its full embedded manifest.
It preserves failed restores and existing directories for investigation. The
archive pin authenticates its embedded manifest; neither pin may be inferred
from an untrusted download itself.

For a subsequent build, use this restored prefix only through private environment
configuration: prepend its `lib/pkgconfig` to `PKG_CONFIG_PATH` and provide its
library directory to the build linker. Do not replace host packages or modify
the pub cache. Set `RAFT_HTML_WEBVIEW_SDK` to that prefix and
`RAFT_HTML_WEBVIEW_MANIFEST_SHA256` to the reviewed manifest hash for packaging.
Both values are required together. With neither supplied, the existing Linux
tar/AppImage packaging path is unchanged.

Linux tar and AppImage packaging copy the runtime/helpers/resources after
verifying the entire SDK again. Different existing media/plugin bytes cause a
failure rather than an overwrite. Build-only headers/pkg-config/static archives
stay out of the application; runtime aliases become private regular copies so
ELF RPATH changes cannot mutate the SDK. Every nested helper or module receives
an RPATH relative to the shared application `lib` directory. ELF dependency
checks include the helpers and GIO module. A separate `packaged-runtime.json`
records the final bytes after those RPATH changes and preserves the original
source-manifest pin. The AppImage stage verifies that receipt before further
packaging and records its own final bytes again.

With this payload, the tar's `run-raft` launcher and desktop entry select the
matching GIO module, GStreamer plugins/scanner and a registry scoped to the
payload's hash. The main ELF keeps its original name. AppImage uses the same
environment setup. Both restore the original host GIO/media environment before
launching an external desktop program. The plugin-path/registry rules follow
the [GStreamer environment contract](https://gstreamer.freedesktop.org/documentation/gstreamer/running.html)
and [registry contract](https://gstreamer.freedesktop.org/documentation/gstreamer/gstregistry.html?gi-language=c).
Browser session data remains managed by the separate ephemeral WebView policy;
this media registry stores plugin metadata.

Scanner and registry paths are set in both the `_1_0` and unversioned variables:
GStreamer prefers the former, while WebKit's sandbox binding code reads
`GST_PLUGIN_SCANNER` and `GST_REGISTRY`. They must identify the same contained
helper and writable registry directory. Both original host values are restored
for external desktop launching.

`python3 -m unittest tool.tests.test_html_webview_payload` covers pinned restore,
malformed archives, preservation, byte/mode drift, provenance/TLS requirements,
SDK/runtime separation, collisions and nested RPATH, including the unchanged
no-payload Linux packaging path. Its small synthetic payload is explicitly not
an engine, native run, signed package or release acceptance result.

The Linux plugin uses a complete build-local source copy. The configure step
checks the exact hashes of every modified upstream file before applying
`patch_linux_plugin.py`; it never edits the Pub cache. This backport uses the
WPE 2.54 reduced-motion setting, transmits native user-gesture and redirect
metadata with the actual request method, and rejects navigation when its host
policy callback fails. Redirects cannot reuse gesture metadata to open an
external browser.

Pointer release follows WPE's own Wayland implementation: clear the released
button before constructing the Up event, while preserving other held buttons
and keyboard modifiers. The old adapter reported a still-pressed button in
`mouseup.buttons`, preventing a complete pointer-up sequence.

Linux consumers require CMake 3.24 or newer and the distribution's
`nlohmann-json3-dev` 3.11.3 or newer. Configure resolves that installed package
before the plugin's unpinned FetchContent fallback; it does not fetch JSON
sources. The pinned Noble development package can also be extracted into a
private prefix selected through `CMAKE_PREFIX_PATH` for an offline build.

The preview's explicit `allowFileAccess: false` also cancels native file chooser
requests before either the Dart callback or GTK fallback. This is required
because the pinned Linux plugin's chooser-mode decoder does not support Linux;
its callback exception otherwise opens the native chooser. Other plugin users
retain the original default until they explicitly disable file access.
`python3 -m unittest tool.tests.test_linux_html_plugin` verifies hash rejection,
cache preservation and the actual original/patched native chooser callback
against external API test doubles. Actual UI acceptance remains separate.

### Linux Dart input ordering

The pinned plugin awaits native focus during pointer Down. Its original Up,
Cancel and Move callbacks can overtake that await, losing a quick first click.
`linux_pointer.py` adds one FIFO around the existing callbacks and retains the
focus-before-Down requirement. A failed focus drops that incomplete gesture;
the next Down can retry. Disposal releases the wait and prevents queued or late
callbacks from sending input. This adapter does not change WebKit gesture policy.

The normal dependency preparation step materializes the official Pub archive
as a private path dependency, before `pub get`:

```sh
python3 -m tool.html_webview.linux_pointer --download \
  --archive .dart_tool/raft_plugin_sources/flutter_inappwebview_linux-0.1.0-beta.1.tar.gz \
  --destination .dart_tool/raft_plugins/flutter_inappwebview_linux
```

The archive is fixed to SHA256
`2e1a3b09bb911fb5a8bb155cb7f1eb1428a19b6e20363b9db48beef428b8cef5`.
Only `lib/src/in_app_webview/custom_platform_view.dart` changes; the generated
receipt hashes all 214 original and output files and their modes. Existing output
must match exactly, including the adapter identity. Drift is preserved and rejected,
never repaired in place. Offline preparation can use the same verified archive
without `--download`. The shared Pub cache and package_config are never patched.

Use Pub's supported root workspace `dependency_overrides` path to the generated
directory. Launcher and CI preparation must run before resolving that path; the
preparer itself does not edit the workspace manifest, lockfile or package graph.

The root workspace declares this override. `tool/flutter` prepares and verifies
it before dependency, analysis, test and build commands on every host platform;
Pub needs the directory even when that host does not run the Linux plugin.
`--offline` and `--no-pub` require the already authenticated private archive and
never fetch it. Version/doctor/cache-management commands do not prepare it.
The adapter checks POSIX permission bits on POSIX hosts; NTFS preparation keeps
the same full byte, file-identity and link checks without claiming POSIX modes.
The CMake native adapter still applies to its separate build copy.

`linux_html_pointer_test.dart` exercises the actual plugin widget through delayed
MethodChannel test doubles, including mouse/touch order, Cancel, already-focused
input, failure recovery and disposal. It proves callback ordering, not native
WebKit click delivery; real first-click acceptance remains required separately.

## Building and restoring an SDK in CI

The source-defined builder is `tool/html_webview/Dockerfile`. It starts from a
fixed Ubuntu 24.04 image digest and uses signed Noble repositories. Within that
private image it applies current Noble security updates, installs the declared
build/development packages, and preserves exact package archives and APT metadata.
JPEG development files are explicit dependencies. Upstream's video configure
check also requests GStreamer MPEG-TS development files even when the separate
MPEG-TS feature is OFF. The builder downloads only the two signed bad-plugin
support development/runtime archives; the worker extracts them to a private
build prefix and rewrites their PC prefix. It does not install bad-dev's unrelated
OpenCV dependency tree or enable extra runtime plugins. Actual archive hashes and
the private prefix inventory are retained with the SDK. Runtime staging follows
actual DT_NEEDED; no private support library may be labelled as WebKit source or
satisfied through an arbitrary host fallback.

Clang 18.1.3 and the reviewed GCC13 backtrace headers/archive are checked again by
the worker. Two compatible libwpe archives are separately pinned in
`libwpe-pins.json` and extracted rather than installed over Ubuntu. These operations
never install or upgrade packages on the developer's host.

Each Dockerfile RUN enters nice15 itself; a Docker client's nice value does not
propagate through the daemon. For a coordinated local legacy build, use
`DOCKER_BUILDKIT=0` with `--cpuset-cpus=0,1 --cpu-period=100000
--cpu-quota=200000 --memory=16g --memory-swap=16g`, a unique
`--build-arg RAFT_HTML_SDK_BUILD_ID=...` and
`--build-arg RAFT_HTML_SDK_ENFORCE_LIMITS=1`. Before APT starts the inner check
records and verifies the actual cgroup/nice values. An external shared-gate
watcher must operate only on this exact build ID's recorded new containers;
control-plane labels do not authorize touching another container.

Build this environment on a dedicated runner, then pass its actual immutable
image ID to the bounded worker:

```sh
docker build --platform linux/amd64 --pull --no-cache -t raft-html-sdk-builder -f tool/html_webview/Dockerfile tool/html_webview
IMAGE_ID=$(docker image inspect --format '{{.Id}}' raft-html-sdk-builder)
python3 -m tool.html_webview.sdk build \
  --archive /inputs/wpewebkit-2.54.2.tar.xz \
  --work /work/new-sdk-build --image "$IMAGE_ID" --max-seconds 21600
```

The source archive still requires the fixed reviewed SHA above. No mutable image
tag is accepted by the worker. Source compilation runs as the caller's non-root
UID, at nice15 once, with two CPUs, 16GiB, no network and no host permission bypass.
The source archive is mounted read-only; hash verification, extraction and patching
also run inside that same capped worker, before configuration. Host setup writes
only small requests and controls Docker. It configures the fixed production options and checks the successful feature
fingerprint before compiling only five engine roles plus InspectorResources.
The worker uses only two isolated libbacktrace headers, never GCC's entire
intrinsics include directory. Install uses a new DESTDIR and cannot implicitly
build `all`. Previous work directories, failed stages, logs and containers remain
available; a bounded stop targets only that invocation's exact labelled container.
On shared machines, obtain the existing native-build resource allocation before
running this substantial build; this CLI does not override a shared full-check
supervisor or provide a new global scheduler.

The worker authenticates each APT InRelease, the complete Packages checksum chain
and each selected archive body before private extraction. It stages the actual
ELF closure, matching GIO/GStreamer helpers/modules, relative pkg-config, full
source/package notices, exact marker and content manifest. Standard license texts
and cross-package copyright directory aliases are resolved within authenticated
archives. Host libc, graphics drivers and Bubblewrap are excluded. Any missing
exact archive, conflicting bytes, unresolved dependency, unsafe link, altered
security configuration or GLIBC requirement above 2.39 stops the job and retains
its evidence. Stage/seal and basic codec checks are separate from actual HTML,
HTTPS, sandbox, session-cleanup and packaging acceptance.

The image's actual installed versions and archive hashes are recorded in the
build key together with source, adapters, worker, configuration and compiler
identity. A new Noble security patch produces a new key; it must not be described
as the package set of an older build. A runtime patch different from its compile
input must be reviewed and recorded explicitly. The automatic builder stages its
own matching build/runtime versions and does not silently apply such overrides.
Existing media/HTML byte conflicts still fail in the application packager.

On success `/work/new-sdk-build/result.json` has this schema (real hashes are
computed by that invocation, never copied from this example):

```json
{
  "state": "sdk-ready",
  "prefix": "sdk",
  "manifestSha256": "ACTUAL_CONTENT_MANIFEST_SHA256",
  "archive": "sdk.tar.gz",
  "archiveSha256": "ACTUAL_ARCHIVE_SHA256",
  "buildKey": "ACTUAL_CANONICAL_BUILD_INPUT_KEY",
  "sourceInputs": "prepared/source-inputs.json",
  "scope": "Authenticated SDK closure/content/ELF floor only; native renderer acceptance not run"
}
```

A trusted CI build job publishes that archive as a normal workflow artifact and
passes its actual `archiveSha256` as a same-run job output. The dependent job uses
that trusted output, rather than a downloaded archive's self-reported hash:

```sh
python3 -m tool.html_webview.sdk restore \
  --archive /inputs/sdk.tar.gz --sha256 "$TRUSTED_BUILD_JOB_ARCHIVE_SHA256" \
  --destination /work/new-restored-sdk
```

The JSON result supplies the restored prefix and actual content-manifest pin for
`RAFT_HTML_WEBVIEW_SDK` / `RAFT_HTML_WEBVIEW_MANIFEST_SHA256`. There is no dependency
on a private machine path or unpublished release URL. Artifact publication and
trust decisions remain in the CI workflow; the CLI does not publish a release,
create a tag, infer trust from cache names or download arbitrary SDK binaries.

### Consumer development dependencies

This SDK includes WPE/libwpe headers and the runtime closure. It is **not a complete
replacement for a Linux development sysroot**. Its public `.pc` files require
GLib/GObject/GIO and libsoup development metadata/headers, including applicable
private Cflags dependencies such as sysprof-capture. The Flutter plugin also
requires GTK3, epoxy, libsecret and wayland-server development packages. Use the
matching Noble builder/development environment above, or a separately verified
development sysroot; do not mix arbitrary newer/older host headers with bundled
libraries or assume a runtime `.so` supplies development headers.

Noble libsoup 3.4.4's actual pkg-config graph does not require json-glib. Additional
plugin versions may differ. The builder supplies the signed Noble nlohmann-json3
3.11.3 development package; consumer CMake should prefer its exact local package
config. Upstream FetchContent without URL_HASH must not become an implicit
unverified network dependency. Native consumer compilation still needs its own
real validation before claiming support on a particular machine.

### Normal release workflow

`release.yml` separates the requested Linux tar/AppImage entries from the
Windows, macOS and Android matrix. When either Linux format was selected, one
`html-sdk` job builds the source-defined x86_64 Noble image and invokes the SDK
CLI once with `--max-seconds 10800`; its job limit is 210 minutes. No binary
cache supplies a new pin. The producer verifies the archive bytes and complete
sealed prefix before emitting the archive and content-manifest SHA256 values.
The normal workflow artifact ID and these two same-run outputs go to both
Linux consumers; downloaded `result.json` is diagnostic metadata, not authority
for selecting a pin.

Each consumer requires a nonempty artifact ID and both pins before downloading,
restores into a new private prefix, compares the returned manifest hash to the
producer's expected hash, then exports `PKG_CONFIG_PATH`, `LIBRARY_PATH`,
`RAFT_HTML_WEBVIEW_SDK` and `RAFT_HTML_WEBVIEW_MANIFEST_SHA256`. Both formats use
the Noble 24.04 hosted runner and its signed APT development packages, including
libsoup 3, json-glib and nlohmann-json 3.11.3. The tar platform remains disabled
by default; manually selecting it uses the same Noble graph. The consumers keep
their 60-minute limit. Existing per-platform publishing, Android signing,
macOS signing and AppImage startup/compatibility requirements still apply.

The independent-platform jobs have no SDK dependency. An SDK failure therefore
blocks the selected Linux formats without holding or skipping the other
platforms. Failed source-build logs and receipts are uploaded separately when
the runner can finish its diagnostic steps. These workflow/dataflow and tool
tests do not establish a successful Actions source build, packaged renderer,
native acceptance or release; those require the actual run and artifact readback.
