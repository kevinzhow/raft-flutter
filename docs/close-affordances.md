# Close affordances: Flutter vs Web

Kevin (2026-10-12): "on desktop the Agent profile side panel has no x; this
seems missing in many places, not aligned with Web." This is the sweep of every
closable surface (side panels, dialogs and modals, drawers, popups and menus,
lightboxes and previews, toasts, full-page phone overlays) at phone (390x844),
foldable (816x900, a wide layout: the compact cut is 768) and desktop
(1280x800), checked against the Web source
(`packages/web/src` of the pinned source mirror).

Affordances: `x` a visible close button, `back` a Back chevron that leaves the
surface, `esc` the Escape key, `scrim` a tap outside / on the scrim,
`sysback` the Android system back gesture. A `-` cell means the surface is not
shown at that width (reason in the cell). Status: `ok` already matched Web,
`fixed` changed in this sweep, `approved` an owner-approved difference,
`no-web` a Flutter-only surface, `n/a` not dismissible by design.

## Shared mechanisms (one place per rule)

| Rule | Mechanism |
|---|---|
| Escape closes a surface wherever focus is (Web listens on `document`) | `RaftDismissScope` (`packages/raft_ui/lib/src/dismiss_scope.dart`): binds `DismissIntent` for the subtree under a nested autofocus `FocusScope`; default action `Navigator.maybePop`, so `PopScope` (busy submit, unsaved draft) still decides. Applied by `showRaftModal`, `raftModalRoute`, `showRaftAgentModal`, `RaftDialogRoute` (so also `RaftConfirmDialog`), the sidebar section and add-computer dialogs, the channel drawer and the workspace shell. A flutter `Scaffold` registers its own disabled `DismissIntent` action that hides outer actions, so the shell wraps its body again (`dismissInScaffold`). |
| Android back closes a popup instead of the page under it | `RaftBackDismiss` / `raftBackDismissed` (same file): a `LocalHistoryEntry` on the enclosing route while the popup is open. Routes that veto back with `PopScope(canPop: false)` (the workspace shell) call `raftDismissTopPopup` first. |
| Wide layouts: Back closes a profile / directory detail | `WorkspaceView` `PopScope.canPop` false while a profile or `desktopNavigation.target` is open; `escapePanel` closes the topmost layer only (never history-back from a plain page). |
| Toasts carry an x unless Web passes `hasClose: false` | `RaftToastController.show(dismissible: true)`; the selection toast passes `false`. Snackbars show a close icon (`snackBarTheme`). |
| Header gets Back below `md`, X from `md` where Web has it | `RaftPanelHeaderBar` + per-panel `onClose`; `FleetDetail.backAlways` for Search / Activity slots (Web `backButtonVisibility="always"`). |

## Owner-approved and phone-specific differences

* Profile side panel closes on an outside tap on wide layouts (`docs/parity.md`).
* The phone image lightbox and attachment preview are pages with a Back chevron
  (no x); Web shows a dialog with an x.
* Channel settings / members are pages on a phone (Web: drawer) and a drawer /
  modal on wide layouts. The channel drawer has no desktop x in Web either
  (`OverflowSheet hideDesktopClose`).

## Known residual gaps

* Avatar enlarge: Web opens an image lightbox from the agent / human profile
  avatar (`AgentDetailPanel.tsx:3135`, `HumanDetailPanel.tsx:396`); the Flutter
  profile avatar is not tappable (feature, not a close fix).
* Image lightbox gallery (prev / next, arrow keys) is not wired in production.
* Routes that veto back with `PopScope(canPop: false)` other than the shell
  (`channel_settings`, `channel_members`, `create_agent_dialog`, `form_dialog`)
  do not call `raftDismissTopPopup`: a popup open inside a dirty or busy dialog
  sends Back to the dialog's own handler first.
* Android system back and Escape are proven with `handlePopRoute` and key
  events in widget tests, not on a device.

## Guard

