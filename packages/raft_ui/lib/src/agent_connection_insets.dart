import 'package:flutter/widgets.dart';

/// Web's GitHub connection card (`components/agent/AgentConnections.tsx`,
/// `GithubConnectAccountDialog.tsx`) spacing that has no wider owner: the card's
/// `p-3`, a radio choice's `py-2` row and the `mt-0.5` that lines its circle up
/// with the first line of text.
abstract final class RaftAgentConnectionInsets {
  /// `Card className="p-3"`.
  static const EdgeInsets card = EdgeInsets.all(12);

  /// `label className="flex min-h-11 items-start gap-3 py-2"`.
  static const EdgeInsets accessRow = EdgeInsets.symmetric(vertical: 8);

  /// `RadioGroupItem className="mt-0.5"` and the `Info` icon's `mt-0.5`.
  static const EdgeInsets firstLine = EdgeInsets.only(top: 2);
}
