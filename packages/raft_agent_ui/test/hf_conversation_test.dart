import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_agent_ui/raft_agent_ui.dart';
import 'package:raft_ui/raft_ui.dart';

/// The chat view of a channel in agent mode. Fictional data only.
const _phone = Size(412, 915);
const _desktop = Size(1440, 900);
const _tv = Size(1920, 1080);

void _size(WidgetTester t, Size size) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Widget _app(Widget child, {HfSurface? surface, bool page = true}) => MaterialApp(
  theme: raftTheme(RaftFamily.brutal),
  home: Scaffold(
    body: HandsFree(
      surface: surface,
      child: page
          ? HfPage(child: child)
          : SingleChildScrollView(child: child),
    ),
  ),
);

HfMessageData _chat(
  String id,
  String who,
  int minute, {
  String text = '你好',
  bool mine = false,
  bool agent = false,
  int day = 17,
}) => HfMessageData(
  id: id,
  senderId: 'id-$who',
  senderName: who,
  isMine: mine,
  isAgent: agent,
  time: DateTime(2026, 10, day, 10, minute),
  text: text,
);

String _norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

bool _isIcon(String s) =>
    s.runes.isNotEmpty && s.runes.every((r) => r >= 0xE000 && r <= 0xF8FF);

/// Every string drawn under [root], the way the screen parity test reads it:
/// no icon glyphs, no avatar letter, no number on a bubble's tag.
List<String> _shown(WidgetTester t, Finder root) {
  final out = <String>{};
  for (final e in find
      .descendant(of: root, matching: find.byType(RichText))
      .evaluate()) {
    var skip = false;
    e.visitAncestorElements((a) {
      final w = a.widget;
      if (w is HfAvatar || w.key == const ValueKey('hf-row-bar')) {
        skip = true;
        return false;
      }
      return true;
    });
    if (skip) continue;
    final text = _norm((e.widget as RichText).text.toPlainText());
    if (text.isEmpty || _isIcon(text)) continue;
    out.add(text);
  }
  return out.toList();
}

BoxDecoration _decoration(WidgetTester t, String id) =>
    t.widget<DecoratedBox>(find.byKey(ValueKey('hf-bubble-$id'))).decoration
        as BoxDecoration;

