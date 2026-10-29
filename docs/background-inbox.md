# Mobile background inbox fallback

**Android has no background fetch (owner decision, 2026-10-13).** The periodic WorkManager task was removed. On Android a notification while the app is in the background arrives only over the live socket (`notification:push`, handled in `NativeContentCoordinator._event`), so it depends on Android keeping the process and its connection alive. At every start Android cancels the unique task `app.raft.raft_flutter.inbox_refresh` left by earlier builds (`BackgroundNotificationScheduler.cancelLegacyAndroidTask`), and a stale job that still fires does nothing. Settings → Notifications shows a notice with a button to the system battery optimization list while the app is optimised (`NativeBatteryBridge`, `lib/platform/battery_optimization.dart`); it does not use `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, which Google Play restricts. The measured delivery of the socket path in the background is in the device experiment report of the commit that made this change.

The rest of this page describes iOS BGAppRefresh and the shared polling code (also used by the desktop notifier).

iOS BGAppRefresh periodically fetches authenticated unread Activity and issues local notifications. Socket notifications remain the live path. This does not register FCM, APNs or UnifiedPush.

The shared code is in `apps/raft_flutter/lib/platform/background_inbox.dart` and `background_notifications.dart`. Enable System notifications for the current account/workspace. One periodic task has the identifier `app.raft.raft_flutter.inbox_refresh`; its input contains no credentials. Tokens remain in SecureSessionStore. A headless engine owns the rotating session only while the UI engine is absent. If the UI exists, the worker delegates to that engine's existing client. UI startup waits for a running headless session owner before reading credentials.

A wake fetches up to 100 latest unread conversations and delivers up to five latest-activity alerts. It does not mark messages read. Account/workspace changes, local opt-out, OS permission, server push preferences, mute/Done/follow projection and current channel/message authority fence delivery. Activation time prevents old-backlog notifications. A bounded persistent ledger and stable OS notification IDs deduplicate Socket and fetch delivery on iOS (Android keeps no ledger: it has no fetch to deduplicate against, and the in-process delivered set covers repeated socket events). Disabling notifications or logging out clears the selected background scope and cancels the job.

Desktop and mobile use the same notification copy. A channel alert is headed
`#channel` with `Sender: message preview` below it; a DM uses the latest
sender's display name, falling back to the conversation name. A thread uses
`#parent-channel · Thread` and the reply sender. Names come from the mounted
`/channels/inbox` projection, without extra directory queries. Missing names
use generic conversation labels, never raw IDs. Titles and bodies are bounded
without splitting Unicode surrogate pairs. Diagnostic notifications are
explicitly titled `Test notification`; the operating system's app identity
remains Raft.

For mentions-only server preferences, a notification requires the projected first personal-mention ID to identify the latest activity. Some current server projections omit that ID. Those ambiguous rows are skipped; this fallback does not claim complete mentions-only delivery.

iOS controls BGAppRefresh timing and may wake infrequently; the interval is not a promise of notification latency. (Earlier Android builds requested a 15-minute WorkManager interval with a network constraint.)

## One count: app icon badge, notification shade, Activity badge

All three follow the accepted Activity window (`SourceActivityUnreadStore`; the server's `totalUnreadCount`, the sum of each listed conversation's `unreadCount`: unread messages of channels, DMs and followed threads, muted and Done rows excluded; the server's own push badge is the same number summed over member servers). `activity_attention.dart` holds the rule.

- **Shade:** one notification per conversation (Activity scope id; a thread is its own conversation), replaced in place by a later message. `NotificationReconciler` removes it as soon as the window shows the conversation read (here, on the Web or another device, mark all read) and removes everything when the total is 0. A conversation the bounded window does not list is left alone.
- **Android launcher badge** is derived from the notifications: each carries `number` = its Activity unread count, and a group summary per server is not counted by launchers. While the app is in the background, unread conversations without a notification get a quiet one (channel `raft_unread_v1`, no sound or pop-up), and unread beyond the 30-row window is one more quiet notification, so the launcher sum is the Activity total. Mentions-only push mode, a muted server or disabled alerts leave those out; then the icon count is lower than the Activity badge by design.
- **iOS and macOS icon badge** is set explicitly to the same total (`MacOSDockUnread`, via `app_badge_plus`; iOS needs the badge permission). Nothing can update it while the iOS process is suspended without APNs, which this client does not register for.
- Not covered: Windows removes no toast on read (no per-id removal in the native host) and has no taskbar badge; Linux has no badge.

## iOS setup

The checked-in iOS host was generated with Flutter 3.47.6. It targets iOS 14+, declares `fetch` and the exact permitted identifier, registers background plugins and restores launch handlers before app launch completes under UIScene. Keychain credentials use first-unlock, device-only accessibility; notifications request permission only after the user opts in. Use an HTTPS coordinator origin. Configure signing in Xcode on a Mac.

This is source integration, not an iOS release. Xcode compilation, iOS scheduling, locked-device credentials, OS notification delivery and cold notification navigation have not been verified on this Linux host. Existing native media features also require their own iOS platform acceptance.

## Verification boundary

Focused tests cover unread selection, old/read suppression, persistent deduplication, server/account/workspace boundaries, opt-out and Done races, denied context, retryable delivery, thread identity and cross-engine session ownership. Historical, before the Android worker was removed: actual Android cold-process delivery, a subsequent system-periodic deduplication check, OS notification click, opt-out and logout passed against commit c598e2c on 2026-10-08. See [source-bound native evidence](android-background-evidence.md). iOS native runtime and subsequent UI-source acceptance remain pending.

Sources: [Workmanager setup](https://docs.page/fluttercommunity/flutter_workmanager/quickstart), [Android periodic work](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work), and the pinned [Raft server routes](https://github.com/botiverse/raft-source/tree/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/server/src/routes).
