import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/message_window_snapshot.dart';

import '../integration_test/perf_lab/fixtures.dart';
import '../integration_test/perf_lab_test.dart' as lab;

void main() {
  test('phone fixture selects the bottom navigation its entry actions require', () {
    expect(RaftWindowClass.phoneNavigationFor(const Size(390, 640)),
        RaftNavigationPlacement.rail);
    expect(RaftWindowClass.phoneNavigationFor(lab.detectionPhoneSize),
        RaftNavigationPlacement.bottom);
    expect(lab.detectionPhoneSize.height, lessThanOrEqualTo(720));
  });
  lab.registerActivityArrivalTest();
  lab.registerRebuildCounterControlTest();
  testWidgets(
    'arrival observes the visible portion of a tall row but excludes an offscreen row',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: 100,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(
                        key: ValueKey('message-tall'),
                        width: 300,
                        height: 2000,
                        child: ColoredBox(color: Colors.blue),
                      ),
                      const SizedBox(
                        key: ValueKey('message-offscreen'),
                        width: 300,
                        height: 100,
                        child: ColoredBox(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final evidence = lab.detectionEvidence(t, 'older-drag', {
        'olderPagesServed': 1,
        'rowsBefore': 50,
        'rowsAfter': 100,
      });
      final arrival = evidence['arrival']! as Map;
      expect(arrival['visibleKeys'], ['message-tall']);
      expect(arrival['arrived'], true);
    },
  );
  test(
    'lab history page honors the transport limit and preserves full history',
    () async {
      final channel = LabChannel('mix', mixKinds(600));
      final first = await channel.page(
        RequestOptions(
          path: '/messages/channel/mix',
          queryParameters: {'limit': 50},
        ),
      );
      final accepted = acceptedWindowRows(first['messages'], 'mix');
      expect(accepted, hasLength(50));
      expect(first['hasMore'], true);
      final before = BigInt.parse(accepted.first['seq']);
      final older = await channel.page(
        RequestOptions(
          path: '/messages/channel/mix',
          queryParameters: {'before': '$before', 'limit': 25},
        ),
      );
      final prior = acceptedWindowRows(older['messages'], 'mix');
      expect(prior, hasLength(25));
      expect(BigInt.parse(prior.last['seq']) < before, true);
      expect(channel.rows, hasLength(600));
      expect(channel.olderPagesServed, 1);
    },
  );
}
