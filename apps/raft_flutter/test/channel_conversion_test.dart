import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/channel_conversion_section.dart';

import 'joint_channel_views_test.dart' show fixture, host;

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
    'default-off or unknown flag never reads job or renders conversion action',
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
      expect(find.text('Convert to joint channel'), findsNothing);
      expect(
        a.calls.where(
          (c) => c.method == 'GET' && c.path.startsWith('/channels'),
        ),
        isEmpty,
      );
    },
  );
  testWidgets(
    'observable command uses UUID and waits for actual job progress through mounted GET',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      w.channels = [RaftChannel(channel())];
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': channelConversionFlag, 'enabled': true},
        ],
      };
      a.routes['GET /channels/c1'] = (_) => channel();
      a.routes['GET /attachments/upload-sessions/c1/active'] = (_) => {
        'uploads': [],
      };
      String? commandId;
      a.routes['POST /channels/c1/convert-to-joint'] = (o) {
        commandId = o.data['commandId'];
        return {
          'conversionState': {
            'status': 'pending',
            'command': {'id': commandId, 'kind': 'start', 'status': 'pending'},
            'job': null,
          },
        };
      };
      await t.pumpWidget(
        host(ChannelConversionSection(controller: w, channelId: 'c1')),
      );
      await flush(t);
      await confirm(t, 'Convert to joint channel');
      final call = a.calls.singleWhere(
        (c) => c.path.endsWith('/convert-to-joint'),
      );
      expect(call.data, {'commandId': commandId, 'observeProgress': true});
      expect(find.text('Waiting for server confirmation.'), findsOneWidget);
      expect(find.text('Convert to joint channel'), findsNothing);
      a.routes['GET /channels/c1'] = (_) => channel(
        job: job('running'),
        command: {
          'id': commandId,
          'kind': 'start',
          'status': 'completed',
          'jobId': 'j1',
        },
      );
      await t.tap(find.text('Check conversion status'));
      await flush(t);
      expect(find.text('Cancel conversion'), findsOneWidget);
      a.routes['GET /channels/conversion-jobs/j1'] = (_) => {
        'channel': channel(type: 'joint', job: job('done')),
        'conversionJob': job('done'),
      };
      await t.pump(const Duration(seconds: 1));
      await flush(t);
      expect(find.text('Conversion complete'), findsOneWidget);
      expect(
        a.calls.any((c) => c.path == '/channels/conversion-jobs/j1'),
        true,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'admission upload rejection exposes actual recoverable sessions and cancels by opaque coordinate',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      w.channels = [RaftChannel(channel())];
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': channelConversionFlag, 'enabled': true},
        ],
      };
      a.routes['GET /channels/c1'] = (_) => channel();
      a.routes['POST /channels/c1/convert-to-joint'] = (_) => {
        'error': 'Attachment uploads are still in flight',
        'code': 'channel_conversion_uploads_in_flight',
        'uploadCount': 1,
      };
      a.statuses['POST /channels/c1/convert-to-joint'] = 409;
      a.routes['GET /attachments/upload-sessions/c1/active'] = (_) => {
        'uploads': [
          {
            'uploadId': 'u1',
            'filename': 'Notes.pdf',
            'state': 'pending',
            'sizeBytes': 12,
            'mimeType': 'application/pdf',
            'expiresAt': '2026-10-08T23:00:00Z',
          },
        ],
      };
      a.routes['DELETE /attachments/upload-sessions/u1'] = (_) => {
        'uploadId': 'u1',
        'state': 'canceled',
      };
      await t.pumpWidget(
        host(ChannelConversionSection(controller: w, channelId: 'c1')),
      );
      await flush(t);
      await confirm(t, 'Convert to joint channel');
      expect(find.text('Notes.pdf'), findsOneWidget);
      expect(find.text('u1'), findsNothing);
      await confirm(t, 'Cancel upload');
      expect(find.text('Notes.pdf'), findsNothing);
      expect(
        a.calls.any(
          (c) =>
              c.method == 'DELETE' &&
              c.path == '/attachments/upload-sessions/u1',
        ),
        true,
      );
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
      expect(find.text('Cancel conversion'), findsNothing);
      await confirm(t, 'Retry conversion');
      expect(a.calls.singleWhere((c) => c.path.endsWith('/retry')).data.keys, [
        'commandId',
      ]);
      expect(find.text('Convert to joint channel'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'lost response stays uncertain across remount and ignores historical done receipt',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      w.channels = [RaftChannel(channel())];
      final previous = channel(
        job: job('done'),
        command: {
          'id': 'old',
          'kind': 'start',
          'status': 'completed',
          'jobId': 'j1',
        },
      );
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': channelConversionFlag, 'enabled': true},
        ],
      };
      a.routes['GET /channels/c1'] = (_) => previous;
      a.routes['GET /channels/conversion-jobs/j1'] = (_) => {
        'channel': previous,
        'conversionJob': job('done'),
      };
      a.routes['GET /attachments/upload-sessions/c1/active'] = (_) => {
        'uploads': [],
      };
      a.routes['POST /channels/c1/convert-to-joint'] = (o) =>
          throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          );
      await t.pumpWidget(
        host(ChannelConversionSection(controller: w, channelId: 'c1')),
      );
      await flush(t);
      await confirm(t, 'Convert to joint channel');
      expect(find.text('Conversion outcome is not confirmed.'), findsOneWidget);
      expect(find.text('Conversion complete'), findsNothing);
      await t.pumpWidget(
        host(
          ChannelConversionSection(
            key: const ValueKey('remount'),
            controller: w,
            channelId: 'c1',
          ),
        ),
      );
      await flush(t);
      expect(find.text('Convert to joint channel'), findsNothing);
      expect(find.text('Conversion complete'), findsNothing);
      expect(
        a.calls.where((c) => c.path.endsWith('/convert-to-joint')).length,
        1,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'role downgrade closes confirmation and retained submit cannot start conversion',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      w.channels = [RaftChannel(channel())];
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': channelConversionFlag, 'enabled': true},
        ],
      };
      a.routes['GET /channels/c1'] = (_) => channel();
      await t.pumpWidget(
        host(ChannelConversionSection(controller: w, channelId: 'c1')),
      );
      await flush(t);
      await t.tap(find.text('Convert to joint channel'));
      await flush(t);
      final retained = t.widget<RaftFormDialog>(find.byType(RaftFormDialog));
      w.server = RaftRecord({'id': 's1', 'role': 'member'});
      w.notifyListeners();
      await flush(t);
      expect(find.byType(RaftFormDialog), findsNothing);
      await expectLater(retained.onSubmit({}), throwsStateError);
      expect(
        a.calls.where((c) => c.path.endsWith('/convert-to-joint')),
        isEmpty,
      );
    },
  );
  testWidgets(
    'fresh kill switch closes an open form before any conversion POST',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      w.channels = [RaftChannel(channel())];
      bool allowed = true;
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': channelConversionFlag, 'enabled': allowed},
        ],
      };
      a.routes['GET /channels/c1'] = (_) => channel();
      await t.pumpWidget(
        host(ChannelConversionSection(controller: w, channelId: 'c1')),
      );
      await flush(t);
      await t.tap(find.text('Convert to joint channel'));
      await flush(t);
      allowed = false;
      await t.tap(find.text('Convert to joint channel').last);
      await flush(t);
      expect(find.byType(RaftFormDialog), findsNothing);
      expect(find.text('Chat with members from other servers'), findsNothing);
      expect(
        a.calls.where((c) => c.path.endsWith('/convert-to-joint')),
        isEmpty,
      );
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
      await confirm(t, 'Cancel conversion');
      expect(find.text('Conversion canceled'), findsOneWidget);
      expect(a.calls.singleWhere((c) => c.path.endsWith('/cancel')).data.keys, [
        'commandId',
      ]);
      oldPoll.complete({
        'channel': channel(job: job('running')),
        'conversionJob': job('running'),
      });
      await flush(t);
      expect(find.text('Conversion canceled'), findsOneWidget);
      expect(find.text('Cancel conversion'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'late failed-job conflict cannot restore private recovery controls after role loss',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      w.channels = [RaftChannel(channel())];
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': channelConversionFlag, 'enabled': true},
        ],
      };
      a.routes['GET /channels/c1'] = (_) => channel();
      final late = Completer<dynamic>();
      a.routes['POST /channels/c1/convert-to-joint'] = (_) => late.future;
      a.statuses['POST /channels/c1/convert-to-joint'] = 409;
      await t.pumpWidget(
        host(ChannelConversionSection(controller: w, channelId: 'c1')),
      );
      await flush(t);
      await confirm(t, 'Convert to joint channel');
      expect(find.byType(RaftFormDialog), findsOneWidget);
      w.server = RaftRecord({'id': 's1', 'role': 'member'});
      w.notifyListeners();
      await flush(t);
      late.complete({
        'error': 'Private conversion receipt',
        'conversionJob': {...job('failed'), 'error': 'Private recovery detail'},
      });
      await flush(t);
      expect(find.byType(RaftFormDialog), findsNothing);
      expect(find.text('Private recovery detail'), findsNothing);
      expect(find.text('Private conversion receipt'), findsNothing);
      expect(find.text('Retry conversion'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
}
