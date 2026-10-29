import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import '../message_presentation_test.dart' show MessageAdapter;
import 'close_support.dart';

/// The no-wait-UI guard: with the data already local (the fixture preloads the
/// workspace directory) the network goes dead, [open] is started, and the
/// surface must be on screen within [settle] frames, without the request that
/// used to gate it ever completing.
///
/// [open] receives a context under the workspace view. Returns the count of
/// requests that were held, for callers that also assert none were needed.
Future<int> expectOpensWithoutNetwork(
  WidgetTester t,
  WorkspaceController w,
  MessageAdapter api, {
  required Future<void> Function(BuildContext context) open,
  required Finder surface,
  int settle = 6,
}) async {
  api.hangAll = true;
  final before = api.hung;
  unawaited(open(t.element(find.byType(WorkspaceView))));
  await frames(t, settle);
  expect(
    surface,
    findsWidgets,
    reason: 'the surface must not wait for the network',
  );
  final held = api.hung - before;
  api.hangAll = false;
  return held;
}
