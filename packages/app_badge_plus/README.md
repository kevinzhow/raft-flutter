# app_badge_plus — Raft local fork

Based on app_badge_plus 1.3.5 from https://pub.dev/packages/app_badge_plus/versions/1.3.5
(upstream https://github.com/windows7lake/app_badge_plus). The upstream LICENSE,
Dart API, Android implementation, Apple package manifests and privacy files are
preserved. Examples and screenshot assets are not vendored.

Raft changes:

- iOS 16+: complete `updateBadge` only after `setBadgeCount` completes. Report a
  `badge_update_failed` FlutterError containing the system error message and only
  its domain/code, excluding arbitrary NSError userInfo. Return on the main queue.
- Earlier iOS: acknowledge the synchronous setter after checking its property.
- macOS: set/read the Dock label on the main queue before completing the call.
- Join the repository's Dart workspace; use its flutter_lints 6 constraint.
- Replace the upstream empty method-channel test with set/clear argument, awaited
  completion, error and support-result regressions; Dart implementation/API stays
  unchanged. These tests use a mocked messenger, not OS badge delivery.

Neither plugin path requests notification authorization. A completed API write
is not proof of visual SpringBoard/Dock rendering. The app retains the last
confirmed value only after a successful Future; a failed write is retried at the
next synchronization, without a self-scheduled retry loop.

Run the source-level Swift regression harness on macOS:

```
python3 test/native/test_badge_completion.py
```

It compiles these production Swift files with inert UIKit, UserNotifications,
Cocoa and Flutter modules. It checks delayed completion, error propagation,
clearing and setter readback; it never invokes actual OS badge/permission APIs.
Actual macOS/iOS method-channel and visual checks remain separate native QA.
