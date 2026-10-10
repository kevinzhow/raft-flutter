import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_ui/raft_ui.dart';

import 'native_control.dart';

/// Uploads known inert fixture content. The native renderer never executes
/// attachment scripts; external browser execution remains an explicit action.
Future<void> verifyHtmlPreview(
  WidgetTester tester,
  WorkspaceController w,
  Future<void> Function(String) capture,
) async {
  final marker = DateTime.now().microsecondsSinceEpoch;
  final filename = 'native-html-$marker.html';
  final data = Uint8List.fromList(
    utf8.encode(
      '''<!doctype html>
<html><head><meta charset="utf-8"><title>Native HTML fixture</title></head>
<body><h1>HTML review $marker</h1><p><strong>中文</strong> and 日本語</p>
<table><tr><th>Step</th><th>Status</th></tr><tr><td>Review</td><td>Ready</td></tr></table>
<img src="https://example.com/no-request.png" alt="Interactive diagram">
<script>document.body.dataset.verified='browser-only';</script></body></html>''',
    ),
  );
  final channelId = w.channel!.id;
  final attachments = await w.client.upload(channelId, data, filename);
  data.fillRange(0, data.length, 0);
  final attachmentId = attachments.single['id'] as String;
  final body = 'Native HTML attachment $marker';
  expect(await w.send(body, attachments: [attachmentId]), isTrue);
  final message = w.messages.singleWhere((m) => m.content == body);
  await w.jumpToMessage(channelId, message.id);
  final tile = find.byKey(ValueKey('message-${message.id}'));
  final target = find.descendant(of: tile, matching: find.text(filename));
  final visible = await revealNativeControl(tester, target);
  expect(visible, findsOneWidget);
  await tester.tapAt(tester.getCenter(visible));
  final viewer = find.byType(HtmlAttachmentPreviewDialog);
  for (
    var i = 0;
    i < 150 && find.byType(RaftHtmlPreview).evaluate().isEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(viewer, findsOneWidget);
  expect(find.byType(RaftHtmlPreview), findsOneWidget);
  expect(find.text('HTML review $marker', findRichText: true), findsOneWidget);
  expect(
    find.text('[Image: Interactive diagram]', findRichText: true),
    findsOneWidget,
  );
  expect(find.text('Open interactive preview in browser'), findsOneWidget);
  expect(tester.takeException(), isNull);
  await capture('linux-html-native-preview');
  await tester.tap(
    find.descendant(of: viewer, matching: find.byTooltip('Close preview')),
  );
  await tester.pump(const Duration(milliseconds: 400));
  expect(viewer, findsNothing);
}
