// WP-DS2 followup: the measurable Web v1.24 differences left in the overlay
// family (menu density by pointer, edge-to-edge context-menu separators,
// ConfirmDialog close X, title-only toast width, selection bar, preview card).
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/dialog_slots.dart' show RaftDialogCloseOutset;

const _desktop = Size(1280, 800);
const _cases = <(String, Size, TargetPlatform, double)>[
  ('1280x800 Linux', _desktop, TargetPlatform.linux, 34),
  ('856x944 Android', Size(856, 944), TargetPlatform.android, 36),
  ('944x856 Android', Size(944, 856), TargetPlatform.android, 36),
  ('390x844 Linux', Size(390, 844), TargetPlatform.linux, 36),
];

void _view(WidgetTester t, Size size) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Widget _host(Widget child, [TargetPlatform p = TargetPlatform.linux]) =>
    MaterialApp(
      theme: raftTheme(dark: false).copyWith(platform: p),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

void main() {
  group('menu item rows: 34 with a mouse from 768, 36 by touch / narrow', () {
    for (final (name, size, platform, h) in _cases) {
      testWidgets('context menu content $name', (t) async {
        _view(t, size);
        await t.pumpWidget(
          _host(
            RaftContextMenuContent(
              entries: [
                RaftContextMenuContentItem(
                  label: 'Copy',
                  itemKey: const Key('i'),
                  onPressed: () {},
                ),
              ],
            ),
            platform,
          ),
        );
        expect(t.getSize(find.byKey(const Key('i'))).height, h);
      });
      testWidgets('message context menu $name', (t) async {
        _view(t, size);
        await t.pumpWidget(
          _host(
            RaftMessageContextMenu(
              sections: [
                [
                  RaftMessageContextMenuItem(
                    label: 'Copy',
                    icon: const SizedBox(),
                    onPressed: () {},
                  ),
                ],
              ],
            ),
            platform,
          ),
        );
        expect(t.getSize(find.byType(RaftMenuButtonItem)).height, h);
      });
      testWidgets('dropdown menu item $name', (t) async {
        _view(t, size);
        await t.pumpWidget(
          _host(
            Semantics(
              role: SemanticsRole.menu,
              child: const SizedBox(
                width: 240,
                child: RaftMenuItem(label: 'Copy'),
              ),
            ),
            platform,
          ),
        );
        expect(t.getSize(find.byType(RaftMenuItem)).height, h);
      });
      testWidgets('selection popover option $name', (t) async {
        _view(t, size);
        await t.pumpWidget(
          _host(
            RaftSelectionPopover(
              title: 'Channels',
              width: 260,
              options: [
                RaftSelectionOption(
                  label: 'Design',
                  checked: false,
                  onTap: () {},
                ),
              ],
            ),
            platform,
          ),
        );
        final row = find
            .ancestor(
              of: find.text('Design'),
              matching: find.byType(RaftInteractive),
            )
            .first;
        expect(t.getSize(row).height, h);
      });
      testWidgets('menu action row $name', (t) async {
        _view(t, size);
        await t.pumpWidget(
          _host(
            const SizedBox(width: 240, child: RaftMenuActionRow(label: 'Copy')),
            platform,
          ),
        );
        expect(t.getSize(find.byType(RaftMenuActionRow)).height, h);
      });
      testWidgets('sidebar context menu $name', (t) async {
        _view(t, size);
        await t.pumpWidget(
          _host(
            RaftSidebarContextMenu(
              entries: [
                RaftSidebarMenuItem(
                  label: 'Rename',
                  itemKey: const Key('s'),
                  onPressed: () {},
                ),
              ],
            ),
            platform,
          ),
        );
        expect(t.getSize(find.byType(RaftMenuButtonItem).first).height, h);
      });
      testWidgets('inline badge editor menu $name', (t) async {
        _view(t, size);
        await t.pumpWidget(
          _host(
            RaftInlineBadgeEditor(
              label: 'Status',
              selectedId: 'todo',
              options: const [
                RaftInlineBadgeOption(id: 'todo', label: 'To do'),
                RaftInlineBadgeOption(id: 'done', label: 'Done'),
              ],
              onSelect: (_) {},
              background: Colors.yellow,
              foreground: Colors.black,
            ),
            platform,
          ),
        );
        await t.tap(find.text('Status'));
        await t.pumpAndSettle();
        final row = find
            .ancestor(
              of: find.text('Done'),
              matching: find.byType(RaftInteractive),
            )
            .first;
        expect(t.getSize(row).height, h);
      });
    }
  });

  group('context-menu separators run edge to edge', () {
    testWidgets('RaftContextMenuContent', (t) async {
      _view(t, _desktop);
      await t.pumpWidget(
        _host(
          RaftContextMenuContent(
            entries: [
              RaftContextMenuContentItem(label: 'Copy', onPressed: () {}),
              const RaftContextMenuContentSeparator(),
              RaftContextMenuContentItem(label: 'Delete', onPressed: () {}),
            ],
          ),
        ),
      );
      final menu = t.getRect(find.byType(RaftContextMenuContent));
      final sep = find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_SeparatorPainter',
      );
      expect(sep, findsOneWidget);
      final box = t.getRect(sep);
      expect(box.height, 1);
      expect(
        sep,
        paints..rect(
          rect: Rect.fromLTRB(
            menu.left - box.left,
            0,
            menu.right - box.left,
            1,
          ),
        ),
      );
    });
    for (final (name, size, platform, _) in _cases.take(2)) {
      testWidgets('RaftMessageContextMenu $name', (t) async {
        _view(t, size);
        await t.pumpWidget(
          _host(
            RaftMessageContextMenu(
              sections: [
                [
                  RaftMessageContextMenuItem(
                    label: 'A',
                    icon: const SizedBox(),
                    onPressed: () {},
                  ),
                ],
                [
                  RaftMessageContextMenuItem(
                    label: 'B',
                    icon: const SizedBox(),
                    onPressed: () {},
                  ),
                ],
              ],
            ),
            platform,
          ),
        );
        final menu = t.getRect(find.byType(RaftMessageContextMenu));
        final sep = find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_SeparatorPainter',
        );
        expect(sep, findsOneWidget);
        final box = t.getRect(sep);
        // The painted rect is the box widened by its own margins.
        final ro = t.renderObject<RenderBox>(sep);
        expect(ro.size.height, 1);
        expect(
          sep,
          paints..rect(
            rect: Rect.fromLTRB(
              menu.left - box.left,
              0,
              menu.right - box.left,
              1,
            ),
          ),
        );
      });
    }
  });

  group('ConfirmDialog close X sits where Web puts it', () {
    for (final (name, size, platform, extent, right, top) in [
      (
        '1440x900 Linux',
        const Size(1440, 900),
        TargetPlatform.linux,
        28.0,
        11.0,
        14.0,
      ),
      (
        '856x944 Android',
        const Size(856, 944),
        TargetPlatform.android,
        32.0,
        13.0,
        15.0,
      ),
    ]) {
      testWidgets(name, (t) async {
        _view(t, size);
        await t.pumpWidget(
          _host(
            Center(
              child: RaftConfirmDialog(
                title: 'Hide #all',
                message: 'Hide this channel from the sidebar.',
                surfaceKey: const Key('card'),
              ),
            ),
            platform,
          ),
        );
        final card = t.getRect(find.byKey(const Key('card')));
        final x = t.getRect(
          find.descendant(
            of: find.byType(RaftDialogCloseOutset),
            matching: find.byType(RaftButton),
          ),
        );
        expect(x.width, extent);
        expect(card.right - x.right, right);
        expect(x.top - card.top, top);
      });
    }
  });

  group('ConfirmDialog actions are lg = h-control (Web 34 with a mouse)', () {
    for (final (name, size, platform, height) in [
      ('1440x900 Linux', const Size(1440, 900), TargetPlatform.linux, 34.0),
      ('856x944 Android', const Size(856, 944), TargetPlatform.android, 44.0),
      ('944x856 Android', const Size(944, 856), TargetPlatform.android, 44.0),
      ('390x844 Linux', const Size(390, 844), TargetPlatform.linux, 44.0),
    ]) {
      testWidgets(name, (t) async {
        _view(t, size);
        await t.pumpWidget(
          _host(
            Center(
              child: RaftConfirmDialog(
                title: 'Hide #all',
                message: 'Hide this channel from the sidebar.',
                confirmLabel: 'Hide',
                cancelLabel: 'Cancel',
              ),
            ),
            platform,
          ),
        );
        for (final label in ['Hide', 'Cancel']) {
          final button = find.ancestor(
            of: find.text(label),
            matching: find.byType(RaftButton),
          );
          expect(t.getSize(button.first).height, height, reason: label);
        }
      });
    }
  });

  testWidgets(
    'DialogCard title takes no decoration from a Material-less route',
    (t) async {
      _view(t, const Size(1440, 900));
      await t.pumpWidget(_host(const SizedBox()));
      showRaftDialog<void>(
        context: t.element(find.byType(Scaffold)),
        builder: (_) => RaftDialog.card(
          title: 'Create channel',
          onClose: () {},
          child: const Text('body'),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.text('Create channel')).style!.decoration,
        TextDecoration.none,
      );
    },
  );

  group('title-only toast reserves the empty grid tracks', () {
    for (final (name, size, platform, _) in [_cases.first, _cases.last]) {
      testWidgets('width is 16 + text + 24 + 16 at $name', (t) async {
        _view(t, size);
        final c = RaftToastController();
        addTearDown(c.dispose);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: false).copyWith(platform: platform),
            home: Scaffold(body: RaftToastPortal(controller: c)),
          ),
        );
        c.show('Link copied. and a longer line', dismissible: false);
        await t.pump(const Duration(milliseconds: 300));
        await t.pump(const Duration(milliseconds: 300));
        final box = t.getRect(find.byType(RaftToast));
        final text = t.getRect(find.text('Link copied. and a longer line'));
        expect(text.left - box.left, 16);
        expect(box.right - text.right, 40);
        c.clear();
      });
    }
  });

  group('text selection bar at 1280x800 Linux', () {
    testWidgets('34px buttons in a p-1 frame', (t) async {
      _view(t, _desktop);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: false)
              .copyWith(platform: TargetPlatform.linux),
          home: Scaffold(
            body: Stack(
              children: [
                RaftSelectionShortcutBar(
                  anchors: const TextSelectionToolbarAnchors(
                    primaryAnchor: Offset(400, 300),
                  ),
                  onQuote: () {},
                  onCopy: () {},
                ),
              ],
            ),
          ),
        ),
      );
      final frame = t.getRect(
        find.byKey(const Key('selection-shortcut-frame')),
      );
      final q = t.getRect(find.byKey(const Key('selection-shortcut-quote')));
      final c = t.getRect(find.byKey(const Key('selection-shortcut-copy')));
      expect(q.height, 34);
      expect(frame.height, 42);
      // p-1, gap-1 around the 1px separator.
      expect(frame.width, 4 + q.width + 4 + 1 + 4 + c.width + 4);
      // px-2.5, 16px icon, gap-1.5 before the label.
      final label = t.getRect(find.text('Quote'));
      expect(label.left - q.left, 10 + 16 + 6);
      expect(q.right - label.right, 10);
    });
  });

  group('profile preview card follows ProfilePreviewCardContent', () {
    Widget card() => _host(
      SizedBox(
        width: 300,
        child: RaftProfilePreviewCard(
          avatar: const RaftAvatarSlot(
            name: 'Claude',
            slot: RaftAvatarSlotContext.mentionCard,
          ),
          name: 'Claude Assistant',
          subtitle: '@assistant',
          status: const RaftProfilePreviewStatus(
            activity: RaftActivityTone.offline,
            text: 'Offline',
          ),
          facts: const [
            RaftProfilePreviewFact('Computer', 'dev-machine'),
            RaftProfilePreviewFact('Runtime', 'Claude Code'),
            RaftProfilePreviewFact('Model', 'Claude Sonnet'),
            RaftProfilePreviewFact('Reasoning', 'default', capitalize: true),
          ],
          description: 'Seeded Claude agent on the primary online computer and more words so it wraps over two lines of the card body',
          activity: const [
            RaftProfilePreviewActivity(
              time: '10:53 PM',
              activity: RaftActivityTone.offline,
              text: 'Stopped',
            ),
            RaftProfilePreviewActivity(
              time: '11:01 PM',
              activity: RaftActivityTone.offline,
              text: 'Stopped',
            ),
          ],
          onOpenActivity: () {},
        ),
      ),
    );

    testWidgets('desktop: 51 avatar, 16/24 name, 22px facts, 337 tall', (
      t,
    ) async {
      _view(t, _desktop);
      await t.pumpWidget(card());
      expect(t.getSize(find.byType(RaftAvatarSlot)), const Size(51, 51));
      final name = t.widget<Text>(find.text('Claude Assistant')).style!;
      expect(name.fontSize, 16);
      expect(name.height! * name.fontSize!, closeTo(24, .01));
      final desc = t.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('profile-preview-description')),
          matching: find.byType(Text),
        ),
      );
      expect(desc.style!.fontSize, 14);
      expect(desc.maxLines, 2);
      expect(
        t
            .getSize(find.byKey(const ValueKey('profile-preview-description')))
            .height,
        69, // 1px rule + 12 + 2x22 + 12
      );
      final computer = t.getRect(find.text('Computer'));
      final runtime = t.getRect(find.text('Runtime'));
      expect(runtime.top - computer.top, 22);
      expect(
        t.getSize(find.byKey(const ValueKey('profile-preview-card'))).height,
        337,
      );
    });

    testWidgets('touch keeps the base scale (17/22 name, 14/20 description)', (
      t,
    ) async {
      _view(t, const Size(856, 944));
      await t.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: RaftProfilePreviewCard(
              avatar: const SizedBox(width: 51, height: 51),
              name: 'Ada',
              subtitle: '@ada',
              description: 'About',
            ),
          ),
          TargetPlatform.android,
        ),
      );
      final name = t.widget<Text>(find.text('Ada')).style!;
      expect(name.fontSize, 17);
      final desc = t.widget<Text>(find.text('About')).style!;
      expect(desc.fontSize, 14);
      expect(desc.height! * desc.fontSize!, closeTo(20, .01));
    });
  });
}
