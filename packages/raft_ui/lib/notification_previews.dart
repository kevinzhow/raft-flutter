import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/design_primitives.dart';
import 'src/icons.dart';
import 'src/notification_center.dart';
import 'src/theme.dart';

@RaftPreviews('Source notification center empty', size: Size(640, 480))
Widget notificationCenterEmptyPreview() => const RaftDensityScope(
  density: RaftDensity.desktop,
  child: Center(child: RaftNotificationCenter(entries: [])),
);

@RaftPreviews('Source notification center actions', size: Size(640, 480))
Widget notificationCenterActionsPreview() =>
    const _NotificationInteractionPreview();

@RaftPreviews(
  'Source notification center Computer fixture',
  size: Size(412, 480),
)
Widget notificationCenterComputerPreview() =>
    const _NotificationComputerPreview();

@RaftPreviews('Source notification center touch', size: Size(412, 480))
Widget notificationCenterTouchPreview() =>
    const _NotificationInteractionPreview(density: RaftDensity.touch);

@RaftPreviews('Source notification center long text', size: Size(412, 640))
Widget notificationCenterLongPreview() => const _NotificationInteractionPreview(
  density: RaftDensity.touch,
  textScale: 1.6,
  longText: true,
);

@RaftPreviews('Source notification attention', size: Size(640, 480))
Widget notificationAttentionPreview() => const _NotificationAttentionPreview();

class _NotificationInteractionPreview extends StatefulWidget {
  const _NotificationInteractionPreview({
    this.density = RaftDensity.desktop,
    this.textScale = 1,
    this.longText = false,
  });
  final RaftDensity density;
  final double textScale;
  final bool longText;
  @override
  State<_NotificationInteractionPreview> createState() =>
      _NotificationInteractionPreviewState();
}

class _NotificationInteractionPreviewState
    extends State<_NotificationInteractionPreview> {
  var planVisible = true;
  var lastAction = 'None';
  void record(String action) => setState(() => lastAction = action);
  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(widget.textScale)),
    child: RaftDensityScope(
      density: widget.density,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftNotificationCenter(
              autofocus: true,
              onDismiss: () => record('Escape'),
              entries: [
                if (planVisible)
                  RaftNotificationEntry(
                    id: 'plan',
                    kind: RaftNotificationKind.info,
                    title: 'Plan changed',
                    bodyContent: const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'The '),
                          TextSpan(
                            text: 'Pro plan',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: ' has changed. Review your workspace limits.',
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      RaftNotificationAction(
                        label: 'View',
                        primary: true,
                        onPressed: () => record('View plan'),
                      ),
                      RaftNotificationAction(
                        label: 'Dismiss',
                        onPressed: () => setState(() {
                          planVisible = false;
                          lastAction = 'Dismiss plan';
                        }),
                      ),
                    ],
                  ),
                RaftNotificationEntry(
                  id: 'agent',
                  kind: RaftNotificationKind.error,
                  title: 'Agent offline',
                  body: 'An active agent is no longer connected.',
                  actions: [
                    RaftNotificationAction(
                      label: 'View',
                      primary: true,
                      onPressed: () => record('View agent'),
                    ),
                  ],
                ),
                RaftNotificationEntry(
                  id: 'computer',
                  kind: RaftNotificationKind.warning,
                  glyph: RaftGlyph.monitor,
                  title: widget.longText
                      ? 'Computer update available for a workstation with a long descriptive name'
                      : 'Computer update available',
                  body: widget.longText
                      ? 'Open the details to review its current status and the available update. '
                            '服务器与账号的提醒内容保持原始顺序。'
                      : 'Review the update before applying it.',
                  actions: [
                    RaftNotificationAction(
                      label: 'View',
                      primary: true,
                      onPressed: () => record('View computer'),
                    ),
                    const RaftNotificationAction(
                      label: 'Unavailable',
                      enabled: false,
                    ),
                  ],
                ),
                RaftNotificationEntry(
                  id: 'feedback',
                  kind: RaftNotificationKind.info,
                  glyph: RaftGlyph.messageSquare,
                  title: 'Feedback updates',
                  body: 'You have unread product feedback replies.',
                  actions: [
                    RaftNotificationAction(
                      label: 'View',
                      primary: true,
                      onPressed: () => record('View feedback'),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              'Preview action: $lastAction',
              key: const Key('notification-preview-action'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NotificationAttentionPreview extends StatefulWidget {
  const _NotificationAttentionPreview();
  @override
  State<_NotificationAttentionPreview> createState() =>
      _NotificationAttentionPreviewState();
}

class _NotificationAttentionPreviewState
    extends State<_NotificationAttentionPreview> {
  var count = 0;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftNotificationAttention(count: count),
        RaftControl(
          semanticLabel: count == 0
              ? 'Show attention mark'
              : 'Clear attention mark',
          onPressed: () => setState(() => count = count == 0 ? 3 : 0),
          child: Text(
            count == 0 ? 'Show attention mark' : 'Clear attention mark',
          ),
        ),
        Text('$count notifications'),
      ],
    ),
  );
}

// Matches the public original Home bell's measured one-row DOM receipt.
class _NotificationComputerPreview extends StatefulWidget {
  const _NotificationComputerPreview();
  @override
  State<_NotificationComputerPreview> createState() =>
      _NotificationComputerPreviewState();
}

class _NotificationComputerPreviewState
    extends State<_NotificationComputerPreview> {
  var dismissed = false;
  var lastAction = 'None';
  @override
  Widget build(BuildContext context) => RaftDensityScope(
    density: RaftDensity.desktop,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftNotificationCenter(
            autofocus: true,
            onDismiss: () => setState(() => lastAction = 'Escape'),
            entries: [
              if (!dismissed)
                RaftNotificationEntry(
                  id: 'computers',
                  iconForeground: RaftTokens.of(context)
                      .colors['foreground-strong'],
                  kind: RaftNotificationKind.warning,
                  glyph: RaftGlyph.monitor,
                  title: 'Computers need attention',
                  body: '1 needs upgrade · 1 offline',
                  actions: [
                    RaftNotificationAction(
                      label: 'View',
                      primary: true,
                      onPressed: () =>
                          setState(() => lastAction = 'View computers'),
                    ),
                    RaftNotificationAction(
                      label: 'Dismiss',
                      onPressed: () => setState(() {
                        dismissed = true;
                        lastAction = 'Dismiss computers';
                      }),
                    ),
                  ],
                ),
            ],
          ),
          Text(
            'Preview action: $lastAction',
            key: const Key('notification-preview-action'),
          ),
        ],
      ),
    ),
  );
}
