# Raft local change

This is the published `media_kit` 1.2.6 source (MIT, see `LICENSE`), vendored so Linux player startup does not subscribe to `audio-device-list`. `example/`, `screenshots/`, `test/`, and the ffigen `headers/` tree are omitted. The Dart API stays the same.

## Why

On Linux, bundled libmpv 0.41.0 with PipeWire 1.6.2 reads `audio-device-list` by starting every hotplug driver, PipeWire first. `ao` does not limit that scan. When the runtime directory has no PipeWire socket, `hotplug_init` fails immediately and `uninit` calls `pw_thread_loop_stop`. That joins the `mpv/ao/pipewire` thread. The captured stack is `mpv_get_property_string` inside `pw_thread_loop_stop` → `pthread_join`, while `mpv/ao/pipewire` is still in `epoll_wait`. The join does not return.

media_kit 1.2.6 observes `audio-device-list` during `NativePlayer` initialization, before `idle-active` completes the player. That read runs on the mpv core thread and blocks in the join above, so `idle-active` does not arrive. Calls that wait for initialization, including `setVolume`, wait with it. A session that already has a PipeWire socket does not hit this. A container, a remote session, or a Pulse-only machine does, about 8 times in 100 when each open is its own process.

## Change

- `lib/src/player/native/player/real.dart`: remove `audio-device-list` from the initialization observe map. The handler that parses the property stays, so a later explicit observe still works. `idle-active` stays, so initialization still completes. Playback and `audio-device` are unchanged.
- `lib/src/player/native/core/initializer_isolate.dart`: one `ignore` comment above `Future.delayed(Duration.zero)`. That wait follows a blocking `mpv_wait_event` and yields once per wake-up. The comment does not change behavior. Vendoring places the file under `packages/*/lib`, so the repo lint sees the upstream line.

## Re-applying on upgrade

Upstream has no switch for this observe list. After taking a newer `media_kit`, delete the same map entry again, put the same `ignore` comment back above `Future.delayed(Duration.zero)`, and keep this note. Confirm with a real `Player()` opened 150 times in an empty `XDG_RUNTIME_DIR` (0 hangs) and once with a PipeWire socket (open, play, sound).

`pubspec.yaml` also sets `publish_to: none`, `resolution: workspace`, and `sdk: ^3.13.5`, and aligns `lints` with the workspace. Those are packaging, not the behavior change.
