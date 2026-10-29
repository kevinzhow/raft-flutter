import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/chat_view.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'workspace_source_location_contract_test.dart'
    show pageFixture, mountPage;

void main() {
  for (final platform in [TargetPlatform.linux, TargetPlatform.android]) {
    for (final dm in [false, true]) {
      testWidgets(
        '${platform.name} ${dm ? 'DM' : 'channel'} keeps a reading row across widths',
        (t) async {
          final (w, api) = await pageFixture(t, section: 'chat');
          addTearDown(() async {
            await t.pumpWidget(const SizedBox());
            await t.pump();
          });
          final selected = RaftChannel({
            'id': 'c1',
            'name': 'Reading history',
            'joined': true,
            'type': dm ? 'dm' : 'channel',
            if (dm) 'peerDisplayName': 'Reading peer',
          });
          w.channel = selected;
          w.channels = dm ? [] : [selected];
          w.dms = dm ? [selected] : [];
          final rows = contextRows('width-read', count: 180);
          api.routes['GET /messages/channel/c1'] = (_) => {
            'messages': rows,
            'hasMore': false,
          };
          api.routes['GET /tasks/channel/c1'] = (_) => {'tasks': []};
          api.routes['GET /announcements/active'] = (_) => {
            'announcements': [],
          };
          w.messageDomain.ledger.ingest(
            rows,
            expectedGeneration: w.messageDomain.ledger.generation,
          );
          w.messageDomain.visibleIds['c1'] = rows
              .map((r) => r['id'] as String)
              .toSet();
          w.navigation.navigate(
            RaftLocation.parse('/s/demo/${dm ? 'dm' : 'channel'}/c1'),
          );
          await mountPage(t, w, false, width: 1440);
          final chat = find.byType(RaftChatView).first;
          expect(chat, findsOneWidget);
          final dynamic chatState = t.state(chat);
          final ScrollableState owner = chatState.viewport.position.context;
          Rect bounds() {
            final box = owner.context.findRenderObject()! as RenderBox;
            return box.localToGlobal(Offset.zero) & box.size;
          }

          final center = bounds().center;
          final initialPosition = chatState.viewport.position.pixels as double;
          if (platform == TargetPlatform.linux) {
            await t.sendEventToBinding(
              PointerScrollEvent(
                position: center,
                scrollDelta: const Offset(0, -1800),
              ),
            );
          } else {
            await t.dragFrom(center, const Offset(0, 500));
          }
          await t.pumpAndSettle();
          expect(
            ((chatState.viewport.position.pixels as double) - initialPosition)
                .abs(),
            greaterThan(100),
            reason: 'the real wheel or touch gesture must move into history',
          );
          String? anchor;
          double? anchorTop;
          final beforeBounds = bounds();
          for (final row in rows) {
            final id = row['id'] as String;
            final rect = paintedMessage(t, id);
            if (rect != null &&
                rect.top >= beforeBounds.top &&
                rect.bottom <= beforeBounds.bottom &&
                (anchorTop == null || rect.top < anchorTop)) {
              anchor = id;
              anchorTop = rect.top;
            }
          }
          expect(
            anchor,
            isNotNull,
            reason: 'an older fully visible row must follow the user scroll',
          );
          expect(anchor, isNot('width-read-179'));
          final expectedRoute = w.location.toString();
          for (final size in [
            const Size(390, 844),
            const Size(856, 944),
            const Size(944, 856),
            const Size(1440, 900),
          ]) {
            t.view.physicalSize = size;
            await t.pumpAndSettle();
            expect(w.location.toString(), expectedRoute);
            final rect = paintedMessage(t, anchor!);
            expect(
              rect,
              isNotNull,
              reason: 'reading row $anchor remains painted at $size',
            );
            expect(
              rect!.overlaps(Offset.zero & size),
              isTrue,
              reason: 'reading row remains visible at $size',
            );
            expect(t.takeException(), isNull);
          }
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }
}
