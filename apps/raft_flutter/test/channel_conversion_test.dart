import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_conversion_section.dart';

import 'support/joint_channel_fixture.dart' show fixture, host;

Map<String, dynamic> channel({
  String type = 'channel',
  Map<String, dynamic>? job,
  Map<String, dynamic>? command,
}) => {
  'id': 'c1',
  'name': 'work',
  'type': type,
  'joined': true,
  'conversionJob': job,
  'conversionCommand': command,
};
Map<String, dynamic> job(String status, {bool canCancel = true}) => {
  'id': 'j1',
  'status': status,
  'phase': status == 'done' ? 'done' : 'prepare',
  'canCancel': canCancel,
};
Future<void> flush(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 30));
  }
}

Future<void> confirm(WidgetTester t, String label) async {
  await t.tap(find.text(label).last);
  await flush(t);
  await t.tap(find.text(label).last);
  await flush(t);
}

void main() {
  test('canonical projection is authoritative and inconsistent snapshots fail closed', () {
    final value = ChannelConversionSnapshot.from({
      'conversionState': {
        'status': 'pending',
        'command': {'id': 'new', 'kind': 'retry', 'status': 'pending'},
        'job': job('failed'),
      },
      'conversionJob': job('done'),
    });
    expect(value.status, 'pending');
    expect(value.job['status'], 'failed');
    expect(
      () => ChannelConversionSnapshot.from({
        'conversionState': {
          'status': 'done',
          'command': null,
          'job': job('running'),
        },
      }),
      throwsFormatException,
    );
    expect(
      ChannelConversionSnapshot.from(
        channel(job: job('running', canCancel: false)),
      ).canCancel,
      false,
    );
  });
  test('old terminal jobs and completed commands without a job cannot settle new start', () {
    final old = ChannelConversionSnapshot.from(
      channel(
        job: job('done'),
        command: {
          'id': 'previous',
          'kind': 'start',
          'status': 'completed',
          'jobId': 'j1',
        },
      ),
    );
    final pending = ConversionObservation(
      token: 'next',
      kind: 'start',
      baseline: old,
      previousCommandId: 'previous',
    );
    expect(pending.settles(old), false);
    expect(
      pending.settles(
        ChannelConversionSnapshot.from(
          channel(
            command: {'id': 'next', 'kind': 'start', 'status': 'completed'},
          ),
        ),
      ),
      false,
    );
    expect(
      pending.settles(
        ChannelConversionSnapshot.from(
          channel(
            job: job('running'),
            command: {
              'id': 'next',
              'kind': 'start',
              'status': 'completed',
              'jobId': 'j1',
            },
          ),
        ),
      ),
      true,
    );
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(conversionCommandIdentity()),
      true,
    );
  });
  testWidgets(
    'external channels off or unknown never reads a job or renders the section',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      w.channels = [RaftChannel(channel())];
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': channelConversionFlag, 'enabled': false},
        ],
      };
      await t.pumpWidget(
        host(ChannelConversionSection(controller: w, channelId: 'c1')),
      );
      await flush(t);
      expect(find.text('Convert to Joint Channel'), findsNothing);
      expect(
        a.calls.where(
          (c) => c.method == 'GET' && c.path.startsWith('/channels'),
        ),
        isEmpty,
      );
    },
  );
  // Web 1.24: converting to a joint channel is retired on every server
  // (EditChannelDialog.tsx:184-188; the server answers 404
  // joint_conversion_retired), and the section only follows a conversion
  // under way where external_channels_v1 is on (channels.ts:867-876).
  testWidgets(
    'an idle channel gets no convert offer with external channels on',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      w.channels = [RaftChannel(channel())];
      a.routes['POST /feature-flags/evaluate'] = (o) => {
        'evaluations': [
          for (final key in (o.data as Map)['keys'] as List)
            {'key': key, 'enabled': true},
        ],
      };
      a.routes['GET /channels/c1'] = (_) => channel();
      await t.pumpWidget(
        host(ChannelConversionSection(controller: w, channelId: 'c1')),
      );
      await flush(t);
      expect(channelConversionFlag, 'external_channels_v1');
      expect(find.text('Convert to Joint Channel'), findsNothing);
      expect(find.text('Chat with members from other servers'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed conversion receipt can retry despite an early joint projection; cutover cannot cancel',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      w.channels = [RaftChannel(channel(type: 'joint'))];
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': channelConversionFlag, 'enabled': true},
        ],
      };
      a.routes['GET /channels/c1'] = (_) =>
          channel(type: 'joint', job: job('failed', canCancel: false));
      a.routes['GET /attachments/upload-sessions/c1/active'] = (_) => {
        'uploads': [],
      };
      a.routes['POST /channels/conversion-jobs/j1/retry'] = (_) => {
        'conversionJob': job('running', canCancel: false),
      };
      a.routes['GET /channels/conversion-jobs/j1'] = (_) => {
        'channel': channel(
          type: 'joint',
          job: job('running', canCancel: false),
        ),
        'conversionJob': job('running', canCancel: false),
      };
      await t.pumpWidget(
        host(ChannelConversionSection(controller: w, channelId: 'c1')),
      );
      await flush(t);
      expect(find.text('Cancel Conversion'), findsNothing);
      await confirm(t, 'Retry Conversion');
      expect(a.calls.singleWhere((c) => c.path.endsWith('/retry')).data.keys, [
        'commandId',
      ]);
      expect(find.text('Convert to Joint Channel'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'cancel acknowledgement cannot be overwritten by an older running poll',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      w.channels = [RaftChannel(channel())];
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': channelConversionFlag, 'enabled': true},
        ],
      };
      a.routes['GET /channels/c1'] = (_) => channel(job: job('running'));
      a.routes['GET /attachments/upload-sessions/c1/active'] = (_) => {
        'uploads': [],
      };
      final oldPoll = Completer<dynamic>();
      a.routes['GET /channels/conversion-jobs/j1'] = (_) => oldPoll.future;
      await t.pumpWidget(
        host(ChannelConversionSection(controller: w, channelId: 'c1')),
      );
      await flush(t);
      await t.pump(const Duration(seconds: 1));
      await flush(t);
      expect(
        a.calls.where((c) => c.path == '/channels/conversion-jobs/j1'),
        isNotEmpty,
      );
      final canceled = {
        'channel': channel(job: job('canceled')),
        'conversionJob': job('canceled'),
      };
      a.routes['POST /channels/conversion-jobs/j1/cancel'] = (_) => canceled;
      a.routes['GET /channels/conversion-jobs/j1'] = (_) => canceled;
      await confirm(t, 'Cancel Conversion');
      expect(a.calls.singleWhere((c) => c.path.endsWith('/cancel')).data.keys, [
        'commandId',
      ]);
      // Canceled is no longer under way: the section goes (Web 1.24
      // EditChannelDialog.tsx:220, 401), and the older poll cannot bring the
      // running job back.
      expect(find.text('Cancel Conversion'), findsNothing);
      oldPoll.complete({
        'channel': channel(job: job('running')),
        'conversionJob': job('running'),
      });
      await flush(t);
      expect(find.text('Cancel Conversion'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
}
