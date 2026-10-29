# Attachment media playback

Current timeline contract (owner decision 2026-10-17): every platform and window size displays a video poster.
Only opening the full-screen viewer creates video playback; closing it releases playback. See [Video cards](#video-cards)
for poster loading, bounded first-frame extraction and the unified viewer entry. The older inline-card measurements,
handoff descriptions and interaction tables below document the previous implementation and are retained as history;
they are superseded by this contract. Inline audio playback remains supported.

Inline video cards, the media viewer and audio attachments play through one interface,
`AttachmentPlayer` (`apps/raft_flutter/lib/platform/attachment_player.dart`). The engine depends on the platform;
`createAttachmentPlayer` (`attachment_player_factory.dart`) chooses it.

**Video (and inline audio) is streamed, not downloaded.** The player opens the attachment's signed URL itself and reads the byte ranges it
needs; nothing is written to disk by the player, and a file is saved only when the user taps Download
(`AttachmentFiles.save`, system save dialog). The audio *viewer* plays the cached file like PDF and documents (Settings >
Storage). An inline card and the full-screen viewer of the same attachment share
one player (one stream, one buffer, one position); see [Streaming and sessions](#streaming-and-sessions).

| Platform | Engine | Why |
| -------- | ------ | --- |
| Android  | `video_player` -> ExoPlayer (Media3), `VideoPlayerAttachmentPlayer` | System codecs, hardware decoding and colour handling; no libmpv in the APK; viewer HDR through a `SurfaceView` |
| iOS      | `video_player` -> AVPlayer | Same; viewer HDR/EDR through `AVPlayerLayer` (cards are SDR) |
| macOS    | `video_player` -> AVPlayer | Same; viewer HDR through `AVPlayerLayer` |
| Windows  | media_kit (libmpv + bundled FFmpeg), `NativeAttachmentPlayer` | Media Foundation needs the optional HEVC extension |
| Linux    | media_kit (libmpv + bundled FFmpeg), `NativeAttachmentPlayer` | Stock GStreamer (Fedora) has no H.264/HEVC; `tool/prepare-media-linux` still supplies the runtime ([Linux runtime](linux-media-runtime.md)) |

## Dependencies

`pubspec.yaml` depends on `media_kit`, `media_kit_video`, `media_kit_libs_linux`, `media_kit_libs_windows_video` and
`video_player`. It does **not** depend on `media_kit_libs_video` (the umbrella pulls `media_kit_libs_android_video`,
`media_kit_libs_ios_video` and `media_kit_libs_macos_video`, i.e. libmpv/FFmpeg on every platform). `media_kit_video`
still registers a native plugin on Android, iOS and macOS; without a libs package its Apple podspecs build the stub
sources and its Android plugin is a small Java class, and nothing initialises media_kit there:
`MediaKit.ensureInitialized()` runs only inside `NativeAttachmentPlayer`, which only Windows and Linux construct.

## Behaviour of `VideoPlayerAttachmentPlayer`

* Source: `AttachmentSource.network(url, refresh:, start:)`, the signed `disposition=inline` URL
  (`VideoPlayerController.networkUrl`; media_kit `loadfile`). No header is sent: the signature in the URL is the only
  credential. A local `AttachmentSource.file` is still accepted (tests). On the first failure of a streamed source the
  player signs the URL again once (`refresh`) and carries on from where it was. `video_player` reports a rejected
  request as a bare "Source error", so a first failure whose class is expired or unknown (see
  [Failure classes](#failure-classes-and-messages)) triggers the one re-sign (mpv: the first reported failure); a
  refused proxy, a missing network or an undecodable file would fail the same way again and show at once.
* Opens paused at the first frame; `hasFrame` becomes true once the picture widget was built with a known size
  (the poster beneath goes then); until then the backdrop is transparent when `transparentVideo` is set.
* Errors: a failed open publishes `error` with its class and throws `MediaPlaybackException`; a runtime player error
  (`VideoPlayerValue.hasError`) is a failure and stays one. Buffering is not. The class and the sanitized cause are
  written with `debugPrint` as a redacted `raft.media: [error] video_player: open failed class=... cause="..."` line
  (logcat on Android).
* Volume is 0-100 like media_kit (video_player takes 0-1). Toggling a finished clip restarts from 0.
* Leaving the app pauses (`AppLifecycleState.paused`); returning does not resume. `video_player`'s own observer, which
  resumes, is disabled with `allowBackgroundPlayback`.
* No timers of its own (`avoid_unreviewed_idle_work` lint); video_player polls the position every 100 ms only while playing.
* The picture is `VideoPlayer` in an `AspectRatio`, centred (contain) inside the box the card gives it.
* Colour and HDR. Two surfaces, chosen by the caller (`createAttachmentPlayer(hdr: ...)`; see "Streaming and sessions"
  for which player the viewer uses):
  * Inline cards (and any list) use the plugin's texture (`VideoViewType.textureView`). The texture is SDR on every
    platform: Android's ExoPlayer/MediaCodec tone-map HDR to SDR for the texture, and `video_player_avfoundation`
    (2.12.1) declares BT.709 8-bit BGRA output settings, which makes AVFoundation tone-map on iOS and macOS. HDR clips
    therefore look SDR (tone-mapped) in the message list, which is the expected look there. A platform view in a
    scrolling list would break clipping, overlays and scroll sync and cost battery.
  * The full-screen media viewer (`AttachmentPreviewDialog`, opened from the eye button; its fullscreen toggle is the
    same widget tree) shares the card's texture player (SDR, seamless). Only an HDR video, detected from the file's
    colour boxes, gets a player of its own with the native view (`VideoViewType.platformView`): a `SurfaceView` on Android and an
    `AVPlayerLayer` on iOS and macOS. They hand the picture to the system compositor untouched, so HDR (HDR10, HLG,
    Dolby Vision) is shown as HDR on an HDR-capable display. Pending device verification on a real HDR phone, iPhone
    and Mac. The overlay controls (`RaftVideoOverlay`) are Flutter
    widgets drawn above the platform view, which is only on screen while the route rests (a black stage during the
    transitions); the audio-only viewer builds no picture and keeps the texture setting.
  * Android needs no window colour mode (`COLOR_MODE_HDR`) and the runner is unchanged: Android's HDR playback guide
    (developer.android.com/media/grow/hdr-playback) says standard `MediaCodec` playback into a `SurfaceView` displays
    HDR without special handling, and that `TextureView` transcodes HDR to SDR (the reason cards stay SDR). The colour
    mode is for HDR content the app draws itself (UI, bitmaps, GL).
  * Apple: the plugin's native view is a plain `AVPlayerLayer` (a layer-backed `NSView` on macOS) and sets no
    `wantsExtendedDynamicRangeContent`; AVPlayerLayer presents HDR on EDR-capable displays by itself. If a Mac shows
    the viewer as SDR, that flag on the layer is the thing to try (needs a plugin override, not applied). macOS uses the
    shared Dart code, which embeds the view with `UiKitView` (supported since video_player_avfoundation 2.8.0 per its
    changelog); not exercised on a Mac from the Linux host.
  * Windows and Linux (media_kit) are unchanged and ignore the flag.
* Formats are the system's: AVPlayer does not play WebM or MKV, so those show the failure state on iOS and macOS with
  "Download to view" (media_kit played them). Ogg/Vorbis audio did play on macOS (CodexMac, 2026-10-13), so Ogg is not
  assumed unsupported; check per file.

## Failure classes and messages

A failed card or viewer says what failed and offers what helps; it never claims a codec problem for a network
one (Kevin 2026-10-13: mpv could not reach the user's HTTP proxy and the card said "may use a codec this browser
cannot preview"). `MediaFailure` (`platform/media_failure.dart`) is the class (`MediaFailureKind`), the proxy
`host:port` it is attributed to (never credentials) and the sanitized cause. `AttachmentPlayback.failure` carries it
with `error`; `MediaPlaybackException` carries it out of `open`.

| Class | libmpv signal | ExoPlayer / AVPlayer signal | Message | Actions |
| --- | --- | --- | --- | --- |
| proxy unreachable | `tcp: Connection to tcp://<proxy> failed: ...` while a proxy is in use, or a failed TCP connect to the proxy | `Source error` / localized text, then a failed connect to the OS proxy | Cannot reach the proxy {proxy}. Check Network settings, then try again. | Retry, Network settings, Download |
| proxy auth | `HTTP error 407`, or probe status 407 | probe status 407 | The proxy {proxy} needs a username and password. Check Network settings. | Retry, Network settings, Download |
| network | `Connection refused`, `No route to host`, `Failed to resolve hostname`, timeouts, TLS, HTTP 5xx/429 | `UnknownHostException`, `ConnectException`, `ERROR_CODE_IO_NETWORK_*`; `NSURLErrorDomain` -1001/-1003/-1004/-1005/-1009, "Could not connect to the server." | Cannot reach the server. Check your connection and try again. | Retry, Network settings, Download |
| expired / forbidden | `HTTP error 401/403/410` or probe status, after the one re-sign | `Response code: 403`, CoreMedia -12660 or probe status | This link has expired or access was denied. Try again. | Retry (signs again), Download |
| not found | `HTTP error 404` or probe status | `Response code: 404`, `ERROR_CODE_IO_FILE_NOT_FOUND` or probe status | This file is no longer available. | Download |
| unsupported / corrupt | `Failed to recognize file format.`, `Invalid data found...`, no decoder | `PARSING_CONTAINER_*`, `DECODING_FORMAT_*`, `UnrecognizedInputFormatException`, `format_supported=NO_*`; AVFoundation `Cannot Open` / `Cannot Decode` | video: Web's "This video may use a codec this browser cannot preview."; audio: This audio may use a codec this app cannot play. | Download |
| unknown | nothing recognisable | nothing recognisable and the host answers | The media could not be played. | Retry, Download |

Where the backend says nothing about the cause (libmpv at `warn` logs only `Failed to open <url>` for a 403, a 404,
a DNS miss and a refused proxy; ExoPlayer says `Source error`; AVPlayer's text is localized), `MediaDiagnosis`
(`platform/media_probe.dart`) settles it: when a proxy is in use, a plain TCP connect to the proxy (refused, no route
or timeout means proxy unreachable); then one ranged `GET` (`bytes=0-1023`, body cancelled) through the same proxy
decision (`SystemProxy`), classified by status or exception. A host that serves the bytes means the file is what the
player rejected (unsupported), or, for a stream that had started, that the link dropped (network). The proxy is
named only when the player really follows it: libmpv gets the app's decision (`http-proxy`), ExoPlayer and
AVPlayer follow the OS proxy only, so a Settings > Network choice is not named for them. The probe is one request
per failure (it passes the attachment rate-limit governor like every attachment request) and never sends the
signed URL anywhere but the host that serves it.

Actions: Retry drops the failed player (a failed session is never shared) and prepares a new one, which signs the
link again, then plays; Network settings (`settingsPath: ['network']`; from the viewer it closes the viewer first)
is offered for proxy and connection failures; Download is always there. The cause line is always written to the
journal (`raft.media: playback failed class=... proxy=host:port cause="..."` for libmpv) through `sanitizeMediaLog`:
host and port stay, paths, queries and credentials do not.

## Streaming and sessions

Why: 8074 downloaded the whole attachment (up to 50 MB) before the first frame, again for the viewer, again on every
reopen. Now:

| | Inline card | Viewer |
| --- | --- | --- |
| Source | signed URL streamed by the player; prepared once the card has been near the viewport for 250 ms (unchanged: cards flung past start nothing; videos over 24 MB wait for the first tap) | the card's player when one exists, else the same URL |
| First frame | when the player has the first range (`moov` + first samples) | immediately when handed over |
| Download | the card's Download action | the viewer's Download action; both still save to disk through the system picker |

* **Sessions** (`platform/attachment_player_sessions.dart`, `AttachmentMedia.playerSessions`): one player per
  attachment version, keyed `id|version`. Holders (a card, a viewer) `acquire` and `release`; the player is disposed the
  moment the last holder is gone, never by a widget's `dispose` alone, and nothing lingers (a viewer closed with no card
  frees its decoder at once). A viewer outlives a card that scrolled away; a card outlives the viewer it opened. At most
  2 players are live: a third evicts the least recently used one that no viewer holds and that is not playing. An
  identity change (`attachmentImageScope`) or a revoked channel drops everything. The sessions also remember, per
  attachment, which cards prepared it (`prepared`), where it stopped (`resumeAt`) and a small still picture (`stills`, 24
  at most, a card's size each).
* **Handoff.** Tapping the eye neither pauses nor re-creates anything. The viewer acquires the card's session (same
  controller / `Player`): position, buffer, volume and audio continue and no request is made. The card does not pause
  while a viewer holds the player (the covered-route and scrolled-away pauses are skipped); on close it continues, playing
  or paused, from the position the viewer reached.
* **HDR exception (Android, iOS, macOS).** The native video view (`SurfaceView`, `AVPlayerLayer`) is the only way to get
  HDR output and a `VideoPlayerController`'s `viewType` is fixed at creation, so an HDR video cannot share the card's
  texture player. The viewer starts on the shared texture player (seamless), reads the file's colour boxes with one to
  three ranged GETs (`mp4_hdr_probe.dart`: `colr`/`nclx` transfer 16 = PQ or 18 = HLG, `dvcC`/`dvvC` = Dolby Vision;
  never the codec or extension: HEVC is mostly SDR) and, if HDR, opens a second player with `viewType: platformView`
  at the card's position (streaming reads only the rest), pauses the shared one and shows the native view; on the first
  moment of any pop it releases the native view, seeks the shared player to the native position and the card carries on
  from there. A server that ignores ranges, a non-MP4/MOV file or an unreadable header give no verdict: SDR, shared
  texture. Verdicts are cached per attachment in the sessions. SDR clips never create a second player.
  Measured on the Android emulator (API 36) with the local range server, an HLG-tagged 5.4 MB / 19 s clip and a 16 MB
  / 287 s clip handed over at 116 s (suite runs of 2026-10-13, `PS-REPORT hdr-handoff-*` in `suite.log`): the eye tap
  to the native view on screen takes 479-533 ms; from the HDR verdict to the native player playing 102-154 ms. Requests:
  the colour probe (one ranged GET of 64 KB; the long clip's `moov` sits behind `mdat` and needed a second, 250 KB),
  then the native player's own, which do **not** start at the card's position: ExoPlayer opens one open-ended GET from
  byte 0 (the head and `moov`), and for the long clip a second one at the position (`bytes=6417379-`, 40 % of the
  file). `video_player` has no start-position option, so the seek happens after prepare. Bytes the server sent since the
  eye tap (unthrottled loopback, the first GET is only cancelled when the second arrives): 5.48 MB for the short clip, 26.7
  MB for the long one. The exit of the HDR path still shows about 230 ms of a stale frame from the native view before the
  fade (visible in `hdr-close-*.mp4`; the SDR exit is clean, see the close recordings); the native view is removed from
  the tree and its player disposed at the first moment of the pop, the remaining lag is the platform view's teardown.
  A fully seamless HDR handoff needs the native ExoPlayer/AVPlayer kept and only its output `Surface` / `AVPlayerLayer`
  swapped; `video_player` has no such API, so it would need a plugin extension (out of scope).
* **Memory.** A decoder holds tens of megabytes of frame buffers (a 2160x3840 clip: ~31.6 MB each, 9 of them were seen
  left behind). A card therefore releases its player (`InlineMediaLoader.releasePlayer`) and keeps a downscaled still
  (`RepaintBoundary.toImage`, 1.5x of the card) when playback **ends**; when it is **scrolled out** of view, its page is
  **hidden** (`TickerMode` off) or the app **backgrounded**, after a 3 s grace (coming back inside it cancels); and when
  the soft cap of **2 live players** is exceeded (it shows its still and waits for a tap; playing players and the one a viewer holds are never evicted, so the count can go above 2 when all of them are). A card does **not** prepare a
  released player again by itself, and a card built again for an attachment already prepared this session (a list drops
  rows far from the viewport) shows the session's still and prepares on a tap, at the position it stopped at
  (`resumeAt`): a new stream every time a clip scrolled back into view would spend the server's attachment limit (the
  `rate_limit_scroll_budget_test` counts 18 stream opens for 17 clips over 30 s of fast scrolling; with re-preparing on
  every return it was 101, and 28 requests were refused with 429 on server-streamed storage). Never while the viewer
  holds the player. Measured on the emulator (4K HEVC clip, `memory` scenario, `dumpsys meminfo` and `ps`): the media
  codec processes' RSS 89.8 MB (idle card) -> 202.7 MB (playing) -> 89.3 MB (after the end) and 89.2 MB (after the page
  was hidden); the app's Java heap in use 4.5 -> 43.4 -> 4.6 MB. The app's PSS stays about where playback left it
  (322.6 -> 351.0 -> 351.8 MB: the allocator does not hand pages back at once) and `Graphics` reads 0 on the emulator, so
  the frame-buffer saving Kevin measured on a phone (9 x 31.6 MB) shows here as the codec processes' RSS.
* **Buffering.** `AttachmentPlayback.buffering` (ExoPlayer/AVPlayer buffering, mpv `buffering`) draws a spinner over
  the picture. The viewer no longer shows a download panel for video: while the player opens, the black stage
  shows a centred spinner (Web's `<video>` has no custom loading UI), a failure shows `RaftLoadError(onDark: true)` in
  light text, and the close control stays in the header. The panel remains for PDF and for the audio viewer, which play the
  cached file (`AttachmentPreviewFiles.loadCached`, Settings > Storage) on the light stage.
* **Looping.** A video of 60 s or less (`kLoopingVideoMaxDuration`, one constant in `attachment_player.dart`) repeats by
  itself, in the card and in the viewer: `setLooping(true)` once ExoPlayer/AVPlayer know the length, mpv's `loop-file=inf`
  when media_kit reports it (`no` again on every open). A longer clip stops at the end as before, and so does audio. A
  looping clip never reaches the "playback ended" state, so a card whose short clip is playing does not release its player
  at the end; it still does when scrolled out, hidden or backgrounded.
* **Taps are never dropped.** A tap on a card whose player is not ready (idle, loading, released) is queued and plays as
  soon as the player is ready (`playRequested`); the picture is interactive in every state but failed.
* **Re-opening.** `video_player_android` (ExoPlayer, Media3 1.9) has no disk cache option and `video_player` exposes no
  cache at all; AVPlayer buffers in memory. A viewer opened from its card needs no request (it takes the card's player).
  A viewer opened with no card, or a card prepared again by a tap after its player was released, streams again and
  reads only what is played: ExoPlayer's read-ahead is about 50 s of media, so on a long clip that is a fraction of the
  file (the suite's 16 MB / 287 s clip: about 2.5 MB), a clip shorter than the read-ahead is fetched whole but streamed.
  Without the video cache (below) that was the whole story; the cache makes the second open free.
* **Rate limit** (`packages/raft_client/lib/src/server_rate_limits.dart`: every request under `/api/attachments`
  counts, 120 per minute per user). The player's own requests do not pass through `AttachmentHttp.governor`. A
  presigned storage URL on another host is not counted at all. When the Raft server streams the bytes itself (a URL path
  under `/api/attachments`), `attachmentStreamSource` admits the first request through the governor (paced, or refused
  after the 30 s `maxWait`, which the card shows as "Download to view") and the usual one to three requests of a
  progressive MP4 stay inside the governor's 25 % headroom. ExoPlayer opens one open-ended `GET` (plus one for a `moov`
  at the end of the file); AVPlayer makes more, short range requests. Seeks add one request each. A column of auto-loading
  cards is bounded by the 250 ms settle rule, the 24 MB auto-load size and the soft cap of 2 live players (playing or viewer-held players are exempt).
* **Proxy.** mpv (Windows/Linux) gets `http-proxy` from the app's decision at run time; ExoPlayer and AVPlayer follow the
  OS proxy only, so Settings > Network *Manual*/*No proxy* do not apply to streamed media on Android/iOS/macOS (see
  [system proxy](system-proxy.md)).

## Video cache

Streamed video is kept on disk so that opening it again costs no download (`platform/video_cache.dart`,
`platform/video_cache_proxy.dart`). On by default; `kVideoCacheEnabled` is the kill switch (`false`: players get the
signed URL directly, as before).

* **How.** The player is not given the signed URL but `http://127.0.0.1:<port>/<token>/<name>.mp4`, served by a loopback
  `dart:io` server (`VideoCacheProxy`) that reads like the file itself (200, 206, HEAD, 416, `Accept-Ranges`) while it
  fetches the bytes from the signed URL in 1 MiB chunks (windows of up to 4 chunks per upstream request, two chunks
  requested ahead of the one being read) and keeps each chunk on disk. Every player works the same way (ExoPlayer,
  AVPlayer, mpv); no platform cache code. Android's network security config already allows cleartext to `127.0.0.1`
  only; Apple's ATS needs no exception for the IP literal (verified on macOS and the iOS simulator).
* **Keys and accounts.** Chunks are keyed by the attachment id, not by the URL, so a re-signed URL keeps its cache. The
  cache is per account: `<app cache>/raft-video/<hash of origin and user id>/`, one proxy (and one random token) per
  account, started lazily by the first video that account plays (nothing runs or is scanned at app start). A source
  without an account is never cached. Sign-out, an ended session and an account switch (`AppRoot.logout`) delete the
  account's folder; the start-up housekeeping removes folders of accounts with no saved session.
* **Limits.** 500 MB per account (`kVideoCacheMaxBytes`), least recently used chunk first (pinned while being read).
  Settings > Storage > Video cache shows the signed-in account's size (live) and has its own Clear.
* **Safety.** Bound to loopback; a request without the process's random token path learns nothing (404). The signed URL
  and headers live in memory only. A chunk reaches disk complete (temporary file, then rename). An upstream 4xx
  (an expired signature above all) reaches the player as the same status so its own re-sign logic runs; a transient
  failure (connection drop, timeout, 408/429/5xx) is retried up to 3 times with growing pauses, resuming at the first
  missing byte; after bytes went out a failure cuts the connection.
* **The disk is optional.** A chunk that cannot be written (disk full, folder gone, no permission) is served from
  memory anyway; after 3 failures in a row the proxy stops writing until the cache is cleared or the app restarts.
  A folder that cannot be created only means nothing is stored. A file that cannot be deleted (held open on Windows) is
  retried, kept out of the index and counted in the size until it goes.
* **Desktop.** `integration_test/video_cache_linux_test.dart` runs the same on mpv (Linux under `xvfb-run`, Windows): a
  clip played and sought once is read from the range server once (through the proxy only, `User-Agent: RaftVideoCache/1`)
  and two reopens with a new player and a newly signed URL read nothing; purging the account deletes its folder.
  The same file checks the loop (a 19 s clip wraps twice while playing and reads nothing more; a 287 s clip stops at its
  end and stays), which needs `long.mp4` in the media directory too.
* **Not covered.** Audio (`hasPicture: false` / `video: false` players) streams as before. Poster frames and thumbnails read
  the signed URL directly (they need the first frame only). Downloads and the audio/PDF previews use the attachment disk
  cache as before. Upstream requests carry `User-Agent: RaftVideoCache/1`, so a server log (or the interaction suite's
  counters) tells them from the app's own downloads.

## Media browser

One route pages through the images (and, behind a flag, the videos) of the message a card belongs to
(`features/media_browser.dart`, `MediaItem` in `media_items.dart`; visuals in `raft_ui/src/media_browser.dart`). Audio, PDF,
documents and everything else still open in `AttachmentPreviewDialog`. A message with one image opens the browser
without counter and strip.

* **Route.** `RaftMediaBrowserRoute` (a `PageRoute`, transparent while it fades; opaque once the open transition ends so
  the chat below stops painting; see-through again while a drag-to-dismiss runs). It replaces the dialog route and the
  Material page of the old image viewer on every layout; reduced motion (`MediaQuery.disableAnimations`) shortens the
  fade to 80 ms and leaves the Hero out. The route's first frame is built off stage while the Hero measures its end
  (framework behaviour), so content shows one frame after the push.
* **Hero.** The tapped card's picture flies to the stage and back (`RaftMediaHero`, tag `media-<attachmentId>`). The
  flight is a straight line (`createRectTween`, not Material's arc) on `RaftMediaMotionTokens`: open 300 ms with the
  emphasized-decelerate curve, close 240 ms with the standard curve, reduced motion 80 ms and no Hero. The shuttle animates
  the crop, never stretches: it starts as exactly what the card paints (the card's own fit, cover for a tile and contain
  for a lone picture, and the bitmap size from the resolved image, never server dimensions), ends as the stage picture, the
  corners round off on the same progress. The flight's end follows the destination's live bounds. The stage picture is ONE
  Hero element from the thumbnail stand-in to the loaded original (same element, the image provider changes, the original
  takes over once decoded), and its box comes from the thumbnail's shape when the attachment's width / height are missing
  or disagree with it (4 % tolerance), so nothing moves after the landing. The card wears its Hero through `HeroMode`
  (always mounted, switched on only for the tapped card while its browser is up: the same message can be on screen twice,
  e.g. a thread's parent, and duplicate tags assert; the card's picture is not rebuilt for the flight). The phone shell
  stages the rest: the scrim follows the picture on the same curve (`RaftMediaBrowserRoute.scrim`), the chrome fades in
  after 70 % of the open and is gone as a close starts, the stage fades over the first 40 % when there is no card to fly
  from. Closing from a zoom starts at the zoomed bounds and shrinks to the card in one move. Closing on another page than
  the opener fades instead of flying.
* **Phone (compact width, or a touch device with a short side under 600 dp: a phone held sideways).** A black stage under
  the status bar and the gesture bar; two chrome layers fade together in 160 ms. Top bar: Back, filename and the
  `sender · time` sub-line, the `n / N` counter, Share (when the platform has a share sheet) and More (Save to Photos /
  Gallery, Download file, Show in message). Bottom band: the message text as a two-line caption (tap expands; only when
  the message has text) and the 44 dp strip. Landscape drops the bottom band. The stage keeps symmetrical room for the
  bands (`RaftLightboxStageInset`), so toggling the chrome never moves the picture. A tap toggles the chrome once the
  300 ms (`kDoubleTapTimeout`) double-tap window has passed without a second tap (a double tap zooms); anywhere on the stage counts, also on
  the thumbnail stand-in (same zoom surface and controller as the original, so a zoom carries over) and on the bands'
  gradient backdrop (only the caption, strip and buttons take their own taps). Hiding the chrome is **immersive mode**: only the app's own chrome goes (the system status and navigation bars are
  never touched) and the picture re-fits to the room between the system bars; the next tap restores everything. The
  first zoom gesture (pinch, double tap to a fixed 2x) enters immersive and zooming back to fit does not leave it. A
  screen reader keeps the chrome on and a tap toggles nothing. A tap on the empty stage does not close (Web's empty-stage click is desktop only). Long press keeps
  the Save / Share menu. System bar icons are light over the black stage, bars transparent (edge to edge).
* **Drag down to dismiss** (touch, zoom at fit, one finger): `RaftMediaDismissible` follows the finger, scales to 0.82 and
  fades the scrim and the chrome (gone within 40 dp). Release past 120 dp or faster than 700 dp/s pops (Hero or fade from
  where it is), otherwise it springs back in 200 ms. Zoomed, a mouse, a second finger or a horizontal intent leave it
  alone; reduced motion drops the scaling.
* **Desktop (wide).** Web's frame: header with the kind glyph, bold filename, the `sender · time · WxH · size` line, the
  counter and Download; side arrows are not drawn (owner decision 2026-10-13); a click on the empty stage closes; page
  changes cut. The strip (`RaftMediaStrip`) is a lazily built, scrollable band the stage keeps clear of; video thumbnails
  carry a play badge with the duration.
* **Keyboard** (`RaftPlatformKeys.command`: Cmd on macOS / iOS, Ctrl elsewhere). Esc, Ctrl+W and Cmd+W close on every
  platform (Web); Left / Right page (not while zoomed), Home / End jump; `+`, `=`, `-`, Cmd/Ctrl + `=` / `-` zoom,
  `0` and Cmd/Ctrl + `0` fit.
* **Accessibility.** Pages read "Image 3 of 9, name, sender, time" and offer Zoom in / Zoom out / Fit to screen actions;
  strip items are selected-state buttons; chrome targets are 44 dp.
* **Video pages (flag).** `--dart-define=RAFT_MEDIA_BROWSER_VIDEO=true` (`MediaBrowserFlags.video`, default off) makes the
  videos of the message pages too, in message order, and a video card's eye opens the browser instead of
  `AttachmentPreviewDialog` (audio, PDF and documents still use the dialog; with the flag off nothing changes). Each video
  page has a `MediaVideoStage` (`media_video_page.dart`) that holds the attachment's session as a *viewer*:
  * **Opened from a card that has a player** (playing or paused): the stage acquires that session at once - same
    `Player`, position, buffer and volume, no request, no pause - and the page shows it playing or paused as it is.
  * **Paged onto a video** (swipe, strip, keys): nothing is created while the page is passed. After the page has rested
    250 ms the stage prepares a player, which opens paused at the first frame and never plays by itself (a swipe through a
    gallery must not play audio, spend the 120/min attachment budget or start decoders). Videos over 24 MB wait for the
    first Play, like cards; a Play before the player is ready is queued.
  * **Leaving a video page** (swipe, arrow, strip, back) pauses it at once, stores where it stopped (`resumeAt`) and keeps
    the hold for 3 s: coming back inside that time shows the same player at the same place with no request; after it the
    hold is released - a card that holds the session keeps it (paused), with no card the decoder is freed. At most two
    stages hold a viewer session (the current page and the one just left), so the soft cap of two is never exceeded by the
    browser itself. Pages whose stage never rested never created a player.
  * **Closing** releases every hold at once; a card holding the session continues (playing if it was) from where the
    viewer left it, with no seek back. A browser opened with no card frees the decoder when it closes.
  * **HDR (Android, iOS, macOS)** keeps the exception of the dialog: the shared texture player first, the colour probe
    (cached per attachment) decides, the native view is created only while the page rests (route settled, no swipe, no
    drag), and the first moment of any horizontal swipe, drag-to-dismiss or pop removes it and hands the position back to
    the shared player.
  * **Failures** are the seven classes of [Failure classes and messages](#failure-classes-and-messages) with their actions
    (Retry signs again, Network settings closes the browser first, Download original). A failed page is not retried by
    paging: leaving and coming back shows the failure again with no request; only Retry opens (exactly one) new player.
  * **Controls.** The phone page fills the stage; a tap toggles the chrome, the control bar and the centre Play together (paused or playing) and never
    plays; they fade with the chrome. A playing video under visible chrome enters immersive by itself after 3 s without an
    interaction (any finger on the viewer postpones it); never while paused, scrubbing, with a menu open or with a screen
    reader. The Play button and the bar play and seek. The control bar keeps clear of the strip (`RaftMediaChromeInsets`). Keyboard: Space, Shift+Left/Right (5 s),
    M. The app going to the background pauses and does not resume.
  The page code is new rather than a refactor of the dialog's (the dialog keeps its own video path while the flag is off);
  the two will share one stage when the flag is removed.
* **Not here yet:** the desktop comments aside, Cmd/Ctrl+S, seek by double tap, the live-texture Hero from a playing card
  (the video card does not fly), double-tap zoom hints, the F full-screen key on video pages.

## Video cards

All platforms use the same `RaftVideoPosterCard` timeline presentation. This is an intentional difference from Web's
inline player, recorded in `docs/parity.md` (owner decision 2026-10-17).

* **Timeline card.** The poster follows the video's declared or remembered shape (otherwise 16:9), at most 448 dp
  wide and 60 % of the screen height. There is a central play affordance and a duration when known. The card owns
  no `AttachmentPlayer` or `PlayerSessions` hold, including for small files. Clicking anywhere opens the existing
  media browser and starts that video. Images and videos of the same message remain pages in message order;
  the old `RAFT_MEDIA_BROWSER_VIDEO` gate is removed. Closing the viewer releases playback rather than continuing
  inside the timeline. The poster can still read original video bytes through the bounded first-frame fallback below.
* **Poster source.** `VideoCardPoster` (`features/video_card_poster.dart`): the server `thumbnail` rendition first (a
  message with a `thumbnailUrl`, or one already stored); a message with none (CLI uploads have neither a thumbnail nor
  `width` / `height`) falls back to the first frame of the video, read through `VideoFrameProbe`
  (`platform/video_frame_probe.dart`):
  * Android: `NativeVideoFrameBridge.kt`, channel `app.raft/video-frame`. A `MediaDataSource` of 256 KB `Range` blocks over
    `HttpURLConnection` (OS proxy respected) feeding `MediaMetadataRetriever`: frame 0 (`OPTION_CLOSEST_SYNC`, then 100 ms
    when it is black), `METADATA_KEY_VIDEO_WIDTH/HEIGHT/ROTATION/DURATION`. The plain `setDataSource(url, headers)` was
    measured and rejected: it sends range-less GETs and reads the whole file (twice with the moov at the end), cannot be
    byte-capped or cancelled. A `maxBytes` cap, a timeout and `cancel` end the read; 401 / 403 / 410 report `expired`.
  * iOS and macOS: `RaftVideoFrame` (same code in `ios/Runner/RaftSharingBridge.swift` and
    `macos/Runner/MainFlutterWindow.swift`): `AVURLAsset` + `AVAssetImageGenerator` (`appliesPreferredTrackTransform`,
    `maximumSize`), size = the track's natural size x preferred transform, rotation from the transform, duration. AVFoundation
    does its own ranged reads; the budget there is the timeout (no byte cap).
  * Windows and Linux: `MpvVideoFrameProbe` (`platform/video_frame_probe_mpv.dart`): a one-off, muted, paused libmpv player.
  * The signed URL is the one the app already signs for playback (`attachmentStreamSource`, `disposition=inline`); an
    `expired` answer signs once more and retries once.
* **Budget.** Only a card that has been within 160 dp of the viewport for 250 ms starts a read; the read is cancelled when the
  card leaves 480 dp of it. `VideoFrameScheduler.shared` runs two at a time app-wide, newest first. A failure puts the
  attachment in `PlayerSessions.frameFailed` for the session (placeholder with the play button, no retry loop); Clear cache
  forgets it. Nothing is read for a card whose poster (or a stored frame) is available.
* **Cache.** The frame is the `poster-frame` rendition of the attachment (a JPEG, longest edge 960 px) and the shape a
  `video-shape` entry (`{w, h, r, d}`), both in the private attachments namespace of `AttachmentDiskCache` (scoped
  account / server / channel, counted in Settings > Storage, removed by Clear cache, sign-out and channel revocation).
  The server thumbnail has its own rendition and is looked at first, so one added later wins. The shape is also kept in
  `PlayerSessions.shapes`, so a card built again in the session has its final box in the first frame; after a restart it is
  read from disk right after the first frame of the card (one box change at most, 16:9 -> real).
* **Image cards use the same shape rule.** A picture whose message has no `width` / `height` is laid out at the reserved 4:3
  box until its preview decodes; the decoded size (no extra download) is the shape: `AttachmentView` remembers it in
  `PlayerSessions.shapes` and an `image-shape` entry of the private cache, `ShapedImageGallery` re-lays the message's single
  image out once (Web's 416 x 288 reservation, so the card has the picture's shape and no letterbox), and the second view or a
  restart has the final box in the first frame. Uploads send the file part's `Content-Type` (the browser type of the picked
  file, as Web's `FormData` does); Web sends no width or height itself.
* **Layout.** A message with `width` / `height` has its final box at once; without them the card is 16:9 until the read
  returns and then changes once (the timeline treats it like any row whose content settles).

## Verification record

* Viewer surface tests (`viewer_video_surface_test`, `video_player_attachment_player_test`, `player_sessions_test`,
  `mp4_hdr_probe_test`): on Android, iOS and macOS a card and its viewer share one `textureView` player on a streamed
  network source; an HDR video gets a second `platformView` player; closing the viewer frees the players.
* Android emulator (API 36, x86_64, isolated `app.raft.raft_flutter.linkperf`), 2026-10-13, with
  `integration_test/video_parity_main.dart` (`VP_LOC=/s/lab`, then open the channel; samples served by
  `tool/video-parity-range-server`): H.264 720p landscape and portrait, 1080p HEVC Main and Kevin's 4K HEVC Main 8-bit
  bt709 30 fps clip show the first frame, play, advance and pause; the WAV plays; an undecodable file shows the
  failure state. The Dolby Vision 8.4 / HLG 4K clip fails on the emulator only:
  `MediaCodecVideoRenderer error ... video/dolby-vision dvhe.08.07 3840x2160 BT2020 HLG 10bit
  format_supported=NO_EXCEEDS_CAPABILITIES` (the emulator's goldfish HEVC decoder has no 4K 10-bit profile); that needs a
  phone.
* Linux, failure classes: `integration_test/media_failure_linux_test.dart` (bundled libmpv, local server on a LAN
  address, local refusing proxy and 407 proxy): valid file, 403 (one re-sign), 401, 410, 404, 500, corrupt video and
  audio, refused port, unresolvable name, manual proxy refused / 407 / unreachable address each land in their class.
  `xvfb-run -a tool/flutter test integration_test/media_failure_linux_test.dart -d linux
  --dart-define=MEDIA_FAILURE_HOST=<LAN address>`.
* Android, failure classes (API 34 x86_64 emulator, isolated `app.raft.raft_flutter.linkperf`):
  `integration_test/media_failure_android_main.dart` drives `VideoPlayerAttachmentPlayer` against a host server
  through 10.0.2.2. ExoPlayer's text is only `PlatformException(VideoError, "Video player had error
  androidx.media3.exoplayer.ExoPlaybackException: Source error")` for 403, 404, 410, 500, a corrupt file and a refused
  port alike; the probe then gives expired (after the one re-sign), not found, expired, network, unsupported and
  network (`SocketException: Connection refused`). A manual OS proxy (`settings put global http_proxy`) was not taken
  by ExoPlayer on that emulator (requests reached the server directly), so the Android proxy classes are
  unit-tested only.
* Linux: `tool/flutter build linux --debug` builds; `native_player_test` passes under Xvfb (`xvfb-run -a tool/flutter
  test integration_test/native_player_test.dart -d linux --dart-define=RAFT_TEST_REPORT=<dir>`), including a new streaming
  test: mpv reads a loopback `http` URL with ranges, and signs again after a 403 (the first failure of a streamed source).
* Android emulator suite (2026-10-13, API 36 x86_64, `.linkperf`): all 18 scenarios of the interaction suite pass on
  this branch; on the previous build the centre-play scenario fails (the suite is the reproduction).
* iOS and macOS cannot be built on the Linux development host; see the hand-off checklist in the change description.

## What 8074 got wrong (root causes)

* **Dead centre play button.** `RaftVideoControlBar` is 112 px tall and anchored to the bottom of the picture; its
  hover `MouseRegion` was hit-opaque. A phone card is 16:9 at `screen width - 112` (about 300 x 170), so the bar's box
  reached past the middle and swallowed the tap (no recognizer in it; hit-testing stops at the first opaque child, so
  the picture's `GestureDetector` beneath never saw it). Cards of the maximum 448 px (252 px tall), the viewer and every
  desktop card were not affected, and the fake-player widget tests tapped such a card. Fixed with a translucent region
  (`video_centre_tap_test`; the interaction suite reproduces it on the unfixed build). A tap while the player is still
  being prepared used to be dropped as well; it is queued now.
* **Close judder.** The viewer always used the platform view (`SurfaceView`), which does not move or fade with Flutter
  content, so during the page's exit it lagged, showed a stale frame and then vanished before the fade. SDR videos now
  share the card's texture player (no platform view at all); an HDR video's native view is only on screen while the
  route rests and is removed at the first moment of any pop (route animation `reverse`, back gesture in progress).
  Recordings of the exit (system animations on, button / back key / back swipe) on the 8074 build and on this change are
  kept with the hand-off (`viewer-close-*.mp4`); frame sheets: before = video lag, stale frame, then black; after = the
  page and its picture fade together.
* **Download on every open.** Cards downloaded a private copy, the viewer downloaded its own, deleting it on close.
  Now neither downloads: see above.

## Interaction suite (Android emulator)

`apps/raft_flutter/integration_test/player_interactions_test.dart` drives the production app (fixture workspace, no
login) on a real emulator with the real `video_player`/ExoPlayer, real taps through the gesture arena, real route
transitions and a real HTTP server that counts what it sends. The existing widget tests use a fake player and cannot
see any of this: 8074's dead centre play button passed every widget test (the fake never sat under a hit-opaque control
bar) and only the emulator reproduced it.

```sh
# one-off: the media (faststart copies; moov-at-end originals also work), see tool/player-interactions --help
tool/player-interactions --serial emulator-5600 --media /tmp/player-streaming/media --out /tmp/player-streaming/run --build
```

The runner starts `tool/video-parity-range-server` (S3-like ranges, `?rate=` throttle, `/__stats`, `/__fail`), `adb
reverse`s it, builds the profile APK of the isolated app `app.raft.raft_flutter.linkperf` (never the real app), drives
it with `flutter drive` and answers the test's host commands: Android back key, a back swipe from the left edge,
screenshots, `screenrecord` of the close animation, `dumpsys meminfo`, the system save dialog. Output in `--out`:
`suite.log` (test output and logcat), `server.log`, `host.log`, recordings and screenshots. `--only <part of a
scenario name>` builds a subset in; `--define NAME=value` passes a `--dart-define` (`VP_BACKGROUND=true` enables the background scenario, which sends the app to the background with the host command `background:<seconds>`); `--no-host` skips the host-driven steps. Start your own emulator on a free port
(`-read-only` when the AVD is shared) and never point it at a phone with the real app.

`--media` must hold every file the suite uses (`REQUIRED_MEDIA` in the runner: the clips and `photo1..12.jpg`). A full run
stops before building when one is missing, a `--only` run warns; the first scenario of a full run reports
`media-incomplete` and every `launch` fails naming the missing files. Before this check a media directory without `landscape.mp4` and the photos made
`browser R3+R4` fail on a 404 from the image loader, deep in the app.

Scenarios are isolated from each other. `scenario(...)` starts each one from a clean slate (`startScenario`: no guarded
call of an earlier scenario in flight, no app tree, no live player, the host command `clean` (no recording, no system
dialog, the app in front), server counters/failures/commands cleared) and runs the body in a zone with a
`ScenarioToken` that is cancelled when the test ends, however it ends (`addTearDown`). A failure that surfaces as an
uncaught async error ends the test at once but leaves its body running; `until`, `lab.host`, `lab.hostQuiet` and the
server calls park such a leftover body at its next call instead of letting it pump frames into the next scenario ("Guarded
function conflict" for every scenario after it). The tear-down of a scenario also waits until the leftover body has let go of the binding (the framework pumps at the
start of the next test, before any of its code runs). A scenario that runs longer than 4 minutes fails and is cancelled.
The runner's watchdog brings the app back to the front when it has been away for 6 s with no host command running (Back on
the last route sends it away and its frames stop, so the scenario could not even time out); the scenario then fails on its
own timeout. Do not add a test that never pumps a widget in front of the scenarios: on the emulator it made the Android back key
leave the app in `viewer: Android back key returns` (the same suite passed without it).

Scenarios (`PS-REPORT` lines in `suite.log` carry the measured numbers):

| Scenario | What it asserts |
| --- | --- |
| centre play | tap the big button on a ready phone-sized card: playing, position advances; tap the seek rail: lands past 60 %; the bar button pauses |
| tap while preparing | two taps on an idle 41 MB card (the second during loading): plays, not toggled off |
| streamed, not downloaded | 41 MB clip served at 2 MB/s: the position advances with fewer than 60 % of the bytes sent; no request from the Dart client (`User-Agent: Dart/`), the native player reads the URL |
| handoff | card playing, eye: viewer position continuous (no jump back), still playing, no platform view, one native player, **no new request**; close: the card carries on from the viewer's position |
| close button / back key / back swipe | each closes the viewer, no native view left, the card still there; recordings of the exit |
| cancelled open | eye and an immediate back: the card keeps playing, one player |
| reopen | open and close the viewer twice on a 16 MB / 287 s clip: zero new requests, under 35 % of the file read |
| HDR | an HLG-tagged clip: native view at the card's position, exit without a native view on the first frames of the pop, card resumes; handoff time and requested ranges reported |
| background | an inline card plays, the app goes to the background for 4 s (longer than the card's 3 s release grace) and returns: no crash (the still is not photographed from the background, flutter/flutter#192365), the decoder is released, the card is not playing, a tap plays on from the position it had |
| video cache: reopen | a clip viewed once (play, seek on the rail with a real tap) is read through the proxy exactly once (proxy bytes = file size, the chunks on disk); closing with the Back key and opening it twice more (a new player each time, rail seeks) sends the range server no further request or byte; the opens and closes are recorded |
| video loop: short / long | the 19 s clip, played in the viewer, wraps from its end back to the start twice while still playing and reads nothing more from the server; the 287 s clip, sought to 98.5 %, stops at its end and is still there 5 s later; recorded |
| video cache: Settings, log-out | after one view, Settings > Storage (real taps) reads `Video cache: <size>` equal to the bytes on disk; Clear (a real tap) reads `0 B` and empties the folder; in another run, Settings > Account > Log out deletes the account's cache folder; recorded / screenshots |
| Download | system save dialog, whole file written to Downloads, size matches |
| expired URL | the host answers 403 once: signed again once, plays |
| undecodable | "Download to view" |
| audio | tap plays; streamed |
| viewer stage | connecting, buffering and failed on the black stage in brutal-light, elegant-light and elegant-dark, screenshots |
| memory | the 4K clip played to its end frees the player, and so does hiding its page; `dumpsys meminfo` before and after |
| browser (flag on, `--only browser`) | R1+R2: opened from a playing card (a message with two videos and an image): position continuous, still playing, no platform view, no new request, no extra decoder; paging to the image pauses (position frozen), back inside 3 s: same player, paused at the same place, no request; after the grace the browser holds nothing |
| | R3+R4: no card holds a player (covered cards released theirs): quick swipes past two videos (pages on screen 61-184 ms) open no stream and create no player; resting prepares exactly one stream after the 250 ms rest, paused; away and back inside the grace: no request; after the grace the decoder is freed (`mediaprocs_rss` 44.7 -> 50.9 -> 44.4 MB) |
| | R5 / R7: close and drag-dismiss from the playing video hand the player back to the card at the viewer position (no seek back over 500 ms, no request); a short slow drag never pauses (recordings) |
| | R6: paging to another video then closing: the opened card stays paused where it was left, the visible video's card takes over playing, no request; R6b: with no card the decoder is freed at close |
| | R8: HDR clip: no native view while the page arrives, native view after the rest, gone at the first frames of a drag and of a pop, back at rest, the colour probe runs once |
| | R9: one 403 signs again once and plays; an undecodable page shows its class (unsupported) and re-entry makes no request; a network failure: re-entry no request, Retry makes one |
| | R10: 12 items (6 videos) rested on 450 ms each: one player per video, no refusal; R11: 12 images: neighbours (current +- 1) are fetched as before, never further; R12: 12/12 swipes page, a drag on the seek rail seeks and does not page; R13: `dumpsys audio` shows one started player while playing and none after paging off |
| | Not automatable: R14 (background the app with the browser open): the app dies with SIGSEGV in the raster thread when sent to the background while any video plays, on a host-GPU and on a SwiftShader emulator, also for a plain inline card (`background R14c`), so it is independent of the browser; the scenarios exist but only run with `--dart-define=VP_BACKGROUND=true`; the pause-on-background rule is covered by `media_browser_video_test` |

### Checklist for player changes

Run before merging anything under `platform/*player*`, `platform/attachment_stream.dart`,
`features/inline_attachment_media.dart`, `features/attachment_preview_dialog.dart` or `raft_ui` video controls:

1. Unit and widget tests: `inline_attachment_media_test`, `attachment_preview_test`, `video_player_attachment_player_test`,
   `viewer_video_surface_test`, `player_sessions_test`, `mp4_hdr_probe_test`, `attachment_stream_test`,
   `attachment_player_fit_test`, `media_controls_guard_test`, `tool/raft-lints`, `proxy_hook_guard_test`, raft_ui
   `video_viewer_test`, `video_idle_hide_test`, `video_centre_tap_test`, and the `rate_limit_*` tests.
2. `tool/flutter analyze` and `python3 tool/ds-audit --check`.
3. **The interaction suite above on an Android emulator** (real taps, route transitions, server byte counts). A change
   that only passes with a fake player is not verified. Keep the recordings of the viewer close (button, back key, back
   swipe) and the suite log with the change.
4. `tool/flutter build linux` (media_kit streaming compiles) and, with Xvfb, `integration_test/native_player_test.dart`.
5. **The attachment open smoke** (`tool/attachment-open-smoke/run`, below): every attachment kind from every entry point on
   an Android emulator and on Linux. Run it before merging anything under `features/attachment_*`,
   `features/inline_attachment_media.dart`, `platform/attachment_*`, `data/attachment_*` or the workspace controller's
   attachment URL code, and fix every FAIL it reports.
6. iOS/macOS cannot be built on the Linux host: say so in the hand-off and list what a Mac must check (handoff, native
   view HDR switch, back swipe, memory).

### Attachment open smoke

`tool/attachment-open-smoke/run --platform android --serial <your emulator> --out <dir> --build` (or `--platform linux`)
runs `integration_test/attachment_open_smoke_test.dart` against the production app and a fixture server that behaves like
Raft's storage and API: presigned storage URLs, the server streaming the bytes itself (token in the query), a 302 to
storage, thumbnails (ok, missing, expired), a first signature that is already expired, and range reads. Cases: jpg, png,
webp, gif, heic, SVG (rasterised thumbnail and without), PDF (also 30 MB), text, Markdown (also Chinese and two real
report.md files), CSV, XLSX, code, JSON, HTML (WebView on Android, close and reopen), m4a, mp3, wav, ogg, H.264, HEVC,
WebM, a 30 MB clip, zip, unknown binary, a 30 MB zip, DOCX. Entry points (`--entries`): `list`, `search`, `thread`,
`forward`, `joint`, `files`, `viewer` (Download pressed inside the viewer), `hidden` (a row released while a viewer covers it).
Each case reports whether it opened, the time to the first content, a reopen time and the requests the server saw;
failures come with a screenshot. `--only id,id` filters; `--tree <checkout>` runs the same suite on an older build.
The Android save picker (Kotlin) is replaced by a mock that writes to a temp directory; everything else is real.
