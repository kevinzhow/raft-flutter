# Final client parity review

This review uses mounted source `26f77ef` / Web 1.17.5. **Current source hash: `6ab79f33a7f39f98523dadd38dfc1430fd2d7f8e75d10736d0c80050bd1c5701`.** Its serialized engineering check passed all **353 Dart tests**, **29 Python host tests** and whole-project analysis. After the mobile thread-state repair, an Android video EGL failure required the MediaCodec Surface output repair. The subsequent Android run passed real video/media and notification-shade click but failed an immediate post-click message assertion before asynchronous loading completed. The test now waits for the loaded target. Current-source Android full is running first; Linux will rerun serially afterward. Neither platform is claimed as a current-source aggregate pass.

The earlier Linux whole-app run **2026-10-08T01:49:11.360590Z** passed with `completed:true` for **earlier** hash `b20ae836e668cfff840cbe01beabfad2526444621866ec0b6f9c173bae4e0fd4`, with53 unique checkpoint rows and matching PNGs checked at completion. It covered core collaboration, resource controls, Fleet/runtime, prepared cards, supported Mermaid, document/media, forwarding, joint channels, default-OFF conversion, desktop inline thread navigation, sidebar drag, Chinese Locale, Dark/Light and secure sign-out. These are historical b20 results, not acceptance of the repaired mobile revision.

`ChatView.didUpdateWidget` now rebinds main/thread state, directory/selection/listeners and fences queued diff/focus work with a binding revision. Two new regressions exercise an actual360px WorkspaceView close/reopen and direct same-State role reuse: they failed before the repair and passed after it. All nine targeted tests passed, as did the final353-test engineering suite. The19 reply/preference/controller cases and75 verified SDK browser theme records remain separately valid. The narrow locale test proves persisted `zh-cn`, Chinese Locale, translated Appearance/Account/dark/light labels and restoration; it did not click the dark/light controls. Actual Dark/Light switching was proved in the earlier b20 Linux whole run.

## Remaining client implementation and rendering limits

- **Independent authenticated native workspace windows remain unimplemented.** Linux has one engine with single-instance URI forwarding. Separate workspace engines, focus/reuse and a shared secure session broker are missing. The configured Web-browser fallback is a separate capability and does not satisfy native-window parity. See `desktop-window-evidence.md`.
- **Full Web Mermaid grammar is not reproduced by the native renderer.** Supported diagrams, source/copy/large-view interactions and failure fallback are implemented and tested. Syntax outside the native parser uses source fallback; a complete diagram-family rendering claim is unsupported. See `message-presentation-evidence.md`.

No mandatory mounted management/auth/joint/resource flow is intentionally replaced by a generic JSON form or fabricated server success. The repaired enabled reply/preference adapters are not classified as experimental gaps.

## Remaining client acceptance work

The current repaired source needs both full native results; Android is currently running first, then Linux will rerun serially. Earlier native and independent OS-probe passes remain explicitly tied to their earlier source or isolated scope. Notification-preference enabled-version behavior and reply epoch/race boundaries also have focused transport tests; the final Linux UI run does not establish a live enabled rollout of every configurable core. Real operating-system screen-reader behavior, comprehensive text-scale/hover/focus visual equivalence and large-history performance are not established by SDK previews or the existing reducer tests. A system file-viewer opening assertion and the configured workspace-browser OS launch also remain unproved. These are validation limits, not proof that the corresponding implemented controls are absent.

## External or deployment prerequisites

