// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the members
// page's external-invite surfaces (the Invited group, its failed read and the
// pinned "Invite people outside" entry) and the details preferences block, at
// Kevin's phone and unfolded-foldable sizes. NOT official cases; ids are
// `components.members-invite.<phone|fold>.<key>.<theme>`.
//
// Each case is the channel-settings drawer case the builder copied
// (tool/parity-ext/build-members-invite.py), with this suite's fixture in place
// of the channel-settings one, exactly as tool/parity-ext/host/MembersInviteCases.tsx
// reuses ParityExtCsView on the React side. The only other difference is
// props.externalFlag, which the drawer case answers in its
// POST /feature-flags/evaluate.
//
// Data: tool/parity-ext/fixtures/members-invite.json
// (fixtures['ext:members-invite']).
import '../parity_harness.dart';
import 'ext_channel_settings.dart' show extChannelSettingsCases;

/// Which channel-settings case each id is built from: `<size>.<key>` ->
/// `<platform>.<state>` (the builder's CASES table).
const _bases = {
  'phone.invited': 'mobile.members-page',
  'fold.invited': 'desktop.members-page',
  'phone.invited-failed': 'mobile.members-page',
  'fold.invited-failed': 'desktop.members-page',
  'phone.prefs': 'mobile.owner',
  'fold.prefs': 'desktop.owner-prefs',
};

ParityCase _case(String base) {
  final from =
      extChannelSettingsCases['components.channelsettings.$base.brutal']!;
  ParityContext swap(ParityContext c) => ParityContext(
    caseJson: c.caseJson,
    fixtures: {
      ...c.fixtures,
      'ext:channelsettings': c.fixtures['ext:members-invite'],
    },
    dark: c.dark,
  );
  return ParityCase(
    widgets: from.widgets,
    notes: 'Extension suite (not official). Base: ${from.notes}',
    settle: from.settle,
    build: (ctx) => from.build(swap(ctx)),
    interact: from.interact == null
        ? null
        : (t, ctx) => from.interact!(t, swap(ctx)),
  );
}

/// Every extension members-invite case Flutter implements, keyed by id
/// (3 themes each).
final Map<String, ParityCase> extMembersInviteCases = {
  // Empty without an extension manifest (extChannelSettingsCases is), e.g. in
  // the official tool/parity run.
  if (extChannelSettingsCases.isNotEmpty)
    for (final MapEntry(key: key, value: base) in _bases.entries)
      for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
        'components.members-invite.$key.$theme': _case(base),
};
