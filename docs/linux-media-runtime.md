# Linux attachment media runtime

Run `tool/prepare-media-linux` before a Linux build. This downloads seven pinned Ubuntu amd64 packages into `.local/media-linux`, extracts them locally, and copies libmpv's resolved codec dependency closure together with every package's distribution copyright notice. It does not install or upgrade system packages. CMake puts these generated libraries under the application's `lib` directory and notices under `data/notices/raft-media`; its relative RPATH applies to transitive decoder dependencies.

The prepared bundle currently contains 208 libraries. `manifest.json` records each library's provider/version/SHA-256 and downloaded package hashes. `ldd-bundle.txt` confirms no unresolved library on this build host. This is a host-matched Ubuntu resolute amd64 runtime: the OS still supplies glibc, its loader, audio/display devices and device drivers. Portability to another distribution or older glibc has not been proven. Binary artifacts stay ignored; rebuild the bundle on its supported build environment.

Downloaded packages are pinned to `libmpv2 0.41.0-2ubuntu4`, `libmpv-dev 0.41.0-2ubuntu4`, `libmujs3 1.3.8-2`, `liblua5.2-0 5.2.4-4`, `libsndio7.0 1.10.0-0.2`, `libsixel1 1.10.5-1build1`, and `libxpresent1 1.0.1-1build1`. These use Ubuntu's configured, signed package indexes. The manifest includes official Launchpad source-package links. For copied host libraries, retrieve the matching source package using the source name/version reported by `dpkg-query -W -f='${source:Package} ${source:Version}' <package>` and `apt-get source <source>=<version>`; [Ubuntu's source archive](https://launchpad.net/ubuntu/+source) supplies the original source packages. Distribution copyright notices include upstream locations and license terms; they are preserved with the application. Several media components use GPL licenses. Distributors must review those included terms and provide the corresponding source for the versions they distribute.

PDF page rendering uses Android's `PdfRenderer` and Linux's installed Poppler `pdfinfo`/`pdftoppm` utilities. Linux requires `poppler-utils` from its distribution; it is a separate OS dependency, not silently downloaded during a preview.

Media is downloaded once into a private, bounded local lease; the decoder receives its local file path through `loadfile`. The player permits only the file protocol, disables network references, automatic extra audio/subtitle files, scripts, yt-dlp, and disk media caching, and does not autoplay. Closing, logout, authority loss and backgrounding stop playback; closing/revocation releases the private input. No signed URL enters the persistent application cache.

Pinned download SHA-256 records (no binary artifacts are committed):

| Package | SHA-256 |
| --- | --- |
| libmpv-dev | `366c01526e737eab9bd053795ebec8729178ca08ca8f519346a59858e5278b86` |
| libmpv2 | `7ab4e586007e65956669fc3a5bd3a870b6f46dd671de20a0572ce7f4ff0fd3d5` |
| libmujs3 | `84a4eac3add5f1ba35f50e8dca8180368a5123b1e732212d1a11c9607336c564` |
| liblua5.2-0 | `1d667717e43ddf79c3d3761a0a4e5c2f92a9970d8b0aeb396ba71835821f095f` |
| libsndio7.0 | `64a89ce28e11f55c02cdae8e959e9bf84c97128d2c04a2881675b76058d6dddb` |
| libsixel1 | `4062a008194d5a336e9bdd11bfb454db0c3d5670a481c4922bc5bcefaa3b4cf2` |
| libxpresent1 | `ae77a5987dfacb8ab2a0230cfccfc8d43f0927f9c23fb8796cba370075a42a59` |

The local development package supplies mpv headers. A generated, relocated pkg-config file describes only the public dynamic client ABI used by media_kit_video; it does not require the unused codec/static-link development headers. Host pkg-config configuration and the Dart package cache remain unchanged.

## Delivery staging checks

`tool/build-deliverables` builds the release entry point `lib/main.dart` after engineering, Linux and Android runs have passed against the same source hash. It does not pass authentication fixtures or test defines. The Linux generated Dart defines are checked before packaging; unexpected non-Flutter defines stop delivery. Android artifacts use the local debug signing key for acceptance, and are not store releases.

The staging copy normalizes every shipped ELF to relative DT_RPATH (`$ORIGIN/lib` for the executable, `$ORIGIN` for libraries), using a locally extracted Ubuntu `patchelf 0.18.0-1.4build1` package with SHA-256 `dd6cde91e0a77a73335a93a4ce41801f21dac36d2158539093c241e46e11b9fc`. It does not modify the build output or install a system package. The JNI native asset pulled in through `path_provider_android` is excluded only after checking that no shipped ELF needs `libdartjni.so`; Linux uses `path_provider_linux` and its native media controller. This avoids shipping an unused binary whose lookup path points at the build machine's Java installation.

Staging verifies the prepared media hashes and copyright notices, then records both the prepared hash and the delivered hash after RPATH edits. The executable, libmpv and video plugin must resolve without missing dependencies or libraries from the development tree. The archive includes these dependency checks and the media source/version notices. These checks establish binary dependency lookup on the build host; they do not prove another distribution's ABI or a release login/playback flow. A relocated debug copy passed the staging checks for 217 ELF files; final release build and actual release execution remain separately reported.

The supplied desktop entry uses `Exec=raft_flutter %u` rather than embedding the build directory. For optional desktop and `raft:` URI registration, put the installed executable on PATH or set this entry to its installed absolute path before placing it in the XDG applications directory. Normal launching from the extracted directory uses `./raft_flutter`.

The delivery manifest binds the source hash to engineering logs, native run IDs, original checkpoint inventories, PNG hashes and artifact checksums. Android's real notification shade/click receipt must belong to that same run and source hash. The report publisher checks the artifact bytes against these checksums and preserves the original per-platform TSV files; missing, corrupt or stale native evidence cannot produce a passing summary.
