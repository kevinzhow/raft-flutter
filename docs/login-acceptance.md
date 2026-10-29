# Login / onboarding acceptance (Android phone)

Owner report (2026-10-12): the login flow was never accepted. (1) Text appears in the middle of the screen
("Loading…") with a yellow line under it. (2) The server-selection rows have no press feedback.

This page is the acceptance record: every screen from cold start to the first workspace frame, rendered through
the real `RaftApp` on an Android emulator in Brutal, Elegant light and Elegant dark, the defects found, the fixes,
and the guards that keep them fixed.

## How it was run

| What | Where |
| --- | --- |
| Fixture entrypoint (production `RaftApp` + `RootErrorBoundary`, fixture API, no real login) | `apps/raft_flutter/integration_test/login_qa_main.dart` |
| Driver: steps through the states, real pointer taps, `adb` typing/screenshots, fallback-style audit | `tool/login-qa` |
| Contact sheets: device shots next to the Web (React) parity captures | `tool/login-qa-sheet` |
| Screenshots | `/tmp/login-qa/after/<state>.<theme>.png` (fixed build), `/tmp/login-qa/before/` (build at `c88601bc`, the states that exercise the changed widgets) |
| Contact sheets | `/tmp/login-qa/sheets/` (Web, before, after per theme), `/tmp/login-qa/sheets-web/` (Web, after) |

```sh
cd apps/raft_flutter
../../tool/flutter build apk --profile --target-platform android-x64 \
  --android-project-arg=raftApplicationIdSuffix=.linkperf -t integration_test/login_qa_main.dart
adb -s <emulator> install -r build/app/outputs/flutter-apk/app-profile.apk   # only the .linkperf package
adb -s <emulator> forward tcp:8791 tcp:8791
python3 tool/login-qa --serial <emulator> --out /tmp/login-qa/after            # every state, 3 themes
python3 tool/login-qa-sheet --shots /tmp/login-qa/after --base /tmp/login-qa/before --out /tmp/login-qa/sheets
```

The control server (`/scenario`, `/set`, `/release`, `/tap`, `/down`, `/up`, `/texts`, `/fallback`) lets the driver
hold loading states (a held request is answered by `/release`), flip the login result (wrong password, network down,
500, 429, pending), the server list (none, one, two, many, loading, failed), the account (verified, unverified, profile
pending) and the setup projection. Anonymous clients built inside the app (providers, forgot password) reach the same
fixture through a loopback server. `/fallback` reports every paragraph painted in Flutter's missing-Material style
(`debugLabel` "fallback style", yellow double underline): it was empty for all 189 screenshots of the fixed build and
listed `Restoring session…`, `Loading servers…` and `Joining community…` on the build before.

Device: Android 16 x86_64 emulator (AVD `rs_design_phone`, 1080x2400 at 420 dpi, gesture navigation), package
`app.raft.raft_flutter.linkperf`. The shared `emulator-5580` was being driven by another run (app-icon alias test:
`force-stop` plus reinstall of `.linkperf` every few seconds), so a private emulator instance (`emulator-5582`) was
started for this pass instead of fighting over the package. The shared emulator was not killed or wiped.

## State inventory

Cold start to first workspace frame. "Web" is the parity capture (tool/parity-ext
`components.auth-pages.mobile.*`, `components.auth-ext.mobile.*`); `-` = no Web capture exists for the state (a
Flutter-only fixture such as the live keyboard or a pressed state).

