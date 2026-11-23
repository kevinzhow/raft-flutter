import 'package:flutter/foundation.dart';

const traceTimelineRows =
    kProfileMode && bool.fromEnvironment('RAFT_LAB_PHASES');

Result timelineRowTrace<Result>(
  String phase,
  String row,
  Result Function() work,
) => traceTimelineRows && FlutterTimeline.debugCollectionEnabled
    ? FlutterTimeline.timeSync('raft.row.$phase:$row', work)
    : work();
