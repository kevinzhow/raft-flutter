import 'package:raft_ui/raft_ui.dart';

import 'computer_detail_view.dart';

/// Web `requestOutcomeStillTrue`: the last upgrade request's `failed` /
/// `no_response` verdict, only while the Computer is still below that
/// request's target. A later manual upgrade makes the line stale.
RaftComputerUpgradeOutcome computerUpgradeRequestOutcome(Map machine) {
  final request = machine['upgradeRequest'];
  if (request is! Map) return RaftComputerUpgradeOutcome.none;
  final state = request['state'];
  if (state != 'failed' && state != 'no_response') {
    return RaftComputerUpgradeOutcome.none;
  }
  final current = machine['computerVersion'];
  final target = request['targetVersion'];
  if (current is! String ||
      target is! String ||
      !isComputerSemver(current) ||
      !isComputerSemver(target) ||
      compareComputerVersions(current, target) >= 0) {
    return RaftComputerUpgradeOutcome.none;
  }
  return state == 'failed'
      ? RaftComputerUpgradeOutcome.failed
      : RaftComputerUpgradeOutcome.noResponse;
}