| State | Screenshots | Web reference |
| --- | --- | --- |
| `access-denied` | `access-denied.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.server-denied.with-server` |
| `forgot` | `forgot.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.forgot.default` |
| `forgot-sent` | `forgot-sent.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.forgot.sent` |
| `invite-agreement` | `invite-agreement.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.invite.agreement` |
| `invite-expired` | `invite-expired.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.invite.expired` |
| `invite-loading` | `invite-loading.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.invite.loading` |
| `invite-seat-limit` | `invite-seat-limit.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.invite.seat-limit` |
| `invite-signed-in` | `invite-signed-in.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.invite.signed-in` |
| `invite-signed-out` | `invite-signed-out.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.invite.signed-out` |
| `invite-throttled` | `invite-throttled.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.invite.throttled` |
| `joining-community` | `joining-community.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.servers.joining-community` |
| `login` | `login.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.login.default` |
| `login-empty-error` | `login-empty-error.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.login.missing-password` |
| `login-invalid-email` | `login-invalid-email.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.login.invalid-email` |
| `login-keyboard` | `login-keyboard.{brutal,elegant,dark}.png` | - |
| `login-keyboard-password` | `login-keyboard-password.{brutal,elegant,dark}.png` | - |
| `login-network` | `login-network.{brutal,elegant,dark}.png` | - |
| `login-pending` | `login-pending.{brutal,elegant,dark}.png` | - |
| `login-pressed-create-one` | `login-pressed-create-one.{brutal,elegant,dark}.png` | - |
| `login-pressed-forgot` | `login-pressed-forgot.{brutal,elegant,dark}.png` | - |
| `login-pressed-signin` | `login-pressed-signin.{brutal,elegant,dark}.png` | - |
| `login-rate` | `login-rate.{brutal,elegant,dark}.png` | - |
| `login-server` | `login-server.{brutal,elegant,dark}.png` | - |
| `login-social` | `login-social.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.login.social` |
| `login-success-first-server` | `login-success-first-server.{brutal,elegant,dark}.png` | - |
| `login-success-servers` | `login-success-servers.{brutal,elegant,dark}.png` | - |
| `login-success-verify` | `login-success-verify.{brutal,elegant,dark}.png` | - |
| `login-wrong` | `login-wrong.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.login.error` |
| `onboarding-profile` | `onboarding-profile.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.identity.default` |
| `onboarding-profile-keyboard` | `onboarding-profile-keyboard.{brutal,elegant,dark}.png` | - |
| `onboarding-verify` | `onboarding-verify.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.verify.default` |
| `onboarding-verify-manual` | `onboarding-verify-manual.{brutal,elegant,dark}.png` | - |
| `onboarding-verify-resend` | `onboarding-verify-resend.{brutal,elegant,dark}.png` | - |
| `public-server` | `public-server.{brutal,elegant,dark}.png` | - |
| `register` | `register.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.register.default` |
| `register-exists` | `register-exists.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.register.error` |
| `register-filled` | `register-filled.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.register.filled` |
| `register-unchecked-error` | `register-unchecked-error.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.register.unchecked` |
| `reset` | `reset.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.reset.default` |
| `resolution-loading` | `resolution-loading.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.bootstrap.loading` |
| `restore-offline` | `restore-offline.{brutal,elegant,dark}.png` | - |
| `restoring` | `restoring.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.bootstrap.restoring` |
| `root-error` | `root-error.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.root-error.default` |
| `servers-create` | `servers-create.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.server.create-more` |
| `servers-create-busy` | `servers-create-busy.{brutal,elegant,dark}.png` | - |
| `servers-create-error` | `servers-create-error.{brutal,elegant,dark}.png` | - |
| `servers-create-filled` | `servers-create-filled.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.server.create-more-filled` |
| `servers-failed` | `servers-failed.{brutal,elegant,dark}.png` | - |
| `servers-loading` | `servers-loading.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.servers.loading` |
| `servers-many` | `servers-many.{brutal,elegant,dark}.png` | - |
| `servers-none` | `servers-none.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.server.create-first` |
| `servers-none-filled` | `servers-none-filled.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.server.create-first-filled` |
| `servers-none-keyboard` | `servers-none-keyboard.{brutal,elegant,dark}.png` | - |
| `servers-none-pressed-create` | `servers-none-pressed-create.{brutal,elegant,dark}.png` | - |
| `servers-one` | `servers-one.{brutal,elegant,dark}.png` | - |
| `servers-pressed-create-new` | `servers-pressed-create-new.{brutal,elegant,dark}.png` | - |
| `servers-pressed-logout` | `servers-pressed-logout.{brutal,elegant,dark}.png` | - |
| `servers-pressed-row` | `servers-pressed-row.{brutal,elegant,dark}.png` | - |
| `servers-two` | `servers-two.{brutal,elegant,dark}.png` | `components.auth-ext.mobile.server.choose` |
| `workspace` | `workspace.{brutal,elegant,dark}.png` | - |
| `workspace-after-select` | `workspace-after-select.{brutal,elegant,dark}.png` | - |
| `workspace-setup-bar` | `workspace-setup-bar.{brutal,elegant,dark}.png` | `components.auth-pages.mobile.setup-gate.resume-bar` |
| `workspace-setup-bar-home` | `workspace-setup-bar-home.{brutal,elegant,dark}.png` | - |

