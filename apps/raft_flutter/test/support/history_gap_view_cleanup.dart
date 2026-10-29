import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import '../history_memory_test.dart' show HistoryClient;
import '../history_memory_viewport_test.dart' show drainIo;

/// Releases every owner even if an earlier flush fails, preserving its error.
Future<void> closeGapView(
  WidgetTester t,
  WorkspaceController w,
  HistoryClient client,
  DriftWorkspaceCache db, {
  Future<void> Function()? flush,
}) async {
  Object? failure;
  StackTrace? stack;
  Future<void> attempt(FutureOr<void> Function() action) async {
    try {
      await action();
    } catch (error, trace) {
      failure ??= error;
      stack ??= trace;
    }
  }

  await attempt(() => t.pumpWidget(const SizedBox.shrink()));
  await attempt(() => drainIo(t, (flush ?? w.flushCache)()));
  await attempt(w.dispose);
  await attempt(() => drainIo(t, db.messageHistory.reads.settled));
  await attempt(() => drainIo(t, client.arrivals.close()));
  await attempt(() => drainIo(t, client.dispose()));
  await attempt(() => drainIo(t, db.close()));
  if (failure != null) Error.throwWithStackTrace(failure!, stack!);
}