void main() {
  final sample = HfConversationSample.sample();
  final now = HfConversationSample.now;

  group('parts', () {
    test('only real messages are numbered, from 1, top to bottom', () {
      final parts = HfConversation.partsOf(sample, now: now);
      final numbered = parts.whereType<HfMessagePart>().toList();
      expect([for (final p in numbered) p.n], [for (var i = 1; i <= numbered.length; i++) i]);
      expect(numbered.length, sample.where((m) => m.isChat).length);
      expect([for (final p in numbered) p.message.id], [
        for (final m in sample)
          if (m.isChat) m.id,
      ]);
      // Notes and task events carry no number.
      for (final p in parts) {
        if (p is! HfMessagePart) expect(p.describe(const HfDescribeEnv()).index, isNull);
      }
    });

    test('consecutive messages of one sender are one group', () {
      final parts = HfConversation.partsOf([
        _chat('a', 'Bo', 1),
        _chat('b', 'Bo', 2),
        _chat('c', 'Bo', 3),
        _chat('d', 'Mia', 4),
        _chat('e', 'Bo', 5),
        _chat('f', 'Bo', 12),
      ], now: now).whereType<HfMessagePart>().toList();
      expect([for (final p in parts) p.head], [true, false, false, true, true, true]);
    });

    test('a person and an Agent of one name are not one group', () {
      final parts = HfConversation.partsOf([
        _chat('a', 'Cindy', 1),
        _chat('b', 'Cindy', 2, agent: true),
      ], now: now).whereType<HfMessagePart>().toList();
      expect([for (final p in parts) p.head], [true, true]);
    });

    test('days and gaps get a separator, the first message always a day', () {
      final parts = HfConversation.partsOf(sample, now: now, hasMoreAbove: true);
      expect(parts.first, isA<HfMoreAbovePart>());
      final labels = [
        for (final p in parts.whereType<HfSeparatorPart>()) p.label,
      ];
      expect(labels.first, '昨天');
      expect(labels, contains('今天'));
      // 10:06 -> 14:20 is a gap.
      expect(labels, contains('14:20'));
      expect(HfConversation.dayLabel(DateTime(2026, 3, 4), now), '3月4日');
      expect(HfConversation.dayLabel(DateTime(2025, 3, 4), now), '2025年3月4日');
    });

    test('adjacent system notes fold to one line, unless one is the highlight', () {
      final folded = HfConversation.partsOf(sample, now: now);
      final group = folded.whereType<HfNoteGroupPart>().single;
      expect(group.summary, '3 条系统更新：2 条系统消息、1 条提醒');
      expect(folded.whereType<HfNotePart>(), isEmpty);
      final open = HfConversation.partsOf(sample, now: now, highlightId: 'n2');
      expect(open.whereType<HfNoteGroupPart>(), isEmpty);
      expect(open.whereType<HfNotePart>().length, 3);
      expect(open.whereType<HfNotePart>().where((p) => p.highlighted).single.message.id, 'n2');
    });

    test('the body is cut into text, quotes and code', () {
      final s = HfConversation.bodyOf(
        '看这里\n```dart\nvoid main() {}\n```\n> 引用一\n> 引用二\n完了',
      );
      expect([for (final x in s) x.kind], [
        HfBodyKind.text,
        HfBodyKind.code,
        HfBodyKind.quote,
        HfBodyKind.text,
      ]);
      expect(s[1].title, 'dart');
      expect(s[1].text, 'void main() {}');
      expect(s[2].text, '引用一\n引用二');
    });

    test('an empty conversation says so', () {
      final parts = HfConversation.partsOf(const [], now: now);
      expect(parts.single, isA<HfEmptyPart>());
    });
  });

  group('json', () {
    test('every message round trips, through text too', () {
      for (final m in sample) {
        final again = HfMessageData.fromJson(
          Map<String, Object?>.from(jsonDecode(jsonEncode(m.toJson())) as Map),
        );
        expect(again, m, reason: m.id);
        expect(again.toJson(), m.toJson());
      }
      final all = [
        for (final m in jsonDecode(jsonEncode([for (final m in sample) m.toJson()])) as List)
          HfMessageData.fromJson(Map<String, Object?>.from(m as Map)),
      ];
      expect(all, sample);
    });

    test('a message from nothing but an id and a time is a plain bubble', () {
      final m = HfMessageData.fromJson({'id': 'x', 'time': '2026-10-17T09:00:00.000'});
      expect(m.kind, HfMessageKind.chat);
      expect(m.attachments, isEmpty);
      expect(m.isMine, isFalse);
    });
  });

  group('drawn', () {
    testWidgets('the conversation is a plain column: nothing scrolls inside', (t) async {
      _size(t, _phone);
      await t.pumpWidget(_app(HfConversationSample(highlightId: 'n1'), page: false));
      await t.pumpAndSettle();
      expect(find.descendant(of: find.byType(HfConversation), matching: find.byType(Scrollable)), findsNothing);
      expect(find.descendant(of: find.byType(HfConversation), matching: find.byType(ListView)), findsNothing);
      // The page around it is the only one.
      expect(find.byType(Scrollable), findsOneWidget);
    });

    testWidgets('mine on the right, the others on the left', (t) async {
      _size(t, _desktop);
      await t.pumpWidget(_app(const HfConversationSample()));
      await t.pumpAndSettle();
      final mine = t.getRect(find.byKey(const ValueKey('hf-bubble-m3')));
      final theirs = t.getRect(find.byKey(const ValueKey('hf-bubble-m1')));
      expect(mine.center.dx, greaterThan(1440 / 2));
      expect(theirs.center.dx, lessThan(1440 / 2));
      expect(mine.right, greaterThan(1440 * .7));
      expect(theirs.left, lessThan(1440 * .15));
    });

    testWidgets('an avatar and a name once per group; mine has none', (t) async {
      _size(t, _phone);
      await t.pumpWidget(_app(HfConversation(
        messages: [
          _chat('a', 'Bo', 1),
          _chat('b', 'Bo', 2),
          _chat('c', 'Mia', 3),
          _chat('d', 'Kevin', 4, mine: true),
        ],
        now: now,
      )));
      await t.pumpAndSettle();
      expect(find.byType(HfAvatar), findsNWidgets(2));
      expect(find.text('Bo'), findsOneWidget);
      expect(find.text('Mia'), findsOneWidget);
      expect(find.text('Kevin'), findsNothing);
      expect(find.text('我'), findsOneWidget);
    });

    testWidgets('an Agent wears the badge and its name', (t) async {
      _size(t, _phone);
      await t.pumpWidget(_app(HfConversation(
        messages: [_chat('a', 'Cindy', 1, agent: true), _chat('b', 'Bo', 40)],
        now: now,
      )));
      await t.pumpAndSettle();
      expect(find.text('Agent'), findsOneWidget);
      expect(find.text('Cindy'), findsOneWidget);
    });

    testWidgets('the numbers are on the bubbles, 1 to N', (t) async {
      _size(t, _desktop);
      await t.pumpWidget(_app(const HfConversationSample(hasMoreAbove: false)));
      await t.pumpAndSettle();
      final chats = sample.where((m) => m.isChat).length;
      expect(find.byKey(const ValueKey('hf-row-bar')), findsNWidgets(chats));
      for (var n = 1; n <= chats; n++) {
        expect(find.descendant(of: find.byKey(const ValueKey('hf-row-bar')), matching: find.text('$n')), findsOneWidget);
      }
    });

    testWidgets('the highlighted message is cream with a thicker border', (t) async {
      _size(t, _phone);
      await t.pumpWidget(_app(const HfConversationSample(highlightId: 'm5')));
      await t.pumpAndSettle();
      expect(_decoration(t, 'm5').color, const Color(0xfffff7d6));
      expect(_decoration(t, 'm4').color, isNot(const Color(0xfffff7d6)));
      double border(String id) {
        final inner = t.widget<DecoratedBox>(
          find.descendant(of: find.byKey(ValueKey('hf-bubble-$id')), matching: find.byType(DecoratedBox)).at(0),
        );
        return ((inner.decoration as BoxDecoration).border! as Border).top.width;
      }

      expect(border('m5'), greaterThan(border('m4')));
    });

    testWidgets('the page opens on the highlighted message', (t) async {
      _size(t, _phone);
      for (final id in ['m1', 'm5', 'm11']) {
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(_app(HfConversationSample(highlightId: id)));
        await t.pumpAndSettle();
        final rect = t.getRect(find.byKey(ValueKey('hf-bubble-$id')));
        expect(rect.top, greaterThanOrEqualTo(-1), reason: id);
        expect(rect.bottom, lessThanOrEqualTo(915), reason: id);
      }
    });

    testWidgets('with nothing highlighted the page shows the newest message', (t) async {
      _size(t, _phone);
      await t.pumpWidget(_app(const HfConversationSample()));
      await t.pumpAndSettle();
      final rect = t.getRect(find.byKey(const ValueKey('hf-bubble-m11')));
      expect(rect.bottom, lessThanOrEqualTo(915));
      expect(rect.top, greaterThan(0));
    });

    testWidgets('the spotlight scrolls to a numbered message', (t) async {
      _size(t, _phone);
      final spot = AgentSpotlightController();
      addTearDown(spot.dispose);
      await t.pumpWidget(_app(
        AgentSpotlight(
          controller: spot,
          child: const HfConversationSample(focusPrefix: 'chan', highlightId: 'm1'),
        ),
      ));
      await t.pumpAndSettle();
      final ids = [for (final f in t.widgetList<AgentFocusable>(find.byType(AgentFocusable))) f.id];
      expect(ids, [for (var n = 1; n <= 11; n++) 'chan#$n']);
      spot.focus('chan#11');
      await t.pumpAndSettle();
      final rect = t.getRect(find.byKey(const ValueKey('hf-bubble-m11')));
      expect(rect.bottom, lessThanOrEqualTo(915));
      expect(_decoration(t, 'm11').color, const Color(0xfffff7d6));
    });

    testWidgets('a system note is a small line, not a bubble', (t) async {
      _size(t, _phone);
      await t.pumpWidget(_app(const HfConversationSample(highlightId: 'n1')));
      await t.pumpAndSettle();
      expect(find.text('Mia 加入了频道'), findsOneWidget);
      expect(find.byKey(const ValueKey('hf-bubble-n1')), findsNothing);
      // Centered.
      final c = t.getCenter(find.text('Mia 加入了频道'));
      expect(c.dx, closeTo(412 / 2, 4));
    });

    testWidgets('a run of system notes is one summary line', (t) async {
      _size(t, _phone);
      await t.pumpWidget(_app(const HfConversationSample()));
      await t.pumpAndSettle();
      expect(find.text('3 条系统更新：2 条系统消息、1 条提醒'), findsOneWidget);
      expect(find.text('Mia 加入了频道'), findsNothing);
    });

    testWidgets('tasks are chips: events inline, and a message that is a task', (t) async {
      _size(t, _desktop);
      await t.pumpWidget(_app(const HfConversationSample()));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('hf-task-chip')), findsNWidgets(3));
      expect(find.text('#12'), findsNWidgets(3));
      expect(find.text('待办'), findsOneWidget);
      expect(find.text('进行中'), findsOneWidget);
      expect(find.text('等验收'), findsOneWidget);
      expect(find.text('Cindy 负责'), findsNWidgets(2));
      expect(find.text('Bo 把消息转成了任务'), findsOneWidget);
      // The one inside a bubble is under it.
      final inBubble = find.descendant(of: find.byKey(const ValueKey('hf-bubble-m5')), matching: find.byKey(const ValueKey('hf-task-chip')));
      expect(inBubble, findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('hf-bubble-m1')), matching: find.byKey(const ValueKey('hf-task-chip'))), findsNothing);
    });

    testWidgets('attachments: a picture tile, files with name and size', (t) async {
      _size(t, _phone);
      await t.pumpWidget(_app(const HfConversationSample()));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('hf-image')), findsOneWidget);
      expect(find.text('login-v3.png'), findsOneWidget);
      expect(find.byKey(const ValueKey('hf-file')), findsNWidgets(2));
      expect(find.text('login-spec.pdf'), findsOneWidget);
      expect(find.text('1.2 MB'), findsOneWidget);
      expect(find.text('3.1 KB'), findsOneWidget);
    });

    testWidgets('the app supplies the picture', (t) async {
      _size(t, _phone);
      HfAttachmentData? asked;
      Size? sized;
      await t.pumpWidget(_app(HfConversationSample(
        imageBuilder: (context, image, size) {
          asked = image;
          sized = size;
          return const ColoredBox(key: ValueKey('real-image'), color: Colors.green);
        },
      )));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('real-image')), findsOneWidget);
      expect(asked!.name, 'login-v3.png');
      expect(sized!.width, greaterThan(100));
      expect(find.text('login-v3.png'), findsNothing);
    });

    testWidgets('code and quotes are drawn as such', (t) async {
      _size(t, _desktop);
      await t.pumpWidget(_app(const HfConversationSample()));
      await t.pumpAndSettle();
      expect(find.byType(HfCodeBlock), findsOneWidget);
      expect(find.text('void main() {'), findsOneWidget);
      // A reply-to quote and a "> " line.
      expect(find.byKey(const ValueKey('hf-quote')), findsNWidgets(2));
      expect(find.text('旧的跳转逻辑已经删掉了'), findsOneWidget);
      expect(find.textContaining('>'), findsNothing);
    });

    testWidgets('reactions, mine marked, and the thread count', (t) async {
      _size(t, _phone);
      await t.pumpWidget(_app(const HfConversationSample()));
      await t.pumpAndSettle();
      expect(find.text('👍 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('hf-reaction-mine')), findsNWidgets(2));
      expect(find.byKey(const ValueKey('hf-reaction')), findsNWidgets(2));
      expect(find.text('2 条回复'), findsOneWidget);
      expect(find.text('3 条回复'), findsOneWidget);
    });

    testWidgets('edited and deleted say so', (t) async {
      _size(t, _phone);
      await t.pumpWidget(_app(const HfConversationSample()));
      await t.pumpAndSettle();
      expect(find.text('已编辑'), findsOneWidget);
      expect(find.text('此消息已删除'), findsOneWidget);
      expect(find.text('发错了'), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('hf-bubble-m7')), matching: find.text('此消息已删除')), findsOneWidget);
    });

    testWidgets('a tap gives the number and the message; a TV has no taps', (t) async {
      final taps = <String>[];
      Widget conv() => HfConversationSample(onTapMessage: (n, m) => taps.add('$n:${m.id}'));
      _size(t, _desktop);
      await t.pumpWidget(_app(conv(), surface: HfSurface.desktop));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('hf-bubble-m8')), warnIfMissed: false);
      expect(taps, ['8:m8']);
      taps.clear();
      _size(t, _tv);
      await t.pumpWidget(_app(conv(), surface: HfSurface.tv));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('hf-bubble-m8')), warnIfMissed: false);
      expect(taps, isEmpty);
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('an empty conversation and the note on top', (t) async {
      _size(t, _phone);
      await t.pumpWidget(_app(const HfConversation(messages: [], hasMoreAbove: true)));
      await t.pumpAndSettle();
      expect(find.text('更早的消息未显示'), findsOneWidget);
      expect(find.text('这里还没有消息'), findsOneWidget);
    });

    for (final (name, size, surface) in [
      ('phone', _phone, HfSurface.phone),
      ('desktop', _desktop, HfSurface.desktop),
      ('tv', _tv, HfSurface.tv),
    ]) {
      testWidgets('$name: every kind, no overflow', (t) async {
        _size(t, size);
        for (final h in [null, 'n2', 'e2', 'm4', 'm7']) {
          await t.pumpWidget(_app(HfConversationSample(highlightId: h, focusPrefix: 'c'), surface: surface));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: '$name $h');
        }
      });
    }

    testWidgets('a long unbroken word and a long file name do not overflow', (t) async {
      _size(t, _phone);
      await t.pumpWidget(_app(HfConversation(
        messages: [
          HfMessageData(
            id: 'x',
            senderId: 'u',
            senderName: 'Bo' * 30,
            time: DateTime(2026, 10, 17, 10),
            text: 'a' * 300,
            attachments: [HfAttachmentData(name: 'very-long-file-name' * 8, bytes: 5)],
            task: HfTaskChipData(number: 123456, title: '很长的标题' * 20, status: 'done', claimant: '负责人' * 10),
            reactions: [for (var i = 0; i < 12; i++) HfReactionData('😀', i + 1)],
          ),
        ],
        now: now,
      )));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('describe', () {
    for (final (name, size, surface) in [
      ('phone', _phone, HfSurface.phone),
      ('tv', _tv, HfSurface.tv),
    ]) {
      for (final h in [null, 'n1']) {
        testWidgets('$name ${h ?? 'folded'}: all drawn text is in the description', (t) async {
          _size(t, size);
          await t.pumpWidget(_app(HfConversationSample(highlightId: h), surface: surface));
          await t.pumpAndSettle();
          final root = find.byType(HfConversation);
          final conv = t.widget<HfConversation>(root);
          final seen = _norm(conv.describe(const HfDescribeEnv()).lines.join('\n'));
          final shown = _shown(t, root);
          expect(shown, isNotEmpty);
          expect([for (final s in shown) if (!seen.contains(s)) s], isEmpty, reason: seen);
        });
      }
    }

    test('each message part says who, kind, when, and what it carries', () {
      const env = HfDescribeEnv();
      final parts = HfConversation.partsOf(sample, now: now, highlightId: 'm4');
      String line(String id) => parts
          .whereType<HfMessagePart>()
          .firstWhere((p) => p.message.id == id)
          .describe(env)
          .lines
          .join('\n');
      expect(line('m4'), contains('来自 Agent Cindy · 09:31'));
      expect(line('m4'), contains(HfConversation.openedFrom));
      expect(line('m4'), contains('void main() {'));
      expect(line('m4'), contains('旧的跳转逻辑已经删掉了'));
      expect(line('m4'), contains('回应：🎉 2'));
      expect(line('m4'), contains('3 条回复'));
      expect(line('m3'), contains('我发的 · 09:30'));
      expect(line('m3'), contains('引用 Bo：明天前把登录页'));
      expect(line('m1'), contains('来自 Bo · 17:40'));
      expect(line('m1'), contains('图片：login-v3.png'));
      expect(line('m1'), contains('文件：login-spec.pdf（1.2 MB）'));
      expect(line('m1'), contains('👍 3（含我）'));
      expect(line('m5'), contains('任务 #12 · 登录页改版 · 等验收 · Cindy 负责'));
      expect(line('m6'), contains('已编辑'));
      expect(line('m7'), contains('此消息已删除'));
      expect(line('m7'), isNot(contains('发错了')));
      final event = parts.whereType<HfTaskEventPart>().first.describe(env).lines.join('\n');
      expect(event, contains('任务事件'));
      expect(event, contains('Bo 把消息转成了任务'));
      final group = parts.whereType<HfNoteGroupPart>().single.describe(env).lines.join('\n');
      expect(group, contains('Mia 加入了频道'));
      expect(group, contains('明天 10:00 设计评审'));
      expect(parts.whereType<HfMessagePart>().first.describe(env).index, 1);
    });

    test('the whole conversation numbers its messages in the lines', () {
      final said = HfConversation(messages: sample, now: now)
          .describe(const HfDescribeEnv())
          .lines;
      expect(said.where((l) => l.startsWith('第 1 条 ')).length, 1);
      expect(said.where((l) => RegExp(r'^第 \d+ 条 ').hasMatch(l)).length, sample.where((m) => m.isChat).length);
      expect(said.any((l) => l.contains('系统消息')), isTrue);
    });
  });
}