`test/close_registry_test.dart` scans `lib/` and `packages/raft_ui/lib/src` for
APIs that open a closable layer (`showRaftModal`, `showDialog`,
`OverlayEntry`, `RaftPanelHeaderBar`, ...). A file that calls one must be listed
in a `CloseSurface` (`test/support/close_registry_*.dart`) or in
`closeScanExempt` with a reason. `test/close_{panels,dialogs,popups,viewers}_test.dart`
open every registered surface fresh at the three widths and perform each listed
affordance (tap the x / Back, Escape, tap the scrim, `handlePopRoute`), failing
when the surface stays open. Surfaces that Web does not let a scrim tap close
also get a "scrim must not close" check. The table below is generated from the
registry: `UPDATE_CLOSE_DOCS=1 tool/flutter test test/close_registry_test.dart`
in `apps/raft_flutter`.

<!-- close-table:start -->
| surface | kind | phone 390 | foldable 816 | desktop 1280 | Web | status | fix |
|---|---|---|---|---|---|---|---|
| `profile-human` | panel | back sysback | x esc scrim sysback | x esc scrim sysback | HumanDetailPanel.tsx: Back md:hidden, X hidden md:flex; ProfilePanel Esc | approved | scrim: owner-approved outside tap (docs/parity.md) |
| `profile-agent` | panel | back sysback | x esc scrim sysback | x esc scrim sysback | AgentDetailPanel.tsx: Back md:hidden, X hidden md:flex; Esc | fixed | header X (97b3f5f7), outside tap (39e0c61c) |
| `profile-external` | panel | back sysback | x esc scrim sysback | x esc scrim sysback | ExternalIdentityDetailPanel.tsx: Back md:hidden, X hidden md:flex | approved |  |
| `thread-panel` | panel | back sysback | back esc sysback | x esc sysback | ThreadPanel.tsx: Back lg:hidden, X lg:flex, Esc | ok |  |
| `channel-settings` | drawer | back sysback | esc scrim sysback | esc scrim sysback | OverflowSheet.tsx (hideDesktopClose): Back md:hidden, Esc, outside press, swipe | fixed | RaftDismissScope: Escape runs the unsaved-draft guard |
| `channel-members-page` | page | back sysback | - (wide layouts open the members dialog (channel-members-dialog) or the drawer sub-page (channel-settings)) | - (wide layouts open the members dialog (channel-members-dialog) or the drawer sub-page (channel-settings)) | ChannelMembers.tsx in the bare OverflowSheet (phone drawer): Back md:hidden | ok |  |
| `channel-members-dialog` | dialog | - (phones open channel-members-page) | x esc sysback | x esc sysback | ChannelMembers.tsx:1090,1334 Modal (Esc, no backdrop close) + X | fixed | showRaftModal binds Escape (RaftDismissScope) |
| `directory-human-detail` | page | back sysback | sysback | sysback | HumanDetailPanel.tsx: Back md:hidden, no desktop close (route page) | fixed | phone Back was missing |
| `search-agent-slot` | panel | back sysback | back esc sysback | back esc sysback | MainLayout.tsx renderContentSlot: AgentById onBack=closeSlot, backButtonVisibility=always | fixed | FleetDetail.backAlways |
| `search-human-slot` | panel | back sysback | back esc sysback | back esc sysback | MainLayout.tsx renderContentSlot: HumanById onBack=closeSlot, backButtonVisibility=always | fixed | MemberProfileView.onBack in a Search / Activity slot |
| `member-graph-page` | page | back sysback | sysback | sysback | MemberGraphSection.tsx MemberGraphRoute (/members/graph): PanelHeader mobileBackProps Back md:hidden, no desktop close (route page) | ok |  |
| `history-lower-limit-confirm` | dialog | x esc sysback | x esc sysback | x esc sysback | Flutter-only history action; ConfirmDialog.tsx:138-165: X + Esc, no pointer dismissal | no-web |  |
| `confirm-dialog` | dialog | x esc sysback | x esc sysback | x esc sysback | ConfirmDialog.tsx:138-165 Dialog disablePointerDismissal: X + Esc, no scrim, all gated on loading | fixed | RaftDialogRoute binds Escape; Esc / Back / X blocked while loading |
| `role-permission-help` | dialog | x esc scrim sysback | x esc scrim sysback | x esc scrim sysback | RolePermissionHelpDialog.tsx:55-60 DialogCard closeOnBackdrop: X + Esc + backdrop | fixed | scrim press: RaftAgentDialogCard.onBackdrop (the card scroll view swallowed it) |
| `sidebar-section-dialog` | dialog | x esc scrim sysback drag | x esc scrim sysback | x esc scrim sysback | SidebarSectionDialog.tsx:30 Modal closeOnBackdrop: X + Esc + backdrop | approved | Below 768 the form is a bottom sheet (RaftPresentationPolicy.form, product-owner approved); from 768 the same centered dialog. X, Esc, Back, a scrim press and (sheet) a drag down all ask the route to close, and a form whose fields changed asks "Discard your changes?" first (an unchanged form just closes); Cancel and Submit never ask |
| `add-computer-dialog` | dialog | x esc sysback | x esc sysback | x esc sysback | AddMachineDialog.tsx:188 Modal (no backdrop close) + X | fixed | Esc / system back run the same cancel path as the X |
| `computer-bulk-model` | dialog | x esc sysback drag | x esc sysback | x esc sysback | BulkChangeModelDialog.tsx:359 DialogCard: X + Esc + Cancel, no backdrop close; applying ignores close; review Back returns to choose | approved | Approved form sheet on phone adds drag; no scrim close at any width. Applying blocks dismissal; Cancel closes, review Back only changes step. |
| `computer-bulk-reset` | dialog | x esc sysback | x esc sysback | x esc sysback | MachineDetailPanel.tsx:622 DialogCard (no closeOnBackdrop): X + Esc | fixed | no scrim close (Web DialogCard); Escape via RaftDismissScope |
| `runtime-usage-sheet` | dialog | x esc scrim sysback | - (wide layouts show the hover / pinned popover (popover family)) | - (wide layouts show the hover / pinned popover (popover family)) | RuntimeAccountUsageChip.tsx:591 BottomSheet (mobile): X, Esc, backdrop press | ok |  |
| `create-channel` | dialog | x esc scrim sysback drag | x esc scrim sysback | x esc scrim sysback | CreateChannelDialog.tsx:250 DialogCard: X + Esc, no backdrop close | approved | Below 768 the form is a bottom sheet (RaftPresentationPolicy.form, product-owner approved); from 768 the same centered dialog. X, Esc, Back, a scrim press and (sheet) a drag down all ask the route to close, and a form whose fields changed asks "Discard your changes?" first (an unchanged form just closes); Cancel and Submit never ask |
| `create-task` | dialog | x esc scrim sysback drag | x esc scrim sysback | x esc scrim sysback | CreateTaskDialog.tsx:59 DialogCard: X + Esc, no backdrop close | approved | Below 768 the form is a bottom sheet (RaftPresentationPolicy.form, product-owner approved); from 768 the same centered dialog. X, Esc, Back, a scrim press and (sheet) a drag down all ask the route to close, and a form whose fields changed asks "Discard your changes?" first (an unchanged form just closes); Cancel and Submit never ask |
| `create-joint-channel` | dialog | x esc scrim sysback drag | x esc scrim sysback | x esc scrim sysback | CreateJointChannelDialog.tsx:245 DialogCard: X + Esc, no backdrop close | approved | Below 768 the form is a bottom sheet (RaftPresentationPolicy.form, product-owner approved); from 768 the same centered dialog. X, Esc, Back, a scrim press and (sheet) a drag down all ask the route to close, and a form whose fields changed asks "Discard your changes?" first (an unchanged form just closes); Cancel and Submit never ask |
| `invite-human` | dialog | x esc scrim sysback drag | x esc scrim sysback | x esc scrim sysback | InviteHumanDialog.tsx:352 DialogCard: X + Esc, no backdrop close | approved | Below 768 the form is a bottom sheet (RaftPresentationPolicy.form, product-owner approved); from 768 the same centered dialog. X, Esc, Back, a scrim press and (sheet) a drag down all ask the route to close, and a form whose fields changed asks "Discard your changes?" first (an unchanged form just closes); Cancel and Submit never ask |
| `add-members` | dialog | x esc sysback | x esc sysback | x esc sysback | AddMembersDialog.tsx:234 DialogCard: X + Esc, no backdrop close | ok |  |
| `form-dialog` | dialog | x esc scrim sysback drag | x esc scrim sysback | x esc scrim sysback | DialogCard.tsx:28-40 / ConfirmDialog.tsx:138: X + Esc, no backdrop close | approved | Below 768 the form is a bottom sheet (RaftPresentationPolicy.form, product-owner approved); from 768 the same centered dialog. X, Esc, Back, a scrim press and (sheet) a drag down all ask the route to close, and a form whose fields changed asks "Discard your changes?" first (an unchanged form just closes); Cancel and Submit never ask; earlier: RaftFormDialog gets a header X and Escape; call sites stop closing on a scrim tap |
| `sos-dialog` | dialog | x esc sysback | x esc sysback | x esc sysback | SOSDialog.tsx:57 DialogCard: X + Esc, no backdrop close (not gated on stopping) | fixed | barrierDismissible false: a stray scrim tap no longer discards the guidance |
| `unsaved-changes-prompt` | dialog | esc sysback | esc sysback | esc sysback | ChannelOverflowMenu.tsx:641 Modal layer=1: Esc closes (ignored while saving), no X, no backdrop close | fixed | PopScope blocks Esc / Back while Save and close runs |
| `announcement-modal` | dialog | x esc scrim sysback | x esc scrim sysback | x esc scrim sysback | AnnouncementModal.tsx:179 Modal layer=1 closeOnBackdrop: X + Esc + backdrop | ok |  |
| `create-agent` | dialog | x esc scrim sysback drag | x esc scrim sysback | x esc scrim sysback | CreateAgentDialog.tsx:1688,1727 Modal / DialogCard: X + Esc, no backdrop close | approved | Below 768 the form is a bottom sheet (RaftPresentationPolicy.form, product-owner approved); from 768 the same centered dialog. X, Esc, Back, a scrim press and (sheet) a drag down all ask the route to close, and a form whose fields changed asks "Discard your changes?" first (an unchanged form just closes); Cancel and Submit never ask |
| `agent-avatar-dialog` | dialog | x esc scrim sysback | x esc scrim sysback | x esc scrim sysback | AgentProfileEditDialog.tsx:187-215 Dialog: X + Esc + outside press, all through requestClose (discard prompt when dirty) | fixed | Escape and an outside press run the guarded close |
| `avatar-discard-confirm` | dialog | esc scrim sysback | esc scrim sysback | esc scrim sysback | AgentProfileEditDialog.tsx:319 AlertDialog: Esc + outside press keep editing (no X) | ok |  |
| `forward-dialog` | dialog | back sysback | x esc scrim sysback | x esc scrim sysback | ForwardComposerDesktop.tsx:61 Modal closeOnBackdrop (md+): X + Esc + backdrop, all inert while sending; ForwardComposerMobile.tsx:201 Back below md | ok |  |
| `composer-expanded-editor` | dialog | x esc scrim sysback drag | x esc scrim sysback | x esc scrim sysback | no Web surface: MessageInput has no expand mode. Flutter-only (GitHub #153): one route whose form follows the window width (RaftPresentationPolicy.editor): a tall bottom sheet below 768 (collapse button, Esc, scrim, back, drag the handle down) and a centered dialog from 768 (collapse button, Esc, scrim, back); every close keeps the draft | no-web |  |
| `community-agreement` | dialog | x esc sysback | x esc sysback | x esc sysback | CommunityAgreementDialog.tsx:49,59 Modal (no backdrop close) + X | ok |  |
| `connected-app-detail` | dialog | x esc sysback | x esc sysback | x esc sysback | SettingsPanel.tsx:6643-6661 Modal (no backdrop close) + CloseButton | ok |  |
| `connected-app-installed-detail` | dialog | x esc sysback | x esc sysback | x esc sysback | SettingsPanel.tsx:6606-6625 Modal (no backdrop close) + CloseButton | ok |  |
| `connected-app-editor` | dialog | x esc sysback | x esc sysback | x esc sysback | SettingsPanel.tsx:6746-6775 Modal (no backdrop close) + CloseButton | ok |  |
| `provider-edit-dialog` | dialog | x esc scrim sysback drag | x esc scrim sysback | x esc scrim sysback | EditProviderConnectionModal.tsx:67 DialogCard: X + Esc, no backdrop close | approved | Below 768 the form is a bottom sheet (RaftPresentationPolicy.form, product-owner approved); from 768 the same centered dialog. X, Esc, Back, a scrim press and (sheet) a drag down all ask the route to close, and a form whose fields changed asks "Discard your changes?" first (an unchanged form just closes); Cancel and Submit never ask |
| `material-alert-dialog` | dialog | esc sysback | esc sysback | esc sysback | no Web modal: the provider assigned-agents / verification result and history lists, the workspace profile card, the one-time credential and the workspace switcher are Flutter presentations (no-web); Esc / system back close, a scrim press does not discard | no-web | scopedDialog / fleet dialogs no longer close on a scrim tap |
| `mention-link-dialog` | dialog | esc scrim sysback | esc scrim sysback | esc scrim sysback | MainLayout.tsx:1369,1410 task Modal closeOnBackdrop: Esc + backdrop (a task link opens the task surface on Web; Flutter shows a summary dialog) | ok |  |
| `workspace-switcher-dialog` | dialog | esc scrim sysback | - (wide layouts open the server switcher popover (server-switcher)) | - (wide layouts open the server switcher popover (server-switcher)) | no Web phone dialog: wide layouts use the server switcher popover (popups family); phones list the workspaces in a SimpleDialog (no-web) | no-web |  |
| `channel-settings-confirm` | dialog | x esc sysback | x esc sysback | x esc sysback | EditChannelDialog.tsx:1579 ConfirmDialog: X + Esc, no pointer dismissal, gated on loading | ok |  |
| `agent-runtime-editor` | dialog | x esc scrim sysback drag | x esc scrim sysback | x esc scrim sysback | AgentDetailPanel.tsx:2094 Modal layer=1 + CloseButton (closeRuntimeConfigEditor): X + Esc, no backdrop close | approved | Below 768 the form is a bottom sheet (RaftPresentationPolicy.form, product-owner approved); from 768 the same centered dialog. X, Esc, Back, a scrim press and (sheet) a drag down all ask the route to close, and a form whose fields changed asks "Discard your changes?" first (an unchanged form just closes); Cancel and Submit never ask; earlier: fleet dialogs stop closing on a scrim tap; the profile Edit runtime config opens AgentRuntimeEditor (legacy fields or the v2 form), which replaced RuntimeFormDialog there |
| `feedback-close-dialog` | dialog | esc sysback | esc sysback | esc sysback | no Web source: the @hands feedback SDK renders the close-ticket AlertDialog (Cancel / Close ticket, no X); Esc and Back cancel, inert while closing | no-web |  |
| `agent-profile-edit-dialog` | dialog | x esc scrim sysback drag | x esc scrim sysback | x esc scrim sysback | AgentProfileEditDialog.tsx:187-201 Dialog: X + Esc + outside press, all through requestClose (discard prompt when dirty) | approved | Below 768 the form is a bottom sheet (RaftPresentationPolicy.form, product-owner approved); from 768 the same centered dialog. X, Esc, Back, a scrim press and (sheet) a drag down all ask the route to close, and a form whose fields changed asks "Discard your changes?" first (an unchanged form just closes); Cancel and Submit never ask; earlier: outside press and every close run requestClose with a discard prompt |
| `agent-reset-dialog` | dialog | x esc sysback | x esc sysback | x esc sysback | ResetAgentDialog.tsx:100-122 ConfirmDialog: X + Esc, no pointer dismissal, gated on loading | fixed | fleet dialogs no longer close on a scrim press |
| `report-issue-dialog` | dialog | x esc scrim sysback drag | x esc scrim sysback | x esc scrim sysback | ReportIssueDialog.tsx:552-559 DialogCard (no closeOnBackdrop): X + Esc, form and submitted states | approved | Below 768 the form is a bottom sheet (RaftPresentationPolicy.form, product-owner approved); from 768 the same centered dialog. X, Esc, Back, a scrim press and (sheet) a drag down all ask the route to close, and a form whose fields changed asks "Discard your changes?" first (an unchanged form just closes); Cancel and Submit never ask |
| `select-field` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | ui/FormField.tsx:1 native <select> / SelectContent: Esc, outside press | ok |  |
| `dropdown-menu` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | layout/Sidebar.tsx:1566 (create-agent menu Esc) + outside press | ok |  |
| `sidebar-context-menu` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | layout/Sidebar.tsx:1761 (Esc) + DismissBackdrop (outside press) | ok |  |
| `sidebar-sort-menu` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | layout/Sidebar.tsx:1540 (Esc) + pointerdown outside | ok |  |
| `server-switcher` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | ui/ServerSwitcherMenu.tsx:279-283 (mousedown outside + Esc) | ok |  |
| `notification-center` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | layout/NotificationTrigger.tsx:55-60 Base UI Popover: Esc, outside press | ok |  |
| `thread-menu` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | message/ThreadOverflowMenu.tsx:24 Base UI Menu: Esc, outside press | ok |  |
| `message-context-menu` | popup | scrim sysback | scrim sysback | scrim sysback | message/MessageItem.tsx:5103-5109 DismissBackdrop (outside press), scroll/resize close | ok |  |
| `toast` | toast | x | x | x | LocalizedToastProvider.tsx:35,61-69 ToastClose unless hasClose === false | fixed | RaftToastPortal renders the Web default toast (icon + close + action); close was ignored in the icon-less layout |
| `selection-toast` | toast | - (Web gives the selection toast no close (auto timeout); asserted in chat_selection_consumer_test) | - (Web gives the selection toast no close (auto timeout); asserted in chat_selection_consumer_test) | - (Web gives the selection toast no close (auto timeout); asserted in chat_selection_consumer_test) | ChatPanel.tsx:117, ThreadPanel.tsx:86 SELECTION_TOAST_OPTIONS dismissible:false; forwardToast.ts:28 hasClose false | fixed | selectionToast.show(dismissible: false) |
| `snackbar` | toast | x | x | x | LocalizedToastProvider.tsx:61-69 (Web has no snackbar; every transient message is a toast with ToastClose) | fixed | theme SnackBarThemeData.showCloseIcon (lead) |
| `reaction-picker` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | message/MessageItem.tsx:4009-4033 pointerdown outside, Esc, scroll, resize | ok |  |
| `thread-followers` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | thread/ThreadAgentFollowers.tsx Base UI Popover: Esc, outside press | fixed | RaftDismissScope: Escape closes the popover with focus still on the trigger |
| `inline-badge-editor` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | InlineBadgeEditor.tsx:173 mousedown outside + DropdownMenuPopup (Esc) | ok |  |
| `agent-overflow-menu` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | agent/AgentProfileOverflowMenu.tsx:108 DropdownMenu (Base UI): Esc, outside press | ok |  |
| `admin-principal-picker` | popup | scrim sysback | scrim sysback | scrim sysback | settings/SettingsPanel.tsx:2626-2638 mousedown outside (no Escape in Web) | ok |  |
| `agent-select` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | agent/RuntimeConfigFields.tsx:32 raft-ui Select (Base UI): Esc, outside press | ok |  |
| `agent-combobox` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | agent/RuntimeChoiceCombobox.tsx Combobox (Base UI): Esc, outside press; the input is the field | ok |  |
| `feedback-close-menu` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | external hands-feedback ReporterCloseSplitButton (not in the Web source tree) | n/a |  |
| `runtime-usage-card` | popup | - (phones open the bottom sheet (dialog family: runtime-usage-sheet)) | x esc scrim sysback | x esc scrim sysback | machine/RuntimeAccountUsageChip.tsx:520-540 pinned popover: Esc, pointerdown outside; CloseButton :234 | fixed | RaftHoverCard: a pinned card closes on Android Back (RaftBackDismiss) |
| `section-emoji-picker` | popup | esc scrim sysback | esc scrim sysback | esc scrim sysback | layout/SidebarSectionEmojiPicker.tsx Popover (Base UI): Esc, outside press; the dialog stays open | ok |  |
| `composer-suggestions` | popup | esc | esc | esc | hooks/useAutocomplete.ts:76 Escape dismisses (no outside-press handler; typing or blur ends the trigger) | ok |  |
| `rail-help-menu` | popup | - (the Help popover hangs off the wide rail only (LeftRail side === left)) | esc scrim sysback | esc scrim sysback | layout/LeftRail.tsx:495-525 Popover (openOnHover): Esc, outside press | ok |  |
| `tooltip` | popup | - (tooltips are pointer-only (docs/parity.md); a touch never opens one) | esc | esc | ui/Tooltip.tsx Base UI Tooltip: Esc (pointer-hover surface) | approved |  |
| `hover-card` | popup | - (hover cards are pointer-only (docs/parity.md); a touch never opens one) | esc scrim | esc scrim | Base UI PreviewCard: pointer-hover surface; Esc and outside press close it | approved |  |
| `message-hover-toolbar` | popup | - (the strip is a hover affordance; touch reaches the same actions through the long-press menu) | - (the strip follows the pointer (hover); Web has no close control) | - (the strip follows the pointer (hover); Web has no close control) | message/MessageItem.tsx:4375 MessageHoverToolbar: follows the pointer, no close control | n/a |  |
| `image-lightbox-timeline` | viewer | back esc sysback | back esc sysback | x esc scrim sysback | ImageLightbox.tsx:267 empty-stage click, ui/Lightbox.tsx:78-95 Esc / Ctrl+W, LightboxClose X | fixed | empty-stage tap closes (AttachmentLightboxImage, lead) |
| `image-lightbox-draft` | viewer | x esc scrim sysback | x esc scrim sysback | x esc scrim sysback | MessageInput.tsx:1733 openDraftImagePreview -> ImageLightbox.tsx:267 empty-stage click, Lightbox.tsx Esc / Ctrl+W, X | fixed | empty-stage tap closes (RaftLightboxStageTap) |
| `image-lightbox-files` | viewer | x esc scrim sysback | x esc scrim sysback | x esc scrim sysback | ChannelFilesPanel.tsx:332 useImageLightboxStore.open -> ImageLightbox.tsx:267 empty-stage click, Esc / Ctrl+W, X | fixed | empty-stage tap closes (RaftLightboxStageTap) |
| `attachment-preview` | viewer | back esc sysback | x esc sysback | x esc sysback | attachmentPreviewSurfaces.tsx:236-325 Esc, Lightbox Ctrl+W, X (CloseButton); document / html / pdf / video / audio share AttachmentPreviewShell | ok |  |
| `attachment-html-preview` | viewer | back esc sysback | x esc sysback | x esc sysback | attachmentPreviewSurfaces.tsx:236-325 (HtmlPreviewBody inside the same AttachmentPreviewShell): Esc, Ctrl+W, X | ok |  |
| `attachment-comments-aside` | drawer | x | x | x | attachmentPreviewSurfaces.tsx:150-170,293 closeComments via the header comment toggle (Preview / Comment segment); phone sheet chevron; no own X | ok |  |
| `mermaid-fullscreen` | viewer | x esc scrim sysback | x esc scrim sysback | x esc scrim sysback | MermaidDiagram.tsx:219-238 Lightbox (Esc, backdrop in the .75rem margin) + LightboxClose | ok |  |
| `image-export-review` | viewer | x esc scrim sysback | x esc scrim sysback | x esc scrim sysback | Lightbox.tsx (Esc, Ctrl+W, backdrop press-then-click) + review Close button | ok |  |
| `task-modern-tasks-route` | panel | back sysback | x esc scrim sysback | x esc scrim sysback | MainLayout.tsx:1364-1376,1172-1185 renderTaskThreadPanel: >=768 centered Modal (closeOnBackdrop, Esc) + TaskModalBar X (task-modal-close); <768 mobile-modal TaskModalBar Back | ok |  |
| `task-modern-channel` | panel | back sysback | x esc scrim sysback | x esc scrim sysback | MainLayout.tsx:1364-1376 taskModalOverlay: same centered Modal / mobile-modal as the Tasks route (the modal is not route dependent) | fixed | Escape reaches the shell scope after a control took focus (dismissInScaffold) |
| `task-legacy-tasks-route` | dialog | back sysback | x esc scrim sysback | x esc scrim sysback | MainLayout.tsx:1407-1416 + LegacyTaskPanel.tsx:55,76-166: >=768 Modal (closeOnBackdrop, Esc) + X (task-close); <768 mobile-modal Back (md:hidden), no X | ok |  |
| `task-legacy-channel` | panel | back sysback | back esc sysback | x esc sysback | LegacyTaskPanel.tsx:84-166 side presentation: Back lg:hidden, X lg:flex, Esc, no backdrop | fixed | Escape reaches the shell scope after a control took focus (dismissInScaffold) |
| `settings-subpage` | page | back sysback | - (wide layouts show the settings navigation beside the page; Web has no close) | - (wide layouts show the settings navigation beside the page; Web has no close) | SettingsPanel.tsx:7906-7924 PanelHeader onMobileBack (md:hidden) to /settings; AboutFeedbackDialog.tsx:219 feedback inbox the same | ok |  |
| `quick-switcher` | dialog | back sysback | esc scrim sysback | esc scrim sysback | SearchOverlay.tsx:41-56 Modal closeOnBackdrop, Escape (wide); MessageSearchPage.tsx:2199 PanelHeader onMobileBack (phone page) | ok |  |
| `computer-detail` | page | back sysback | sysback | sysback | MachineDetailPanel.tsx: PanelHeader Back md:hidden, no desktop X | ok |  |
| `agent-directory-detail` | page | back sysback | sysback | sysback | MainLayout.tsx:565 AgentById (no onBack): AgentDetailPanel Back md:hidden, X only with onClose | ok |  |
| `public-thread-panel` | panel | back sysback | back esc sysback | x esc sysback | PublicServerPage.tsx:668 ThreadPanel side: Back lg:hidden, X lg:flex, Esc | ok |  |
| `feedback-ticket` | page | back sysback | back sysback | back sysback | AboutFeedbackDialog.tsx:196-252 FeedbackWorkspace route=ticket (Back to the inbox inside the @hands workspace); inbox Back md:hidden to Settings | ok |  |
| `feedback-create` | page | back sysback | back sysback | back sysback | AboutFeedbackDialog.tsx:196-252 FeedbackWorkspace route=create (Back to the inbox) | ok |  |
| `agent-migration-page` | page | back sysback | back sysback | back sysback | agentMigration/AgentMigrationDialog.tsx: a Modal (X, Esc); Flutter presents the same flow as a pushed page | approved | native page: raftPageAppBar Back + system back |
| `agent-scopes-page` | page | back sysback | back sysback | back sysback | AgentAppAccessTab.tsx: an inline tab of AgentDetailPanel (no page); Flutter pushes a native page | no-web |  |
| `incoming-share-picker` | page | back sysback | back sysback | back sysback | none: Android share-sheet hand-off, native only | no-web |  |
| `server-setup-gate` | page | - (non-dismissible gate: the workspace is unusable until setup completes) | - (non-dismissible gate: the workspace is unusable until setup completes) | - (non-dismissible gate: the workspace is unusable until setup completes) | onboarding/ServerSetupProjectionGate.tsx: blocks the workspace until setup completes; no close by design | n/a |  |
| `account-onboarding` | page | - (required first-run sequence; every step ends in a decision, not a dismiss) | - (required first-run sequence; every step ends in a decision, not a dismiss) | - (required first-run sequence; every step ends in a decision, not a dismiss) | onboarding flow after sign-up: a required sequence with no close | n/a |  |
<!-- close-table:end -->