Beyond the table: `login-pressed-*`, `servers-pressed-*`, `servers-none-pressed-create` are held presses;
`login-keyboard*`, `servers-none-keyboard`, `onboarding-profile-keyboard` are the form with the IME open;
`login-success-*` is a real sign-in through the fixture API landing on the server list, the first-server form
and the email verification page; `workspace-after-select` is a tap on a server row landing on the workspace;
`restore-offline` is a stored session with the server unreachable (login page with the restore banner).
`after-zh/` repeats the signed-in pages with the account language zh-CN (no clipping or wrong strings).
The login/auth pages of a signed-out device follow the device locale (English on the emulator).

## Issues found

| # | Issue | Evidence (before) | Root cause | Fix |
| --- | --- | --- | --- | --- |
| 1 | The startup, loading and joining screens paint their label in Flutter's missing-Material fallback style: big text with a yellow double underline, in the middle of the page. | `before/restoring.*`, `before/servers-loading.*`, `before/joining-community.*` (same widget for `Loading…`) | `RaftServerResolutionBody` was a bare `ColoredBox` + `Text`, routed as a `MaterialPage` child with no `Material` / default text style above it (every other auth page frames itself in `RaftAuthShell`'s `Material`). | `RaftServerResolutionBody` is a page: `RaftStatusBarHost` + `Material` + page text style + `safe-top`. No `DefaultTextStyle` hack at call sites. |
| 2 | Server-selection rows (and the Create New Server / Log out controls around them) show nothing when pressed. | `before/servers-pressed-row.*` identical to `before/servers-two.*` | The raft-ui `Card variant="option"` recipe (the Web ServerSelector row) has no hover, active or focus style at all (resolved idle, hover, pressed and focus recipes are identical), so the design system gave the row nothing to show; the Web page has no feedback either, a touch client needs one. | New design-system primitive `RaftChoiceCard` (raft_ui): the option card on `RaftInteractive` states. Pressed fills with the muted canvas (brutal: cream and the brutal shadow drops), elegant hover takes `border-line-strong shadow-raft-sm`, focus-visible a 2px ring. `GlobalServerSelector` uses it. See `after/servers-pressed-row.*`. |
| 3 | Text links (Log out, Forgot password?, Create one, Sign in, Back to sign in, Cancel browser sign-in, the brand-bar server URL, Enter code manually, session-footer Log out) had no pressed/hover/focus state and a 14-20dp tap area. | `before/login-pressed-forgot.*`, `before/servers-pressed-logout.*` | `RaftAuthTextLink` was a `GestureDetector` around `Text`; "No account? Create one" was a `TextSpan` with a recognizer. | `RaftAuthTextLink` is a `RaftInteractive`: muted links go to the strong foreground on hover/press, primary links dim on press, focus-visible ring, disabled opacity; on touch density a tap up to 24dp above/below a one-line row reaches the link (48dp target) without changing the Web geometry. `RaftAuthPrompt` and `RaftAuthSessionFooter` use the widget link; `verify-manual-toggle` likewise. |
| 4 | Setup survey option chips, the setup runtime row toggle, "Copy install command" and the root-error "details" disclosure were hand-rolled `GestureDetector`s with no state. | code audit (`GestureDetector` in `setup_steps.dart`, `root_error_fallback.dart`) | Same pattern. | All moved to `RaftInteractive` (chips: hover/press tint + ring; row: tinted while pressed; links: dim on press). |
| 5 | The splash painted a hard-coded `brutalCream` in every theme, so it flashed light cream in Elegant dark (reported by another run, confirmed in `before/restoring.dark`). | `before/restoring.dark`, `before/servers-loading.dark` | `t.product.brutalCream` used for all themes. | Brutal keeps the Web cream; Elegant (light and dark) uses the theme canvas token. (The Web page itself draws cream with the dark foreground colour, i.e. grey text on cream in dark: not matched on purpose.) |
| 6 | "Restoring session…" and the first auth page used the default Brutal light theme for the first frames, then switched to the saved theme (a cream flash before Elegant dark). | `before/restoring.dark` (cream) | `RaftApp.appearance` started at the default and was read from `SharedPreferences` inside `restore()`. | `appearance` starts from the preloaded `DevicePreferences` (loaded before the first frame): `after/restoring.dark` is dark from frame one. |
| 7 | (Caught by this pass, fixed in the same change.) The widget links lost the space in "No account?Create one" and "Signed in as x.Log out". | an intermediate build | Wrap children trim a trailing space. | Non-breaking space after the prefix. |

