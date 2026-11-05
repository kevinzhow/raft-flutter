import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

class NativeGeometry
    implements RaftHtmlRegionController, RaftHtmlNativeRegionController {
  @override
  bool active = true;
  final input = StreamController<RaftHtmlNativeRegionInput>.broadcast(
    sync: true,
  );
  final frames = <RaftHtmlNativeRegionOverlay>[];
  Completer<RaftHtmlRegionLocation?>? pendingCapture;
  final jumps = <RaftHtmlRegion>[];
  final captures = <(Rect, Size)>[];
  final scrolls = <Offset>[];
  @override
  Stream<RaftHtmlNativeRegionInput> get nativeRegionInputs => input.stream;
  @override
  void updateNativeRegionOverlay(RaftHtmlNativeRegionOverlay frame) =>
      frames.add(frame);
  RaftHtmlGeometry shape(Size host) => RaftHtmlGeometry(
    viewport: host,
    visible: host,
    scroll: Offset.zero,
    document: const Size(2000, 3000),
  );
  @override
  Future<RaftHtmlGeometry?> measure(Size host) async => shape(host);
  @override
  Future<RaftHtmlRegionLocation?> capture(Rect local, Size host) async {
    captures.add((local, host));
    if (pendingCapture != null) return pendingCapture!.future;
    return RaftHtmlRegionLocation(
      shape(host),
      RaftHtmlRegion(
        rect: local,
        viewportWidth: host.width,
        document: const Size(2000, 3000),
      ),
    );
  }

  @override
  Future<RaftHtmlRegionLocation?> jump(RaftHtmlRegion region, Size host) async {
    jumps.add(region);
    return RaftHtmlRegionLocation(shape(host), region);
  }

  @override
  Future<RaftHtmlGeometry?> scrollBy(Offset delta, Size host) async {
    scrolls.add(delta);
    return shape(host);
  }

  void send(
    RaftHtmlNativeRegionOverlay frame,
    RaftHtmlNativeRegionPhase phase,
    int sequence,
    Offset position, {
    Offset delta = Offset.zero,
  }) => input.add(
    RaftHtmlNativeRegionInput(
      generation: frame.generation,
      sequence: sequence,
      phase: phase,
      position: position,
      delta: delta,
      viewport: frame.viewport,
    ),
  );
}

Widget nativeFrame(
  RaftAttachmentCommentState session,
  NativeGeometry controller, {
  bool enabled = true,
  bool touch = false,
  ThemeData? theme,
  double textScale = 1,
  bool tickers = true,
}) => MaterialApp(
  theme: (theme ?? raftTheme()).copyWith(
    platform: touch ? TargetPlatform.android : TargetPlatform.linux,
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: TickerMode(enabled: tickers, child: child!),
  ),
  home: Scaffold(
    body: RaftAttachmentCommentScope(
      state: session,
      child: RaftHtmlRegionCommentSurface(
        controller: controller,
        enabled: enabled,
        child: const SizedBox.expand(),
      ),
    ),
  ),
);
