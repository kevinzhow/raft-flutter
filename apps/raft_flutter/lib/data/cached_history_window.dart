import 'dart:collection';

import 'message_history.dart';

/// A local snapshot can prove that no reading position needs restoring.
/// This proof is process metadata and is never serialized into cached JSON.
class CachedHistoryWindow extends MapView<String, dynamic> {
  CachedHistoryWindow(
    super.map, {
    required this.scope,
    required this.positionAbsent,
    required this.positionsUnchanged,
    required this.current,
  });

  final MessageHistoryScope scope;
  final bool positionAbsent;
  final bool Function() positionsUnchanged, current;

  bool provesNoPosition(MessageHistoryScope receiver) =>
      positionAbsent &&
      (
            scope.origin,
            scope.principal,
            scope.server,
            scope.channel,
            scope.parentChannel,
            scope.authority,
          ) ==
          (
            receiver.origin,
            receiver.principal,
            receiver.server,
            receiver.channel,
            receiver.parentChannel,
            receiver.authority,
          ) &&
      positionsUnchanged() &&
      current();
}