Checked and fine (no change): safe areas and status bar colour on every auth page (brand bar colour reaches the status
bar), keyboard insets on the login form on a tall emulator (superseded: it hid the field on short phones, docs/auth-keyboard.md), Retry / error banners for wrong
password, network down, 500, 429, unverified account, failed server list and failed create, disabled/busy buttons,
zh-CN strings of the signed-in pages, the Web parity of the covered cases (below).

Notes, not changed (Web behaviour or out of scope):

- The first-server page autofocuses the name field, so the IME opens at once (Web autofocuses the same field). The
  keyboard no longer covers the URL field and button: see docs/auth-keyboard.md.
- The two legal links (Terms of Service, Privacy Policy) stay inline spans inside their paragraph (Web look, text-height
  hit area, no pressed state).
- Hit areas below 48dp next to another control are limited by the neighbour (the next sibling wins the overlap).
- Elegant/dark Web captures of the splash cases show cream (see issue 5); those two ext parity cases now differ
  from the capture by design.

## Parity

Run on the fixed build and on `c88601bc` with the same cases (tool/parity-ext, brutal-light unless noted); no case
changed: restoring 99.90%, loading 99.95%, joining-community 99.90%, server choose 99.37%, create-more 99.58%,
create-more-filled 99.46%, create-first-filled 97.04%, login default/filled 99.31/99.10% (elegant 98.38/98.27%),
login social/invalid/missing/error 99.0-99.1%, forgot 99.0-99.4%. Failing on both builds (pre-existing): login
elegant-dark 95.95/95.37%, setup survey 94.8-95.7%.

## Guards

- `apps/raft_flutter/test/fallback_text_style.dart`: `expectNoFallbackTextStyle()` walks every `RenderParagraph` and
  fails on Flutter's missing-Material fallback style (`debugLabel` "fallback style", or the yellow double underline).
- `apps/raft_flutter/test/login_flow_states_test.dart`: pumps the real `RaftApp` on a phone (390x844) in Brutal,
  Elegant light and Elegant dark through restoring, login, wrong password, busy, network down, register, forgot,
  invite (signed out, expired, loading), account onboarding (profile, verify), first-server / server list /
  create / create error / create busy / failed directory / loading, access denied, joining community and the first
  workspace frame, and the splash and root error pages directly as bare `MaterialApp` pages; each frame must have no
  fallback-styled text. It also pins the splash canvas (theme canvas, brutal cream) and that the first frame uses the
  saved theme.
- `apps/raft_flutter/test/login_press_feedback_test.dart`: for the server rows, `+ Create New Server` and `Log out`
  in three themes: pressing changes the painted decoration/colours, and a tap 23dp from the control centre (inside a
  48dp box, outside the 36/24dp visual box) still triggers it.
- `server_setup_resume_bar_test.dart` asserts the setup resume bar and the setup step have no fallback style.

Test run before and after the fixes: the new guards fail on `c88601bc` (splash paragraphs in fallback style, server
row without pressed feedback, saved theme ignored on the first frame) and pass after.

## Desktop browser sign-in that never opens

`NativeOAuthBroker` (desktop loopback flow, unchanged) exposes `helpUrl`: set when the launcher throws / returns false
(immediately) or when no callback has arrived after 3 s (`launchUrl` can return true while nothing opens, e.g. the
Linux AppImage when GIO cannot exec the browser). `RaftAuthPage` then shows, above "Cancel browser sign-in", "Browser
didn't open?" with "Copy sign-in link" (copies the exact authorization URL, then reads "Link copied") and "Open again"
(`launchUrl` on the same attempt). The attempt keeps waiting (10 min); cancelling removes the help. The URL carries the
provider state: it is never logged or put in an error message. zh strings: `l10n/zh_oauth_browser.dart`. Guard:
`test/oauth_browser_help_test.dart` (a launcher that never opens: nothing before 3 s, help after; a launcher that
throws: help at once; copy puts the exact URL on the clipboard; open again launches again; cancel clears it).
