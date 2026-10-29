// Indicator specimens (specimens.tsx: BadgeVariants, StatusLights, AvatarFaces, AvatarSizes, AvatarPresence,
// IconTileVariants).
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support.dart';

final Map<String, RaftSpecimenBuilder> raftIndicatorSpecimens = {
  'badge.variants': _badgeVariants,
  'status.lights': _statusLights,
  'avatar.faces': _avatarFaces,
  'avatar.sizes': _avatarSizes,
  'avatar.presence': _avatarPresence,
  'icon-tile.variants': _iconTileVariants,
};

// BADGE_VARIANTS order of specimens.tsx.
const _badgeOrder = [
  (RaftBadgeRecipeVariant.default_, 'default'),
  (RaftBadgeRecipeVariant.primary, 'primary'),
  (RaftBadgeRecipeVariant.accent, 'accent'),
  (RaftBadgeRecipeVariant.warning, 'warning'),
  (RaftBadgeRecipeVariant.danger, 'danger'),
  (RaftBadgeRecipeVariant.information, 'information'),
  (RaftBadgeRecipeVariant.success, 'success'),
  (RaftBadgeRecipeVariant.muted, 'muted'),
];

Widget _badgeVariants(BuildContext context, RaftTokens t) => specimenStack([
  // The unread count and the @ marker: the two jobs Badge exists for.
  specimenRow([
    const RaftBadge(
      label: '1',
      variant: RaftBadgeRecipeVariant.accent,
      semanticLabel: '1 unread',
    ),
    const RaftBadge(
      label: '12',
      variant: RaftBadgeRecipeVariant.accent,
      semanticLabel: '12 unread',
    ),
    const RaftBadge(
      glyph: RaftGlyph.atSign,
      variant: RaftBadgeRecipeVariant.primary,
      semanticLabel: 'Mentions you',
    ),
  ]),
  for (final appearance in RaftBadgeRecipeAppearance.values)
    specimenRow([
      for (final (variant, name) in _badgeOrder)
        RaftBadge(label: name, appearance: appearance, variant: variant),
    ]),
]);

Widget _statusLights(BuildContext context, RaftTokens t) => specimenStack([
  specimenRow([const RaftStatus()]),
  specimenRow([
    for (final p in RaftPresence.values)
      RaftStatus(presence: p, semanticLabel: p.name),
  ]),
  specimenRow([
    for (final s in RaftStatusSize.values)
      RaftStatus(
        size: s,
        presence: RaftPresence.online,
        semanticLabel: 'Online',
      ),
  ]),
  specimenRow([
    for (final (_, name) in _badgeOrder)
      RaftStatus(variant: _statusVariant(name)),
  ]),
  // Agent state chips: a soft Badge holding a Status with its presence and word.
  specimenRow([
    for (final (presence, word) in const [
      (RaftPresence.online, 'Online'),
      (RaftPresence.busy, 'Working'),
      (RaftPresence.error, 'Error'),
      (RaftPresence.offline, 'Offline'),
      (RaftPresence.external, 'External agent'),
    ])
      RaftBadge(
        appearance: RaftBadgeRecipeAppearance.soft,
        leading: RaftStatus(presence: presence),
        label: word,
      ),
  ]),
]);

RaftStatusVariant _statusVariant(String name) => switch (name) {
  'primary' => RaftStatusVariant.primary,
  'accent' => RaftStatusVariant.accent,
  'warning' => RaftStatusVariant.warning,
  'danger' => RaftStatusVariant.danger,
  'information' => RaftStatusVariant.information,
  'success' => RaftStatusVariant.success,
  'muted' => RaftStatusVariant.muted,
  _ => RaftStatusVariant.default_,
};

Widget _agentFace(String key, RaftAvatarSize size) => RaftAvatar(
  name: key,
  kind: RaftAvatarKind.agent,
  uiSize: size,
  content: RaftAvatarContent(
    name: key,
    kind: RaftAvatarContentKind.agent,
    pixelKey: key,
  ),
);

Widget _gap(double w) => SizedBox(width: w);

Widget _endRow(List<Widget> children, double gap) => Row(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) _gap(gap),
      children[i],
    ],
  ],
);

Widget _avatarFaces(BuildContext context, RaftTokens t) => specimenStack([
  specimenRow([
    for (final key in const ['robot', 'crown', 'mushroom'])
      _agentFace(key, RaftAvatarSize.lg),
    // AvatarPreviewContent: an agent whose pixel avatar has not loaded
    const RaftStickerAvatar(
      size: RaftAvatarSize.lg,
      type: RaftAvatarType.agent,
      badge: RaftAvatarBadge(
        size: RaftAvatarSize.lg,
        variant: RaftStatusVariant.success,
      ),
    ),
  ]),
  specimenRow([
    const RaftAvatar(name: 'Mia Chen', uiSize: RaftAvatarSize.lg),
    const RaftAvatar(name: 'Anna', uiSize: RaftAvatarSize.lg),
    // AvatarPanelHeaderContent without the photo: the placeholder icon
    const RaftAvatar(name: '', uiSize: RaftAvatarSize.lg),
    const RaftAvatar(
      name: 'Wug',
      kind: RaftAvatarKind.agent,
      uiSize: RaftAvatarSize.lg,
    ),
  ]),
]);

const _sizeOrder = [
  RaftAvatarSize.xs,
  RaftAvatarSize.sm,
  RaftAvatarSize.md,
  RaftAvatarSize.lg,
  RaftAvatarSize.xl,
];

Widget _avatarSizes(BuildContext context, RaftTokens t) => specimenStack([
  _endRow([for (final s in _sizeOrder) _agentFace('crown', s)], 16),
  _endRow([
    for (final s in _sizeOrder) RaftAvatar(name: 'Mia Chen', uiSize: s),
  ], 16),
]);

Widget _avatarPresence(BuildContext context, RaftTokens t) => _endRow([
  for (final (letter, type, presence) in const [
    ('W', RaftAvatarType.agent, RaftPresence.online),
    ('B', RaftAvatarType.agent, RaftPresence.busy),
    ('M', RaftAvatarType.agent, RaftPresence.error),
    ('MC', RaftAvatarType.human, RaftPresence.offline),
    ('R', RaftAvatarType.agent, RaftPresence.external),
  ])
    RaftStickerAvatar(
      size: RaftAvatarSize.md,
      type: type,
      presence: presence,
      child: RaftAvatarInitials(letter, size: RaftAvatarSize.md),
    ),
], 24);

Widget _iconTileVariants(BuildContext context, RaftTokens t) => specimenStack([
  // IconTileSizesComposition
  Row(
    children: [
      for (var i = 0; i < RaftIconTileSize.values.length; i++) ...[
        if (i > 0) _gap(16),
        RaftIconTile(
          glyph: RaftGlyph.appWindow,
          size: RaftIconTileSize.values[i],
        ),
      ],
    ],
  ),
  // IconTileVariantsComposition
  Row(
    children: [
      const RaftIconTile(glyph: RaftGlyph.appWindow, semanticLabel: 'App'),
      _gap(16),
      const RaftIconTile(
        glyph: RaftGlyph.octagonAlert,
        variant: RaftIconTileVariant.warning,
        semanticLabel: 'Error',
      ),
      _gap(16),
      const RaftIconTile(
        glyph: RaftGlyph.info,
        variant: RaftIconTileVariant.information,
        semanticLabel: 'Message',
      ),
    ],
  ),
]);