| Capability | Implemented conditional client behavior | Unproved external operation |
| --- | --- | --- |
| Account/MCP/provider OAuth | Scoped callback, PKCE/nonce, link/unlink, refresh and masked credentials | Configured provider login/link/tool callback on Linux and Android |
| Slack bridge | Real flag, provisioning/readiness, pairing, preflight, epochs and disconnect | Configured Slack OAuth, provisioning and message delivery |
| Billing | Actual subscription summary, owner portal/checkout, proration/seat review and scheduled states | Configured Stripe purchase/portal/webhook/cancellation; no charge was made |
| Channel conversion | Real default-OFF gate, source command/job progress, retry/cancel/upload recovery and send fence | Enabled durable-worker conversion/recovery; no rollout/config was forced |
| Computer/provider onboarding | Source Computer instructions, scoped probes, correlated receipts, real runtime forms and setup projection | Configured Computer/provider canary and complete managed Cindy onboarding |
| Invitation/email flows | Mounted request/review/verification/reset surfaces | External email delivery; local fixture has no Resend client |

A missing deployment prerequisite is not a simulated success or an excuse to omit its conditional UI. Ordinary/private → joint is the mounted conversion route; completed joint → ordinary is not mounted. Production delivery needs its actual external configuration and explicit evidence.

## Source exclusions and platform contracts

The Activity TypeSpec transport remains experimental/off under the pinned Web contract; existing inbox/read-state APIs are used. Removed thread/task open-new-tab entrypoints are not restored. The mounted server restricts notification:push to mobile; Linux desktop message push is unsupported by that source. Android online-Socket local notifications are implemented, while an FCM/killed-app remote-push contract is absent from the mounted native registration route. These source/platform boundaries must not be reported as completed background-push or independent-window parity.

## Current Android media acceptance

The earlier Android full run reached prepared cards/runtime, text/PDF and WAV pause/seek/volume, then failed video output because mpv GPU output could not establish its EGL GLES context. The Android-only MediaCodec Surface (`mediacodec_embed`) repair passed the two native player tests, including real160×90 video,332ms progress, pause,1500ms seek, volume40 and sticky-fatal behavior. The completed player-smoke receipt records the earlier042 media-repair source hash; the unchanged media behavior still needs the current4baf full manifests. It is auxiliary evidence; current Android full is running, with Linux rerun afterward. See `attachment-evidence.md`.

A later Android0c attempt stopped before completing the suite when an external Vulkan diagnostic crashed the emulator graphics stack. That attempt is not a product acceptance pass. The same owned AVD was restored; no extra Vulkan diagnostics are being issued during the serialized native runs. Current acceptance remains pending until both manifests are completed for the same0c hash.

The current ChatView also confirms a target row is attached and intersects the viewport before acknowledging focus. A regression forces the library’s first focus callback to return without a mounted target: the old code makes one attempt and fails, while the bounded retry succeeds. All eight focused jump/role/receipt cases passed; final full native runs remain pending.

The earlier8e61 Linux80500 run passed actual message selection/export, native media, management and joint workflows, then failed a sidebar test assertion because a shown DM lazy row was still off-screen after scrolling to a custom section. The test now reveals that actual DM row before asserting and capturing the custom section. This is a test-only fix; the complete353 Dart/29 host/analyze check passed for current4baf. Android19417 is now running first and fresh Linux will follow. Neither earlier8e61 nor current4baf is marked as a completed aggregate until its actual manifest says completed.

The latest repair gives each replaced context a fresh keyed Chat, adapter and viewport. The package detaches focus methods when the old list disposes; sharing its adapter across main/thread list replacement could disable later focus permanently. Retired lists now detach only their own adapter. Queued focus/diffs verify adapter and viewport ownership after awaits. Normal updates and history prepend retain the active list/anchor. Ten focused context, role, inline and receipt regressions passed, followed by the full 353 Dart/29 host/analyze engineering run. Actual full native results for this source remain pending.

The Android full run of the previous a05 source passed real native video, audio/PDF, selected-message PNG review and real OS-notification navigation. It ended at a test-only mobile sidebar assertion while its drawer was closed. The current test opens the actual navigation drawer before sidebar inspection and closes it with an outside tap before continuing. Current whole-platform results remain pending; this earlier partial run is not represented as completed.
