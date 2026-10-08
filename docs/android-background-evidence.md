# Android background inbox: actual native evidence

Verified on 2026-10-08 UTC against product commit `c598e2c18247e217a4798f6cc65fc785c11cbc3b`, Flutter 3.47.6, and owned Android emulator-5580. This proof uses the debug product `main` APK, the actual app login/settings UI, and isolated local fixture accounts. It does not establish acceptance for subsequent UI changes or iOS.

The installed APK and built APK have the same SHA256 `499698bb8c83bdbaca59e14415b14a12a3da4805c7736a1bdc5a051df4eb7688` (228981677 bytes). The user opted into notifications in the actual UI and accepted Android's permission prompt.

## Actual results

- The owned WorkManager database contained one unique periodic task `app.raft.raft_flutter.inbox_refresh`, interval 900000 ms and a network constraint. Its Android namespace is `androidx.work.systemjobscheduler`.
- The app went Home and was killed with `am kill`, rather than force-stop. Its PID was absent before a genuine other-human DM was sent at 06:26:15 UTC. At its actual due time, only the owned registered job 2 was forced. A successful headless wake ran at 06:29:03.989–06:29:04.453. The persistent ledger contained the genuine message ID; Android NotificationManager and the actual notification shade contained its body.
- With the message still unread, a second real periodic wake ran automatically at 06:44:05.373–06:44:05.604, just before the planned force command. The notification remained exactly one record, with the same ID, creation time and update time. This is actual native deduplication evidence, not an early forced job that skipped work.
- An actual pointer tap on that OS notification opened Raft's MainActivity and rendered the exact target message in its conversation.
- The actual System notifications switch was disabled. The selected background scope cleared, local preference became false, and no live owned JobScheduler job remained. Another genuine DM produced no OS notification. Actual Sign out returned to the login form and left no selected scope, live job or per-scope ledger.

No WorkManager timing database, system clock or scheduler callback was edited. The first wake was forced after the registered period became due; this does not measure natural notification latency. The second wake was a real system-periodic execution. Android power policies and explicit force-stop remain outside this controlled timing result.

## Evidence

Receipts and screenshots are in [evidence/android-background-20261008](evidence/android-background-20261008/). They include the matching APK hashes, registered task metadata, both successful wakes, stable native notification identity, actual click timestamp, and opt-out/logout checks. They contain no tokens, passwords or private fixture login configuration.

The host harness originally expected the second wake to occur after the force command, but the system had already started it 108 ms earlier. The final proof requires the real next period and successful headless result. Android's abbreviated `/.MainActivity` component name also required canonical component validation. Neither correction changes app behavior or treats a missing message as success.

## Remaining platform acceptance

The iOS host/plugin/Keychain source is integrated. Xcode compilation, iOS scheduler behavior, locked-device credentials, notification delivery and cold click routing still require a Mac/device run. No iOS runtime pass is claimed. The final visual source must also receive its own full Linux/Android acceptance.
