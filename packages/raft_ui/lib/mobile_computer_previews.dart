import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'previews.dart';
import 'raft_ui.dart';

@Preview(
  name: 'Computers · Light',
  group: 'Mobile computers',
  wrapper: lightWrapper,
  size: Size(390, 844),
)
@Preview(
  name: 'Computers · Dark',
  group: 'Mobile computers',
  wrapper: darkWrapper,
  size: Size(390, 844),
)
Widget mobileComputersPreview() => const _ComputersPreview();

@RaftPreviews(
  'Computer directory · long list with bottom inset',
  size: Size(390, 844),
)
Widget computerDirectoryInsetPreview() => Builder(
  builder: (context) {
    final metrics = MediaQuery.of(context);
    return MediaQuery(
      data: metrics.copyWith(
        padding: metrics.padding.copyWith(bottom: 48),
        viewPadding: metrics.viewPadding.copyWith(bottom: 48),
      ),
      child: Column(
        children: [
          const RaftMobileRootHeader(title: 'Computers'),
          Expanded(
            child: RaftMobileComputerList(
              emptyTitle: 'No computers yet',
              emptyDetail: 'Add a computer',
              addLabel: 'Add Computer',
              retryLabel: 'Retry',
              rows: [
                for (var i = 1; i <= 16; i++)
                  RaftComputerRow(
                    mobile: true,
                    name: 'Computer $i',
                    description: 'Shared development machine',
                    runLabel: 'Online',
                    offline: false,
                    dot: RaftComputerDot.online,
                    onTap: () {},
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  },
);

class _ComputersPreview extends StatefulWidget {
  const _ComputersPreview();
  @override
  State<_ComputersPreview> createState() => _ComputersPreviewState();
}

class _ComputersPreviewState extends State<_ComputersPreview> {
  String state = 'loaded', result = 'Computers';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      RaftMobilePageHeader(
        title: Text(result),
        onBack: () => setState(() => result = 'Back'),
      ),
      Wrap(
        children: [
          for (final option in ['loaded', 'loading', 'empty', 'error'])
            RaftButton.text(
              onPressed: () => setState(() => state = option),
              child: Text(option),
            ),
        ],
      ),
      Expanded(
        child: RaftMobileComputerList(
          loading: state == 'loading',
          error: state == 'error' ? 'Directory could not be loaded.' : null,
          emptyTitle: 'No computers yet',
          emptyDetail: 'Add a computer to run agents in this server.',
          retryLabel: 'Retry',
          addLabel: 'Add Computer',
          onRetry: () => setState(() => state = 'loaded'),
          onAdd: () => setState(() => result = 'Add Computer'),
          rows: state == 'empty' || state == 'loading'
              ? []
              : [
                  for (final dot in RaftComputerDot.values)
                    RaftComputerRow(
                      mobile: true,
                      name: '${dot.name} Computer',
                      description: 'Shared development machine',
                      runLabel: dot == RaftComputerDot.offline
                          ? 'Offline'
                          : 'Computer v1.0.44',
                      offline: dot == RaftComputerDot.offline,
                      dot: dot,
                      availableVersion: dot == RaftComputerDot.upgrade
                          ? '1.0.45'
                          : null,
                      diskLow: dot == RaftComputerDot.online,
                      onTap: () => setState(() => result = dot.name),
                    ),
                ],
        ),
      ),
    ],
  );
}
