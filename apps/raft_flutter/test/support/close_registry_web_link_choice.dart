import 'close_surface.dart';

const _x = Affordance.x,
    _esc = Affordance.esc,
    _scrim = Affordance.scrim,
    _sys = Affordance.systemBack;

/// The "Open links in Raft?" dialog (WP-SIDE: web preview). Its own list and
/// harness file (close_web_link_choice_test.dart) so the dialog parts keep
/// their case budget.
const webLinkChoiceSurfaces = <CloseSurface>[
  CloseSurface(
    'web-link-choice',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.closes,
    web: 'webPreview/WebLinkChoiceDialog.tsx: Dialog size sm, DialogClose X + Esc + an outside press, each is onDismiss: nothing is remembered, the link opens in the browser this time and the next click asks again',
    phone: {_x, _esc, _scrim, _sys},
    fold: {_x, _esc, _scrim, _sys},
    desktop: {_x, _esc, _scrim, _sys},
    files: ['lib/features/web_link_open.dart'],
  ),
];

/// The web page beside the conversation (WP-SIDE: web preview), harnessed in
/// close_web_preview_test.dart.
const webPreviewSurfaces = <CloseSurface>[
  CloseSurface(
    'web-preview',
    kind: SurfaceKind.panel,
    web: 'webPreview/WebPreviewPanel.tsx: X in the head (hidden when covering), Back when it covers the conversation on a phone (usePhoneHistoryEntry: the system Back closes it), Esc (handleKeyDown) with focus moved into the panel',
    phone: {Affordance.back, _esc, _sys},
    fold: {_x, _esc},
    desktop: {_x, _esc},
    files: ['lib/features/channel_side_web_preview_panel.dart'],
  ),
];
