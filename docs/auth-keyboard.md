# Auth / onboarding pages and the soft keyboard

Owner report (2026-10-12): on the login screen the password field was covered by the keyboard and nothing lifted it.

## Cause

The auth pages are bare `MaterialPage` routes with no `Scaffold`, so nothing resizes them for the keyboard
(`MediaQuery.viewInsets.bottom` was ignored). `RaftAuthShell` already had a `SingleChildScrollView`, but its content
was laid out against the full window height (`min-height: window - brand bar`), so the scroll view had no extent and
Flutter's own "caret into view" had nowhere to scroll. Fields below the keyboard top stayed under it. On a 411x914dp
Android phone only the submit button was hidden; on 360x640 the password / URL / display-name field itself was.
Web gets the lift from the browser (it scrolls the focused input into view of the visual viewport).

## Mechanism (one for every page)

`packages/raft_ui/lib/src/keyboard_reveal.dart`:

- `RaftAuthShell` (and the wide `RaftOnboardingShell`) spend the keyboard inset themselves: bottom padding is the
  keyboard height while it is up (the old `safe-bottom` = inset + 1rem at rest, unchanged), so the viewport ends at the
  keyboard and the centred composition returns when it goes away.
- The page scrolls through `RaftKeyboardScrollView`. On keyboard / window changes (`didChangeMetrics`, frame by frame
  with no animation) and on focus changes (160 ms) it reveals the focused `EditableText` and the nearest
  `RaftPrimaryAction` below it (the submit / continue button) together when both fit above the keyboard; when they do
  not fit, the field goes to the top of the window. It moves only when something is hidden, so switching between
  fields does not jump or re-centre. A second pass after 180 ms makes it the last word over `EditableText`'s own
  100 ms caret scroll.
- `RaftPrimaryAction` marks the action: `RaftAuthWideButton` with the accent variant (every `RaftAuthSubmit`, "Continue"
  of the profile page, "Create Server") and the verify-code `Verify` button and the setup survey `Continue` wrap it.
- The keyboard height is read from the `View` (not `MediaQuery`), so a page below a layout that already spent the
  inset (the workspace content region: setup survey) reveals too. `KeyboardInsetGuard` (stale inset after Home,
  `docs/keyboard-repro.md`) still zeroes the `MediaQuery` inset, so a phantom inset cannot shrink the page.
- Status bar: the shell keeps `RaftStatusBarHost` and the top inset as the scroll view's outer padding, so scrolled
  content clips at the status bar bottom and the brand-bar colour rule of `docs/status-bar.md` is unchanged.

Pages: sign in, register, forgot password, reset password (token, password, confirm), verify email (manual code),
account profile (username, display name), create first server (autofocused name + URL), create another server,
setup survey ("Other" source), the Server URL dialog (`RaftFormDialog`, already inset-aware). No text entry, nothing to
lift: invite accept, community join, choose server, result pages, the Cindy step (runtime picker only).

## Guards

- `apps/raft_flutter/test/auth_keyboard_test.dart`: each page above through the real `RaftApp` at 390x844 and 360x640
  and 841x701 with a 336dp keyboard: focused field below the status bar and above the keyboard, and the submit button
  too (at 360x640 the button is required from the last field; the first field of a three-row form cannot share 280dp
  with it). Also the inset-spent-by-an-ancestor case, and a source guard: `auth_page.dart` has no raw
  `SingleChildScrollView`, no file but `auth_page.dart` builds `RaftAuthTopBar`.
- `tool/auth-keyboard-qa`: the same check on an emulator (fixture app, no real login):
  `apps/raft_flutter/integration_test/login_qa_main.dart` gained `workspace-setup-survey` / `workspace-setup-cindy`.

## New auth page

Compose `RaftAuthPage` / `RaftOnboardingPage` / `RaftAuthShell`; mark the page's submit as `RaftAuthSubmit` or accent
`RaftAuthWideButton` (or wrap it in `RaftPrimaryAction`). Do not build a second frame with its own scroll view.
