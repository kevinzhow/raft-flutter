import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/features/source_channel_file_glyph.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Fixed Web db5e399f en.ts message.channelFilesPanel jump/download copy.
const _jump = 'Jump to original message';
const _download = 'Download file';
const _trigger = ValueKey('channel-file-overflow-a');
const _popup = ValueKey('channel-file-overflow-menu-a');

// Real Web db5e399f ChannelFileOverflowMenu: the published DropdownMenu
// recipe, not Web MenuItem's product action recipe. Its content is min-w-60,
// p-1.5, and two min-h-9 items; bottom/end with sideOffset4. These assertions
// inspect rendered geometry and real callbacks, without requiring a particular
// canonical widget class to exist.
Finder _menu() => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics && widget.properties.role == SemanticsRole.menu,
);

class _Files {
  var authority = 'current';
  final actions = <({String kind, SourceChannelFileEntry file})>[];
  late final store = SourceChannelFilesStore(
    channelId: 'channel',
    authority: () => authority,
    get: (_, {query}) async => {
      'files': [
        {
          'id': 'a',
          'messageId': 'message',
          'channelId': 'channel',
          'filename': 'Public.txt',
          'mimeType': 'text/plain',
          'sizeBytes': 1024,
          'createdAt': '2026-10-08T01:30:00Z',
          'source': {
            'type': 'channel',
            'channelId': 'channel',
            'parentMessageId': null,
          },
        },
      ],
      'nextCursor': null,
    },
  );

  Future<void> mount(
    WidgetTester tester, {
    bool dark = false,
    TargetPlatform platform = TargetPlatform.linux,
    Size viewport = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = viewport;
    addTearDown(tester.view.reset);
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark).copyWith(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 390,
              child: SourceChannelFilesProjectionView(
                store: store,
                formatCreatedAt: (_) => 'Oct 8, 10:30 AM',
                onPreview: (file) async =>
                    actions.add((kind: 'preview', file: file)),
                onOpenSource: (file) async =>
                    actions.add((kind: 'jump', file: file)),
                onDownload: (file) async =>
                    actions.add((kind: 'download', file: file)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> retire(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    store.dispose();
  }
}

FocusNode _triggerFocus(WidgetTester tester) => tester
    .widget<FocusableActionDetector>(
      find
          .descendant(
            of: find.byKey(_trigger),
            matching: find.byType(FocusableActionDetector),
          )
          .first,
    )
    .focusNode!;

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_trigger));
  await tester.pumpAndSettle();
  expect(find.byKey(_popup), findsOneWidget);
  expect(find.text(_jump).hitTestable(), findsOneWidget);
  expect(find.text(_download).hitTestable(), findsOneWidget);
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets('file overflow published Dropdown geometry; dark=$dark', (
      tester,
    ) async {
      final files = _Files();
      try {
        await files.mount(tester, dark: dark);
        final anchor = tester.getRect(find.byKey(_trigger));
        await _open(tester);
        final popup = tester.getRect(_menu());
        final pin = find.descendant(
          of: _menu(),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ChannelFileGlyph &&
                widget.glyph == SourceChannelFileGlyph.jump,
          ),
        );
        final pinSize = tester.getSize(pin);
        expect(
          popup.width,
          closeTo(240, .01),
          reason:
              'published min-w-60 content; actual trigger=${anchor.size}, '
              'popup=${popup.size}, pin=$pinSize, '
              'rightDelta=${popup.right - anchor.right}, '
              'bottomGap=${popup.top - anchor.bottom}',
        );
        expect(
          popup.height,
          closeTo(84, .01),
          reason: 'p-1.5 plus two min-h-9 rows',
        );
        // Published floating placement rounds the computed popup origin.
        // Its fixed 240px width therefore keeps this end edge integral too.
        expect(
          popup.right,
          closeTo(anchor.right.roundToDouble(), .01),
          reason: 'align=end with published whole-pixel placement',
        );
        expect(
          popup.top,
          closeTo((anchor.bottom + 4).roundToDouble(), .01),
          reason: 'side=bottom and sideOffset4 before whole-pixel placement',
        );
        expect(pinSize, const Size(16, 16));
        expect(
          anchor.size,
          const Size(32, 32),
          reason: 'source ghost icon-sm trigger',
        );
        final more = find.descendant(
          of: find.byKey(_trigger),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ChannelFileGlyph &&
                widget.glyph == SourceChannelFileGlyph.more,
          ),
        );
        expect(
          tester.getSize(more),
          const Size(18, 18),
          reason: 'published Button icon-sm CSS overrides the JSX SVG width attribute',
        );
        expect(files.actions, isEmpty);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text(_jump), findsNothing);
        expect(_triggerFocus(tester).hasFocus, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        await files.retire(tester);
      }
    });
  }

  testWidgets(
    'file overflow keyboard activates distinct typed actions and restores trigger focus',
    (tester) async {
      final files = _Files();
      try {
        await files.mount(tester);
        final file = files.store.files.single;
        final trigger = _triggerFocus(tester)..requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(find.text(_jump).hitTestable(), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(files.actions, [(kind: 'download', file: file)]);
        expect(find.text(_jump), findsNothing);
        expect(trigger.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(files.actions, [
          (kind: 'download', file: file),
          (kind: 'jump', file: file),
        ]);
        expect(trigger.hasFocus, isTrue);
        await tester.tap(find.byKey(const ValueKey('channel-file-preview-a')));
        await tester.pumpAndSettle();
        expect(files.actions.last, (kind: 'preview', file: file));
        expect(files.actions, hasLength(3));
        expect(tester.takeException(), isNull);
      } finally {
        await files.retire(tester);
      }
    },
  );

  testWidgets(
    'file overflow dismisses outside and refuses stale authority without another action',
    (tester) async {
      final files = _Files();
      try {
        await files.mount(tester);
        await _open(tester);
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
        expect(find.text(_jump), findsNothing);
        expect(files.actions, isEmpty);
        await _open(tester);
        files.authority = 'revoked';
        await tester.tap(find.text(_download));
        await tester.pumpAndSettle();
        expect(files.actions, isEmpty);
        expect(find.text(_jump), findsNothing);
        files.store.syncAuthority();
        await tester.pumpAndSettle();
        expect(find.text('Public.txt'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await files.retire(tester);
      }
    },
  );

  for (final size in [const Size(856, 944), const Size(944, 856)]) {
    testWidgets(
      'file overflow touch and unbounded text at $size keeps both actions reachable',
      (tester) async {
        final files = _Files();
        try {
          await files.mount(
            tester,
            platform: TargetPlatform.android,
            viewport: size,
            textScale: 3.1,
          );
          expect(
            tester.getSize(find.byKey(_trigger)).shortestSide,
            greaterThanOrEqualTo(48),
          );
          await _open(tester);
          final popup = tester.getRect(_menu());
          expect(
            popup.height,
            greaterThan(84),
            reason: 'rows grow with content text',
          );
          expect(popup.left, greaterThanOrEqualTo(0));
          expect(popup.right, lessThanOrEqualTo(size.width));
          expect(popup.bottom, lessThanOrEqualTo(size.height));
          await tester.tap(find.text(_download));
          await tester.pumpAndSettle();
          expect(files.actions, [
            (kind: 'download', file: files.store.files.single),
          ]);
          expect(find.text(_jump), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          await files.retire(tester);
        }
      },
    );
  }
}
