export 'package:raft_client/channel_conversion.dart';

String conversionPhaseLabel(String phase) => switch (phase) {
  'prepare' => 'Preparing conversion',
  'prepare_tasks' ||
  'move_parent_messages' ||
  'prepare_threads' ||
  'move_thread_messages' => 'Preserving messages, files, threads, and tasks',
  'verify' => 'Verifying history',
  'audience_cutover' ||
  'residual_cleanup' ||
  'finalize' => 'Updating server access',
  'done' => 'Conversion complete',
  _ => 'Converting channel',
};
