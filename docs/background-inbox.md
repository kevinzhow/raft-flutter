# Mobile background inbox fallback

Android WorkManager and iOS BGAppRefresh periodically fetch authenticated unread Activity and issue local notifications. Socket notifications remain the live path. This does not register FCM, APNs or UnifiedPush.

The shared code is in `apps/raft_flutter/lib/platform/background_inbox.dart` and `background_notifications.dart`. Enable System notifications for the current account/workspace. One periodic task has the identifier `app.raft.raft_flutter.inbox_refresh`; its input contains no credentials. Tokens remain in SecureSessionStore. A headless engine owns the rotating session only while the UI engine is absent. If the UI exists, the worker delegates to that engine's existing client. UI startup waits for a running headless session owner before reading credentials.

A wake fetches up to 100 latest unread conversations and delivers up to five latest-activity alerts. It does not mark messages read. Account/workspace changes, local opt-out, OS permission, server push preferences, mute/Done/follow projection and current channel/message authority fence delivery. Activation time prevents old-backlog notifications. A bounded persistent ledger and stable OS notification IDs deduplicate Socket and fetch delivery. Disabling notifications or logging out clears the selected background scope and cancels the job.

For mentions-only server preferences, a notification requires the projected first personal-mention ID to identify the latest activity. Some current server projections omit that ID. Those ambiguous rows are skipped; this fallback does not claim complete mentions-only delivery.

Android requests a 15-minute interval with a network constraint. Doze, battery policies and explicit force-stop can delay or suspend work. iOS controls BGAppRefresh timing and may wake infrequently. Neither interval is a promise of notification latency.

## iOS setup

The checked-in iOS host was generated with Flutter 3.47.6. It targets iOS 14+, declares `fetch` and the exact permitted identifier, registers background plugins and restores launch handlers before app launch completes under UIScene. Keychain credentials use first-unlock, device-only accessibility; notifications request permission only after the user opts in. Use an HTTPS coordinator origin. Configure signing in Xcode on a Mac.

This is source integration, not an iOS release. Xcode compilation, iOS scheduling, locked-device credentials, OS notification delivery and cold notification navigation have not been verified on this Linux host. Existing native media features also require their own iOS platform acceptance.

## Verification boundary

Focused tests cover unread selection, old/read suppression, persistent deduplication, server/account/workspace boundaries, opt-out and Done races, denied context, retryable delivery, thread identity and cross-engine session ownership. Actual Android cold-process delivery, a subsequent system-periodic deduplication check, OS notification click, opt-out and logout passed against commit c598e2c on 2026-10-08. See [source-bound native evidence](android-background-evidence.md). iOS native runtime and subsequent UI-source acceptance remain pending.

Sources: [Workmanager setup](https://docs.page/fluttercommunity/flutter_workmanager/quickstart), [Android periodic work](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work), and the pinned [Raft server routes](https://github.com/botiverse/raft-source/tree/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/server/src/routes).
