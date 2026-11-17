import 'close_surface.dart';

const _popup = {Affordance.esc, Affordance.scrim, Affordance.systemBack};
const _confirm = {Affordance.x, Affordance.esc, Affordance.systemBack};

const channelAnnouncementSurfaces = <CloseSurface>[
  CloseSurface(
    'channel-details-slack',
    kind: SurfaceKind.dialog,
    web: 'components/channel/ChannelSlackBridgeField.tsx: ConfirmDialog X and Escape',
    webOutside: WebOutside.stays,
    phone: _confirm,
    fold: _confirm,
    desktop: _confirm,
    files: ['lib/features/channel_details_slack.dart'],
  ),
  CloseSurface(
    'channel-announcement-menu',
    kind: SurfaceKind.popup,
    web: 'components/channel/ChannelAnnouncementStrip.tsx: DropdownMenu closes on Escape and outside press',
    phone: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    fold: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    desktop: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    files: ['lib/features/channel_announcement_strip.dart'],
  ),
  CloseSurface(
    'channel-announcement-actions',
    kind: SurfaceKind.popup,
    web: 'components/channel/ChannelAnnouncementField.tsx: DropdownMenu closes on Escape and outside press',
    phone: _popup,
    fold: _popup,
    desktop: _popup,
    files: ['lib/features/channel_announcement_settings.dart'],
  ),
  CloseSurface(
    'channel-announcement-picker',
    kind: SurfaceKind.dialog,
    web: 'components/channel/ChannelAnnouncementField.tsx: ConfirmDialog X, Escape and no outside press',
    webOutside: WebOutside.stays,
    phone: _confirm,
    fold: _confirm,
    desktop: _confirm,
    files: ['lib/features/channel_announcement_settings.dart'],
  ),
  CloseSurface(
    'channel-announcement-confirm',
    kind: SurfaceKind.dialog,
    web: 'components/channel/ChannelAnnouncementField.tsx: ConfirmDialog for replace and remove, X and Escape',
    webOutside: WebOutside.stays,
    phone: _confirm,
    fold: _confirm,
    desktop: _confirm,
    files: ['lib/features/channel_announcement_settings.dart'],
  ),
  CloseSurface(
    'channel-sidebar-section',
    kind: SurfaceKind.popup,
    web: 'components/channel/ChannelSectionSelect.tsx: SelectContent closes on Escape and outside press',
    phone: _popup,
    fold: _popup,
    desktop: _popup,
    files: ['lib/features/channel_section_select.dart'],
  ),
];
