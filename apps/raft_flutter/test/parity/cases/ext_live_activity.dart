// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the live
// agent activity bar ("what the bot is doing now") in its two Web placements.
// Ids `components.liveactivity.<platform>.<kind>.<theme>`, dispatched on
// props.platform / activity / text like tool/parity-ext/host/LiveActivityCases.tsx.
//
//   desktop -> the workspace sidebar bottom slot (240 wide column, canvas
//              background, `border-r`)
//   mobile  -> the mobile bottom bar stack (390 wide; elegant floats over the
//              canvas, brutal sits in flow over white)
//
// The capture crop is the bar itself (`capture.androidKey`).
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';

Widget _bar(ParityContext ctx) {
  final agents = ctx.fixtureData['agents'] as Map<String, dynamic>;
  final cindy = agents['cindy'] as Map<String, dynamic>;
  return LegacyBar(
    name: '${cindy['displayName']}',
    text: '${ctx.props['text']}',
  );
}

Widget _build(ParityContext ctx) => Builder(
  builder: (context) {
    final t = RaftTokens.of(context);
    final mobile = ctx.props['platform'] == 'mobile';
    final bar = _bar(ctx);
    return Align(
      alignment: Alignment.topLeft,
      child: ctx.target(
        mobile
            ? ColoredBox(
                color: t.brutal ? Colors.white : t.sidebar,
                child: SizedBox(
                  width: ctx.width,
                  height: ctx.height,
                  child: Align(alignment: Alignment.bottomCenter, child: bar),
                ),
              )
            : SizedBox(
                width: ctx.width,
                height: ctx.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.brutal ? t.product.brutalCream : t.sidebar,
                    border: Border(
                      right: BorderSide(
                        color: t.brutal ? Colors.black : t.colors['line-muted']!,
                        width: t.brutal ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Align(alignment: Alignment.bottomCenter, child: bar),
                ),
              ),
      ),
    );
  },
);

ParityCase _case() => ParityCase(
  widgets: const ['raft_flutter:NativeLiveAgentActivityBar'],
  notes: 'Extension suite (not official).',
  settle: const Duration(milliseconds: 300),
  build: _build,
);

const _keys = {
  'desktop': ['tool-finished', 'working', 'thinking', 'compacting', 'long'],
  'mobile': ['tool-finished', 'thinking', 'long'],
};

/// Every extension live activity case, keyed by id (3 themes each).
final Map<String, ParityCase> extLiveActivityCases = {
  for (final MapEntry(key: platform, value: kinds) in _keys.entries)
    for (final kind in kinds)
      for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
        'components.liveactivity.$platform.$kind.$theme': _case(),
};

class LegacyBar extends StatelessWidget {
  const LegacyBar({super.key, required this.name, required this.text});
  final String name, text;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      key: const Key('live-agent-activity-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          RaftAvatar(name: name, kind: RaftAvatarKind.agent, size: 20),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xffffd440),
              shape: BoxShape.circle,
              border: Border.all(
                color: t.brutal ? t.strong : Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RaftTypography.body(t, size: 12, line: 16, color: t.strong),
            ),
          ),
        ],
      ),
    );
  }
}
