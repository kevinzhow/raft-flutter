# Final client parity review

This review uses mounted source `26f77ef` / Web1.17.5. **Functional baseline source hash: `6ab79f33a7f39f98523dadd38dfc1430fd2d7f8e75d10736d0c80050bd1c5701`.** The serialized engineering check passed353 Dart tests,29 Python host tests and whole-project analysis. **Android full `2026-10-08T03:02:43.361866Z` completed successfully** at this hash. Its54 unique checkpoint rows all match that run and all referenced PNGs exist. Same-source Linux full `2026-10-08T03:11:25.507223Z` also completed successfully with53 unique matching screenshot checkpoints. The baseline is archived at `.local/functional-baseline-6ab`. Both baseline platform runs passed; the active visual-alignment revision is newer and must be revalidated before final artifacts.

The Android run covers actual inline-thread navigation, resource/Fleet/runtime controls, human-edited prepared cards, supported Mermaid, text/PDF/audio/video, selected-message export, real OS-notification navigation, management, joint channels, default-OFF conversion, sidebar, Chinese Locale, Dark/Light and secure sign-out. Earlier b20 Linux full passed with53 checkpoints, but does not substitute for the current Linux result. The mobile state rebind, adapter/viewport ownership and bounded target-focus repairs have their focused regressions;19 reply/preference/controller cases also pass.

**Pixel-level component parity is incomplete.**75 verified SDK theme interactions and token mapping demonstrate specific functional controls and theme states. They do not establish same-size Web/native pixel equivalence. Material controls and page presentation need an explicit visual audit, corrections and same-version/data/theme/size evidence. A component-by-component visual diff/golden acceptance record is still missing. Functional/native passes must not be reported as design parity.

## Remaining client implementation and rendering limits

- **Independent authenticated native workspace windows remain unimplemented.** Linux has one engine with single-instance URI forwarding. Separate workspace engines, focus/reuse and a shared secure session broker are missing. The configured Web-browser fallback is a separate capability and does not satisfy native-window parity. See `desktop-window-evidence.md`.
- **Full Web Mermaid grammar is not reproduced by the native renderer.** Supported diagrams, source/copy/large-view interactions and failure fallback are implemented and tested. Syntax outside the native parser uses source fallback; a complete diagram-family rendering claim is unsupported. See `message-presentation-evidence.md`.

No mandatory mounted management/auth/joint/resource flow is intentionally replaced by a generic JSON form or fabricated server success. The repaired enabled reply/preference adapters are not classified as experimental gaps.

## Remaining client acceptance work

Both6ab baseline full runs passed. Pixel-level page/component corrections are now active; new-source native suites and final artifacts remain pending. Earlier native and independent OS-probe passes remain explicitly tied to their earlier source or isolated scope. Notification-preference enabled-version behavior and reply epoch/race boundaries also have focused transport tests; the final Linux UI run does not establish a live enabled rollout of every configurable core. Real operating-system screen-reader behavior, comprehensive text-scale/hover/focus visual equivalence and large-history performance are not established by SDK previews or the existing reducer tests. A system file-viewer opening assertion and the configured workspace-browser OS launch also remain unproved. These are validation limits, not proof that the corresponding implemented controls are absent.

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

## Android media and context repair evidence

The current completed Android full run validates native video160×90, audio, PDF pages, pause/seek/volume and the Android-only MediaCodec Surface output. The earlier042 native-player receipt remains auxiliary evidence for the EGL repair and sticky-error behavior; it does not replace this current-source full proof. ChatView now gives a replaced context its own keyed Chat, adapter and viewport. Queued focus/diffs verify ownership after awaits and acknowledge only an attached target intersecting the viewport; normal updates and history prepend retain the active anchor. Ten focused context/role/inline/receipt regressions passed. These repaired behaviors are also exercised by the completed Android whole-app flow. Same-source6ab Linux full also passed; this baseline does not validate subsequent visual corrections.
