import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/attachment_player_log.dart';

void main() {
  group('isPlaybackFailure', () {
    test('hardware decoder misses do not fail playback', () {
      for (final line in [
        ('error', 'vd', 'Could not open codec.'),
        ('error', 'ffmpeg', 'AVHWDeviceContext: Cannot load libcuda.so.1'),
        (
          'error',
          'ffmpeg/video',
          'h264_v4l2m2m: Could not find a valid device',
        ),
        ('warn', 'vd', 'Using software decoding.'),
      ]) {
        expect(
          isPlaybackFailure(line.$1, line.$2, line.$3),
          isFalse,
          reason: '$line',
        );
      }
    });

    test('a missing sound card does not fail a video', () {
      expect(
        isPlaybackFailure('fatal', 'ao/jack', 'cannot open server'),
        isFalse,
      );
      expect(
        isPlaybackFailure('error', 'ao/alsa', 'Playback open error'),
        isFalse,
      );
      expect(
        isPlaybackFailure(
          'error',
          'cplayer',
          'Could not open/initialize audio device -> no sound.',
        ),
        isFalse,
      );
      expect(
        isPlaybackFailure(
          'error',
          'ad',
          'Failed to initialize an audio decoder',
        ),
        isFalse,
      );
    });

    test('a missing output device fails an audio-only attachment', () {
      expect(
        isPlaybackFailure(
          'error',
          'cplayer',
          'Could not open/initialize audio device -> no sound.',
          video: false,
        ),
        isTrue,
      );
    });

    test('unplayable input and broken video output fail playback', () {
      expect(isPlaybackFailure('fatal', 'cplayer', 'anything'), isTrue);
      expect(isPlaybackFailure('error', 'vo/libmpv', 'render failed'), isTrue);
      expect(isPlaybackFailure('error', 'vo', 'x'), isTrue);
      expect(isPlaybackFailure('error', 'file', 'Cannot open file'), isTrue);
      expect(isPlaybackFailure('error', 'demux', 'x'), isTrue);
      expect(
        isPlaybackFailure(
          'error',
          'cplayer',
          'Failed to recognize file format.',
        ),
        isTrue,
      );
      expect(
        isPlaybackFailure('error', 'cplayer', 'Errors when loading file.'),
        isTrue,
      );
      expect(
        isPlaybackFailure(
          'error',
          'vd',
          "Failed to initialize a decoder for codec 'h264'.",
        ),
        isTrue,
      );
    });

    test('warnings never fail playback', () {
      expect(isPlaybackFailure('warn', 'vo', 'x'), isFalse);
      expect(isPlaybackFailure('warn', 'file', 'x'), isFalse);
    });
  });

  group('sanitizeMediaLog', () {
    test('drops URL paths, queries, fragments and credentials', () {
      final text = sanitizeMediaLog(
        'Failed to open https://user:pw@cdn.example.com:8443/a/b.mp4?token=secret#t=1.',
      );
      expect(text, contains('https://cdn.example.com:8443/[path]'));
      expect(text, isNot(contains('secret')));
      expect(text, isNot(contains('user')));
      expect(text, isNot(contains('b.mp4')));
    });

    test('hides local file URLs and user names in paths', () {
      expect(
        sanitizeMediaLog('open file:///home/kevin/x.mp4'),
        contains('[local file]'),
      );
      expect(
        sanitizeMediaLog('/home/kevin/.cache/raft/a.mp4: error'),
        '/home/~/.cache/raft/a.mp4: error',
      );
      expect(
        sanitizeMediaLog('/Users/Kevin Zhow/a.mp4'),
        isNot(contains('Kevin')),
      );
      expect(sanitizeMediaLog(r'C:\Users\kevin\a.mp4'), r'C:\Users\~\a.mp4');
      expect(
        sanitizeMediaLog('/data/user/0/app.raft/cache/a.mp4'),
        '/data/user/0/~/cache/a.mp4',
      );
    });

    test('limits one line', () {
      expect(sanitizeMediaLog('x' * 1000).length, lessThan(310));
    });
  });

  test('formatMediaLog uses the stable raft.media prefix', () {
    expect(
      formatMediaLog('error', 'vd', 'Could not open codec.'),
      'raft.media: [error] vd: Could not open codec.',
    );
  });

  test('MediaLogLimiter collapses repeats and caps volume', () {
    final limiter = MediaLogLimiter(limit: 3);
    expect(limiter.admit('a'), 'a');
    expect(limiter.admit('a'), isNull);
    expect(limiter.admit('b'), 'b');
    expect(limiter.admit('c'), contains('further log lines suppressed'));
    expect(limiter.admit('d'), isNull);
    expect(limiter.suppressed, 1);
  });

  group('parseLinuxHwdec', () {
    test('unset, empty and no keep software decoding', () {
      for (final raw in [null, '', '  ', 'no', 'NO']) {
        expect(parseLinuxHwdec(raw), isNull, reason: '$raw');
      }
    });

    test('copy-back modes are passed through, normalised', () {
      expect(parseLinuxHwdec('auto-copy-safe'), 'auto-copy-safe');
      expect(parseLinuxHwdec(' Auto-Copy '), 'auto-copy');
      expect(parseLinuxHwdec('vaapi-copy'), 'vaapi-copy');
      expect(
        parseLinuxHwdec('vaapi-copy, nvdec-copy'),
        'vaapi-copy,nvdec-copy',
      );
    });

    test('zero-copy and malformed values are ignored', () {
      for (final raw in [
        'auto',
        'auto-safe',
        'vaapi',
        'vaapi-copy,vaapi',
        'vaapi-copy;rm',
        '--hwdec=vaapi-copy',
        'vaapi copy',
        '-copy-',
      ]) {
        expect(parseLinuxHwdec(raw), isNull, reason: raw);
      }
    });
  });

  group('formatHwdecLog', () {
    test('names requested and current decoder, codec and size', () {
      expect(
        formatHwdecLog(
          requested: 'auto-copy-safe',
          current: 'vaapi-copy',
          codec: 'h264',
          width: 1080,
          height: 1920,
        ),
        'raft.media: hwdec requested=auto-copy-safe current=vaapi-copy '
        'codec=h264 1080x1920',
      );
    });

    test('software decoding and unknown values stay readable', () {
      expect(
        formatHwdecLog(requested: 'no', current: 'no'),
        'raft.media: hwdec requested=no current=no codec=unknown unknown',
      );
      expect(
        formatHwdecLog(requested: 'no', current: '', width: 0, height: 5),
        'raft.media: hwdec requested=no current=unknown codec=unknown unknown',
      );
    });

    test('property text cannot inject paths or extra lines', () {
      final line = formatHwdecLog(
        requested: 'no',
        current: 'vaapi\nraft.media: x /home/me/a.mp4',
        codec: 'h264 file:///home/me/a.mp4',
      );
      expect(line.contains('\n'), isFalse);
      expect(line.contains('/'), isFalse);
      expect(line.contains(' '), isTrue);
    });
  });
}
