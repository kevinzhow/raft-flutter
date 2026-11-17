import 'close_surface.dart';

const _x = Affordance.x, _esc = Affordance.esc, _sys = Affordance.systemBack;

/// The Free-plan limit notice (WP-BILL part C). Its own list and harness file
/// (close_limit_notice_test.dart) so the dialog parts keep their case budget.
const limitNoticeSurfaces = <CloseSurface>[
  CloseSurface(
    'limit-notice',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web: 'billing/UpgradeDialog.tsx: Dialog disablePointerDismissal, DialogClose X (common.close) + Esc; the app shows the dialog header words with one Upgrade to Pro and Close',
    phone: {_x, _esc, _sys},
    fold: {_x, _esc, _sys},
    desktop: {_x, _esc, _sys},
    files: ['lib/features/limit_notice.dart'],
  ),
];
