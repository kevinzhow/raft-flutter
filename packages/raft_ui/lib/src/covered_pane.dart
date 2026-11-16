import 'package:flutter/widgets.dart';

/// Whether a panel of the same route now covers this pane: the folded profile
/// over the conversation, or the profile over the thread column.
///
/// A row's hover toolbar floats in the route's overlay, above every pane, so
/// it would paint and take hits over the covering panel. Web keeps the toolbar
/// in its row's stacking context, so the panel covers it and the row loses
/// `:hover`; rows under a covered pane put their toolbar away to match.
class RaftCoveredPane extends InheritedWidget {
  const RaftCoveredPane({
    super.key,
    required this.covered,
    required super.child,
  });
  final bool covered;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftCoveredPane>()?.covered ??
      false;

  @override
  bool updateShouldNotify(RaftCoveredPane old) => covered != old.covered;
}
