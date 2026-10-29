import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart' show raftText;

/// Web `RuntimeFormV2SourceStatusLine`: why a field's option source is not
/// live (`option_source.status` + `reason`). An unknown reason gets the generic
/// line; a `fallback` source adds that the standard list is shown instead.
String runtimeSourceStatusText(
  BuildContext context, {
  required String status,
  Object? reason,
}) {
  final why = raftText(context, switch (reason) {
    'probe_timeout' => 'This Computer took too long to list the options.',
    'probe_failed' => 'This Computer could not list the options.',
    'missing_config' => 'This runtime needs configuration on this Computer before it can list the options.',
    'no_models' => 'This Computer reported no available options.',
    'unsupported' => 'This Computer cannot list the options for this runtime.',
    'machine_offline' => 'This Computer is offline.',
    _ => 'The options could not be loaded.',
  });
  return status == 'fallback'
      ? '$why ${raftText(context, 'Showing the standard list instead.')}'
      : why;
}
