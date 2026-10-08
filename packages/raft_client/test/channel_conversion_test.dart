import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

Map<String, dynamic> job(String status, {String? rollback}) => {
  'id': 'job',
  'status': status,
  'phase': status == 'done' ? 'done' : 'prepare',
  if (rollback != null) 'progress': {'rollbackState': rollback},
};

void main() {
  test('admitted commands fence writes before the worker creates a job', () {
    for (final kind in ['start', 'retry', 'cancel']) {
      expect(
        channelConversionBlocksSending({
          'conversionState': {
            'status': 'pending',
            'command': {'id': 'command', 'kind': kind, 'status': 'pending'},
            'job': null,
          },
        }),
        isTrue,
      );
    }
  });

  test('pending command overrides a previous restored or completed job', () {
    for (final previous in [job('failed', rollback: 'restored'), job('done')]) {
      expect(
        channelConversionBlocksSending({
          'conversionState': {
            'status': 'pending',
            'command': {'id': 'retry', 'kind': 'retry', 'status': 'pending'},
            'job': previous,
          },
          'conversionJob': job('done'),
        }),
        isTrue,
      );
    }
  });

  test('command completion cannot release an active job write fence', () {
    for (final status in ['pending', 'running', 'failed']) {
      expect(
        channelConversionBlocksSending({
          'conversionJob': job(status),
          'conversionCommand': {
            'id': 'command',
            'kind': 'start',
            'status': 'completed',
            'jobId': 'job',
          },
        }),
        isTrue,
      );
    }
  });

  test('only restored failure or terminal jobs release their write fence', () {
    expect(
      channelConversionBlocksSending({
        'conversionJob': job('failed', rollback: 'restoring'),
      }),
      isTrue,
    );
    for (final terminal in [
      job('failed', rollback: 'restored'),
      job('done'),
      job('canceled'),
    ]) {
      expect(
        channelConversionBlocksSending({'conversionJob': terminal}),
        isFalse,
      );
    }
    expect(channelConversionBlocksSending({}), isFalse);
    expect(
      channelConversionBlocksSending({
        'conversionState': {
          'status': 'failed',
          'command': {'id': 'command', 'kind': 'start', 'status': 'failed'},
          'job': null,
        },
      }),
      isFalse,
      reason: 'Admission rejection alone never fenced the source.',
    );
  });

  test('canonical state overrides stale legacy fields and malformed state closes writes', () {
    expect(
      channelConversionBlocksSending({
        'conversionState': {'status': 'idle', 'command': null, 'job': null},
        'conversionJob': job('running'),
      }),
      isFalse,
    );
    for (final state in [
      {'status': 'done', 'command': null, 'job': job('running')},
      {'status': 'pending', 'command': null, 'job': null},
      {'status': 'unknown', 'command': null, 'job': null},
    ]) {
      expect(
        channelConversionBlocksSending({'conversionState': state}),
        isTrue,
      );
    }
  });
}
