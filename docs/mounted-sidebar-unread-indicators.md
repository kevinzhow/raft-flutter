# Mounted sidebar unread and draft indicators

The mounted channel row follows pinned Web `Sidebar.tsx:838–918` and `utils/channelUnreadIndicator.ts`: a joined, unmuted channel shows an accent unread badge and bold title. Unjoined or activity-muted channels keep an exact unread count as quiet monospaced text. Selection alone does not turn a quiet count into a loud badge. Unjoined rows retain their normal navigation action.

The shared `RaftNavItem` now accepts membership, activity mute and draft presentation inputs. The application supplies accepted channel records and existing scoped drafts; the SDK does not fetch preferences, read messages or own draft persistence. Channel and direct-message drafts use the mounted Pencil fallback only when there is no unread count. Both regular and pinned Agent DM compositions pass their actual draft state.

Muted joined channels show the Source BellOff glyph in a 16px slot with a 12px graphic. Its tooltip and semantic label are localized. Unselected unjoined channels dim the name and channel glyph using the placeholder color. Activity-muted names use the muted color even on hover. These are separate from disabled actions.

SDK previews show all three actual themes. New SDK tests exercise capped quiet counts, loud/quiet precedence, typography, hover, first pointer input, keyboard input and draft precedence. Mounted application tests exercise the actual sidebar in three themes, accepted unmute changes, channel/DM drafts and first-pointer navigation to an unjoined channel. Existing conversation, directory, navigation-role and group tests remain required.

Draft marker updates currently follow the existing workspace rebuild notifications, rather than introducing a broad notification for every editor keystroke. This change does not establish immediate per-keystroke draft marker updates.

The application does not yet project Source `hasNew` and `mentionFlags` into sidebar rows, and this change does not invent those inputs. Quiet new dots, mention markers, Slack bridge badges, pinned wrapping and Agent activity badges remain separate gaps. No scanner baseline or rule changed. Pixel and native workflow acceptance requires fresh captures and real platform runs; widget checks do not establish scrolling performance or resolve P01.
