import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chinese_community.dart';
import 'package:raft_ui/raft_ui.dart';

const _primary = 'https://static.example/community/chinese-qr.json';
const _fallback = 'https://app.example/community/chinese-qr.json';

Map<String, Object?> _config(String image, {String? expiresAt}) => {
  'imageUrl': image,
  'expiresAt': ?expiresAt,
};

Widget _page({
  required Map<String, Object?> answers,
  DateTime? now,
  List<String>? asked,
}) => MaterialApp(
  theme: raftTheme(),
  home: ChineseCommunityPage(
    configUrl: _primary,
    fallbackConfigUrl: _fallback,
    now: now == null ? null : () => now,
    fetch: (url) async {
      asked?.add(url);
      final answer = answers[url];
      if (answer is Exception) throw answer;
      return answer;
    },
    imageBuilder: (url, onError) => answers['broken:$url'] == true
        ? Builder(
            builder: (_) {
              onError();
              return const SizedBox.shrink();
            },
          )
        : Text('qr:$url', key: const ValueKey('fake-qr')),
  ),
);

void main() {
  group('QR configuration rules (utils/chineseCommunityQr.ts)', () {
    final url = Uri.parse(_primary);
    test(
      'the image resolves against the config and stays under /community/',
      () {
        final ok = resolveChineseCommunityQrConfig(_config('wechat.png'), url);
        expect(ok?.imageUrl, 'https://static.example/community/wechat.png');
        final root = resolveChineseCommunityQrConfig(
          _config('/community/a/b.png'),
          url,
        );
        expect(root?.imageUrl, 'https://static.example/community/a/b.png');
      },
    );

    test('anything off the config origin or path is refused', () {
      for (final bad in [
        'https://evil.example/community/qr.png',
        '/other/qr.png',
        'qr.png?x=1',
        'qr.png#frag',
        'https://user:pw@static.example/community/qr.png',
        'http://static.example/community/qr.png',
      ]) {
        expect(
          resolveChineseCommunityQrConfig(_config(bad), url),
          isNull,
          reason: bad,
        );
      }
      expect(
        resolveChineseCommunityQrConfig(
          _config('qr.png'),
          Uri.parse('http://static.example/community/chinese-qr.json'),
        ),
        isNull,
        reason: 'a remote config must be https',
      );
      expect(resolveChineseCommunityQrConfig({'imageUrl': '  '}, url), isNull);
      expect(resolveChineseCommunityQrConfig('nope', url), isNull);
    });

    test('expiry reads an ISO date and never expires on nonsense', () {
      final now = DateTime.utc(2026, 10, 21);
      expect(isChineseCommunityQrExpired(null, now: now), isFalse);
      expect(isChineseCommunityQrExpired('garbage', now: now), isFalse);
      expect(
        isChineseCommunityQrExpired('2026-10-20T00:00:00Z', now: now),
        isTrue,
      );
      expect(
        isChineseCommunityQrExpired('2026-10-22T00:00:00Z', now: now),
        isFalse,
      );
    });
  });

  testWidgets('shows the QR image of the primary configuration', (t) async {
    final asked = <String>[];
    await t.pumpWidget(
      _page(asked: asked, answers: {_primary: _config('wechat.png')}),
    );
    await t.pumpAndSettle();
    expect(find.text('Scan the QR code to join'), findsOneWidget);
    expect(
      find.text('qr:https://static.example/community/wechat.png'),
      findsOneWidget,
    );
    expect(asked, [_primary]);
  });

  testWidgets('falls back to the app copy when the primary cannot be read', (
    t,
  ) async {
    final asked = <String>[];
    await t.pumpWidget(
      _page(
        asked: asked,
        answers: {
          _primary: Exception('offline'),
          _fallback: _config('/community/own.png'),
        },
      ),
    );
    await t.pumpAndSettle();
    expect(asked, [_primary, _fallback]);
    expect(
      find.text('qr:https://app.example/community/own.png'),
      findsOneWidget,
    );
  });

  testWidgets('a primary picture that fails to load retries the fallback', (
    t,
  ) async {
    await t.pumpWidget(
      _page(
        answers: {
          _primary: _config('wechat.png'),
          'broken:https://static.example/community/wechat.png': true,
          _fallback: _config('/community/own.png'),
        },
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.text('qr:https://app.example/community/own.png'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chinese-community-qr-missing')),
      findsNothing,
    );
  });

  testWidgets('says why there is no QR code', (t) async {
    // No configuration anywhere.
    await t.pumpWidget(_page(answers: {}));
    await t.pumpAndSettle();
    expect(
      find.text(
        'The QR code is not configured yet. Refresh later or contact the Raft team.',
      ),
      findsOneWidget,
    );
    // Primary picture and fallback both unusable.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      _page(
        answers: {
          _primary: _config('wechat.png'),
          'broken:https://static.example/community/wechat.png': true,
        },
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.text(
        'The QR code cannot be loaded. Please refresh later or contact the Raft team.',
      ),
      findsOneWidget,
    );
    // An expired code is not drawn.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      _page(
        now: DateTime.utc(2026, 10, 21),
        answers: {
          _primary: _config('wechat.png', expiresAt: '2026-10-01T00:00:00Z'),
        },
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('fake-qr')), findsNothing);
    expect(
      find.text(
        'This QR code has expired. Please refresh later or contact the Raft team.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the Help menu item follows the display language', (t) async {
    RaftMenuEntry? entry;
    var joined = 0;
    Widget host(Locale locale, {bool joining = false}) => MaterialApp(
      home: Builder(
        builder: (context) => Localizations.override(
          context: context,
          locale: locale,
          child: Builder(
            builder: (context) {
              entry = communityHelpEntry(
                context,
                apiOrigin: 'https://api.raft.build',
                joining: joining,
                join: () => joined++,
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await t.pumpWidget(host(const Locale('en')));
    expect(entry!.label, 'Join Community');
    entry!.onPressed!();
    expect(joined, 1);

    await t.pumpWidget(host(const Locale('zh')));
    expect(entry!.label, '加入中文社群');
    // It opens the page instead of joining the default community server.
    expect(entry!.onPressed, isNotNull);

    await t.pumpWidget(host(const Locale('en'), joining: true));
    expect(entry!.label, 'Joining community…');
    expect(entry!.onPressed, isNull);
    await t.pumpWidget(host(const Locale('zh'), joining: true));
    expect(entry!.label, '正在加入社区…');
    expect(entry!.onPressed, isNull);
  });
}
