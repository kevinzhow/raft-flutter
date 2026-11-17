import 'close_surface.dart';

const _x = Affordance.x,
    _esc = Affordance.esc,
    _scrim = Affordance.scrim,
    _sys = Affordance.systemBack,
    _drag = Affordance.drag;

/// The human avatar builder (Web `HumanAvatarBuilderDialog`, a raft-ui
/// `Dialog` with `DialogSheetContent`): Esc, the X and the scrim close it
/// unless a save is in flight; Cancel closes it too.
const humanAvatarSurfaces = <CloseSurface>[
  CloseSurface(
    'human-avatar-builder',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.closes,
    web:
        'member/HumanAvatarBuilderDialog.tsx:249-391 Dialog onOpenChange (X, Esc, scrim; '
        'refused while saving) + DialogSheetContent (a sheet on a phone)',
    phone: {_x, _esc, _scrim, _sys, _drag},
    fold: {_x, _esc, _scrim, _sys},
    desktop: {_x, _esc, _scrim, _sys},
    files: [
      'lib/features/human_avatar_builder_dialog.dart',
      'lib/features/human_avatar_edit_menu.dart',
    ],
    status: 'approved',
    fix:
        'Below 768 the form is a bottom sheet (RaftPresentationPolicy.form, '
        'product-owner approved); from 768 the same centered dialog. X, Esc, '
        'Back, a scrim press and (sheet) a drag down all ask the route to '
        'close; PopScope refuses them while a save is in flight',
  ),
];
