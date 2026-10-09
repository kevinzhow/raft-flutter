# Activity server flag coverage

The pinned Source ThreadsInbox uses the evaluated `activity_sidebar_inbox_v0`
flag for the selected server. Its disabled branch has All, Unread and Mentions
segmented controls. Its enabled branch has the Activity sidebar, grouped
channel/DM selection, Saved and Done views. Source does not expose the old
Flutter test's Unfollowed view in either branch.

Flutter DesktopActivityFlag already requests `/feature-flags/evaluate` with
selected server ID and actual platform, and fences origin, principal, generation,
server and role changes. At the original gap audit it applied only the master/detail breakpoint.
ResourceView rendered the classic branch when evaluation is enabled. This
is an implementation gap, not proof that enabled and disabled pages match.

Checklist N24h requires six mounted page proofs: both service evaluation states
in all three themes, including the actual enabled controls and result sources.
It deliberately references the future full-page test file; model flag tests or
local overrides cannot satisfy it. Server switch and late evaluation fences
must also remain covered. The original 47-item audit and its historical verdicts
remain immutable; N24h adds the missing acceptance boundary to N24.

The 74fa876 Linux run failed when its old lifecycle helper attempted a Filters /
Done / Unfollowed menu in the actual disabled branch. That failure and its prior
22 checkpoints remain archived. Correcting the flow must use real Source entry
points and backend readback; it cannot add a non-Source menu just to pass a test.

The bounded implementation and its before/after mounted receipts are recorded
in [activity-server-flag-implementation.md](activity-server-flag-implementation.md).
Native and full-page pixel claims remain separate.
