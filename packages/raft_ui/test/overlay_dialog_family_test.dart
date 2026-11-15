// WP-DS2 dialog group: the dialog family follows raft-ui 0.95.3 as Web v1.24
// uses it (fold avoidance for modal routes, stacked footer, nested scrim,
// standard close X by pointer, height-capped card, DialogCard description,
// ConfirmDialog v1.24, AlertDialog helper, one-button announcement).
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/dialog_slots.dart' show RaftDialogCloseOutset;
import 'package:raft_ui/src/stacked_actions.dart' show RaftStackedActions;

const _touchSizes = <(String, Size)>[
  ('856x944', Size(856, 944)),
  ('944x856', Size(944, 856)),
];

void _view(WidgetTester t, Size size) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Widget _host(
  Widget child, {
  TargetPlatform platform = TargetPlatform.linux,
  List<DisplayFeature> features = const [],
}) => MaterialApp(
  theme: raftTheme(dark: false).copyWith(platform: platform),
  builder: (context, home) => MediaQuery(
    data: MediaQuery.of(context).copyWith(displayFeatures: features),
    child: home!,
  ),
  home: Scaffold(body: child),
);

RaftTokens _tokens(WidgetTester t, Finder f) =>
    RaftTokens.of(t.element(f.first));

Color _fill(RaftRecipeBox box) =>
    box.style.backgroundColor!.resolve(box.tokens);

void main() {
  group('R59 fold avoidance for modal routes', () {
    const hinge = DisplayFeature(
      bounds: Rect.fromLTWH(395, 0, 10, 600),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureHalfOpened,
    );
    testWidgets('a modal card sits on one side, the scrim fills the window', (
      t,
    ) async {
      _view(t, const Size(800, 600));
      await t.pumpWidget(
        _host(
          platform: TargetPlatform.android,
          features: const [hinge],
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => showRaftModal<void>(
                context,
                builder: (_) => RaftModalBackdrop(
                  child: RaftDialog.card(
                    title: 'Fold card',
                    onClose: () {},
                    contentKey: const Key('fold-card'),
                    child: const SizedBox(height: 40, child: Text('body')),
                  ),
                ),
              ),
              child: const SizedBox.expand(child: Text('Open')),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      final card = t.getRect(find.byKey(const Key('fold-card')));
      expect(
        card.right <= 395 || card.left >= 405,
        isTrue,
        reason: 'card $card must not cross the hinge',
      );
      expect(
        t.getRect(find.byType(RaftDialogBackdrop).last),
        const Rect.fromLTWH(0, 0, 800, 600),
      );
    });
  });

  group('stacked footer', () {
    Widget shell({required String cancel, required String commit}) =>
        RaftDialog.shell(
          title: 'Discard draft',
          onClose: () {},
          maxWidth: 400,
          body: const Text('Body'),
          footer: [
            RaftButton(
              key: const Key('cancel'),
              label: cancel,
              uiVariant: RaftButtonVariant.ghost,
              uiSize: RaftButtonSize.lg,
              onPressed: () {},
            ),
            RaftButton(
              key: const Key('commit'),
              label: commit,
              uiVariant: RaftButtonVariant.accent,
              uiSize: RaftButtonSize.lg,
              onPressed: () {},
            ),
          ],
        );

    // The ghost Cancel's `in-data-stacked:` frame is the Button recipe's
    // `ancestor:data-stacked` state, read from this scope (raft/button.dart).
    // Both the scope and the painted `border-line-strong` frame.
    bool ghostFrame(WidgetTester t) {
      final cancel = find.byKey(const Key('cancel'));
      final scoped = RaftStackedActions.of(t.element(cancel));
      final framed = t
          .widgetList<DecoratedBox>(
            find.descendant(of: cancel, matching: find.byType(DecoratedBox)),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .any((d) {
            final b = d.border;
            return b is Border && b.top.width > 0 && b.top.color.a > 0;
          });
      expect(framed, scoped, reason: 'the frame follows the stacked scope');
      return scoped;
    }

    for (final (name, size, platform) in [
      ('390x844 Linux', const Size(390, 844), TargetPlatform.linux),
      ('856x944 Android', const Size(856, 944), TargetPlatform.android),
    ]) {
      testWidgets('long labels stack, commit on top, ghost framed $name', (
        t,
      ) async {
        _view(t, size);
        await t.pumpWidget(
          _host(
            platform: platform,
            shell(
              cancel: 'Keep editing this draft for now',
              commit: 'Discard every unsaved change',
            ),
          ),
        );
        final cancel = t.getRect(find.byKey(const Key('cancel')));
        final commit = t.getRect(find.byKey(const Key('commit')));
        expect(commit.width, closeTo(cancel.width, .01));
        expect(commit.top, lessThan(cancel.top), reason: 'commit first');
        expect(commit.left, closeTo(cancel.left, .01));
        expect(ghostFrame(t), isTrue);
      });

      testWidgets('short labels stay one row, ghost unframed $name', (t) async {
        _view(t, size);
        await t.pumpWidget(
          _host(
            platform: platform,
            shell(cancel: 'Cancel', commit: 'Discard'),
          ),
        );
        final cancel = t.getRect(find.byKey(const Key('cancel')));
        final commit = t.getRect(find.byKey(const Key('commit')));
        expect(cancel.top, closeTo(commit.top, .01));
        expect(cancel.right, lessThan(commit.left));
        expect(ghostFrame(t), isFalse);
      });
    }
  });

  group('nested scrim', () {
    testWidgets('a dialog over a dialog uses layer-backdrop-nested', (t) async {
      _view(t, const Size(800, 600));
      late BuildContext host;
      await t.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              host = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      showRaftDialog<void>(
        context: host,
        builder: (_) => const RaftDialog(title: 'First', content: Text('a')),
      );
      await t.pumpAndSettle();
      showRaftDialog<void>(
        context: host,
        builder: (_) => const RaftDialog(title: 'Second', content: Text('b')),
      );
      await t.pumpAndSettle();
      final scrims = find
          .descendant(
            of: find.byType(RaftDialogBarrier),
            matching: find.byType(RaftRecipeBox),
          )
          .evaluate()
          .map((e) => _fill(e.widget as RaftRecipeBox))
          .toList();
      expect(scrims, hasLength(2));
      expect(scrims.first.a, closeTo(.651, .01));
      expect(scrims.last.a, closeTo(.4, .01));
    });
  });

  group('standard dialog close X by pointer', () {
    Widget dialog() => RaftDialog(
      title: 'Standard',
      content: const Text('body'),
      onClose: () {},
    );

    (double, double) measure(WidgetTester t) {
      final slot = find.byType(RaftDialogCloseOutset);
      final button = find.descendant(
        of: slot,
        matching: find.byType(RaftButton),
      );
      final b = t.getRect(button);
      return (b.width, b.right - t.getRect(slot).right);
    }

    for (final (name, size) in _touchSizes) {
      testWidgets('touch $name: 32px, 7px pull', (t) async {
        _view(t, size);
        await t.pumpWidget(_host(platform: TargetPlatform.android, dialog()));
        final (extent, pull) = measure(t);
        expect(extent, 32);
        expect(pull, 7);
      });
    }
    testWidgets('mouse 1280x800: 28px, 5px pull', (t) async {
      _view(t, const Size(1280, 800));
      await t.pumpWidget(_host(dialog()));
      final (extent, pull) = measure(t);
      expect(extent, 28);
      expect(pull, 5);
    });
    testWidgets('mouse 390x844: 32px, 7px pull', (t) async {
      _view(t, const Size(390, 844));
      await t.pumpWidget(_host(dialog()));
      final (extent, pull) = measure(t);
      expect(extent, 32);
      expect(pull, 7);
    });
  });

  group('modal card caps its height and scrolls inside', () {
    testWidgets('the backdrop does not scroll, the card body does', (t) async {
      _view(t, const Size(800, 400));
      await t.pumpWidget(
        _host(
          RaftModalBackdrop(
            child: RaftDialog.card(
              title: 'Tall',
              onClose: () {},
              contentKey: const Key('tall-card'),
              child: const SizedBox(height: 900, child: Text('tall body')),
            ),
          ),
        ),
      );
      final card = t.getRect(find.byKey(const Key('tall-card')));
      expect(card.height, lessThanOrEqualTo(400 - 32 + .01));
      expect(card.top, greaterThanOrEqualTo(16));
      final scrollables = find.descendant(
        of: find.byType(RaftModalBackdrop),
        matching: find.byType(Scrollable),
      );
      expect(scrollables, findsWidgets);
      final outer = t.state<ScrollableState>(scrollables.first);
      expect(outer.position.maxScrollExtent, 0);
      final inner = Scrollable.of(t.element(find.text('tall body')));
      expect(inner.position.maxScrollExtent, greaterThan(0));
    });
  });

  group('DialogCard description', () {
    testWidgets('sits under the title with mt-1 and mb-4', (t) async {
      _view(t, const Size(800, 600));
      await t.pumpWidget(
        _host(
          RaftDialog.card(
            title: 'Create agent',
            description: 'Seat text',
            onClose: () {},
            child: const Text('Form body'),
          ),
        ),
      );
      final title = t.getRect(find.text('Create agent'));
      final desc = t.getRect(find.text('Seat text'));
      final body = t.getRect(find.text('Form body'));
      expect(desc.top - title.bottom, closeTo(4, 3), reason: 'mt-1 + leading');
      expect(body.top - desc.bottom, closeTo(16, 3), reason: 'mb-4');
    });
  });

  group('RaftConfirmDialog v1.24', () {
    RaftConfirmDialog confirm({
      String? message = 'Sure?',
      Widget? content,
      RaftDialogSize? size,
      bool focusCancel = false,
      RaftGlyph? trailing,
      VoidCallback? onTap,
    }) => RaftConfirmDialog(
      title: 'Delete',
      message: message,
      content: content,
      size: size,
      initialFocusCancel: focusCancel,
      confirmTrailingGlyph: trailing,
    );

    testWidgets('message uses the subhead type, not 14/22.75', (t) async {
      _view(t, const Size(800, 600));
      await t.pumpWidget(_host(confirm()));
      final style = t
          .renderObject<RenderParagraph>(find.text('Sure?'))
          .text
          .style!;
      final tokens = _tokens(t, find.text('Sure?'));
      final subhead = tokens.scale(RaftTypeScale.subhead);
      expect(style.fontSize, subhead.fontSize);
    });

    testWidgets('Cancel is the ghost button', (t) async {
      _view(t, const Size(800, 600));
      await t.pumpWidget(_host(confirm()));
      final cancel = find.widgetWithText(RaftButton, 'Cancel');
      expect(t.widget<RaftButton>(cancel).uiVariant, RaftButtonVariant.ghost);
    });

    testWidgets('no message, no content, no error: no body', (t) async {
      _view(t, const Size(800, 600));
      await t.pumpWidget(_host(confirm(message: null)));
      expect(find.byType(RaftDialogBody), findsNothing);
    });

    testWidgets('size sm is 400, md is 448', (t) async {
      _view(t, const Size(800, 600));
      await t.pumpWidget(_host(confirm(size: RaftDialogSize.sm)));
      expect(t.getSize(find.byType(RaftDialogSurface)).width, 400);
      await t.pumpWidget(_host(confirm(size: RaftDialogSize.md)));
      expect(t.getSize(find.byType(RaftDialogSurface)).width, 448);
    });

    testWidgets('initialFocusCancel focuses Cancel; Enter does not confirm', (
      t,
    ) async {
      _view(t, const Size(800, 600));
      bool? result;
      await t.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await RaftConfirmDialog.show(
                context,
                confirm(focusCancel: true),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      final focus = FocusManager.instance.primaryFocus!;
      expect(
        focus.context!.findAncestorWidgetOfExactType<RaftButton>()?.label,
        'Cancel',
      );
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(result, false);
    });

    testWidgets('confirmTrailingGlyph renders after the label', (t) async {
      _view(t, const Size(800, 600));
      await t.pumpWidget(_host(confirm(trailing: RaftGlyph.externalLink)));
      final confirmButton = t.widget<RaftButton>(
        find.widgetWithText(RaftButton, 'Confirm'),
      );
      expect(confirmButton.trailingGlyph, RaftGlyph.externalLink);
    });
  });

  group('showRaftAlertDialog helper', () {
    testWidgets('Cancel ghost lg, action lg', (t) async {
      _view(t, const Size(800, 600));
      late BuildContext host;
      await t.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              host = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      showRaftAlertDialog(
        context: host,
        title: 'Reset all',
        confirmLabel: 'Reset',
      );
      await t.pumpAndSettle();
      final cancel = t.widget<RaftButton>(
        find.widgetWithText(RaftButton, 'Cancel'),
      );
      final action = t.widget<RaftButton>(
        find.widgetWithText(RaftButton, 'Reset'),
      );
      expect(cancel.resolvedVariant, RaftButtonVariant.ghost);
      expect(cancel.resolvedSize, RaftButtonSize.lg);
      expect(action.resolvedSize, RaftButtonSize.lg);
    });
  });

  group('announcement dialog', () {
    Widget announcement({RaftAnnouncementImage? image, String? cta}) =>
        RaftAnnouncementModal(
          title: 'What is new',
          body: 'Body copy',
          ctaLabel: cta,
          image: image,
          onDismiss: () {},
          onCta: cta == null ? null : () {},
        );

    testWidgets('a CTA leaves exactly one footer button', (t) async {
      _view(t, const Size(1280, 800));
      await t.pumpWidget(_host(announcement(cta: 'Try it')));
      expect(find.byKey(const ValueKey('announcement-dismiss')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('announcement-footer')),
          matching: find.byType(RaftButton),
        ),
        findsOneWidget,
      );
    });

    double inset(WidgetTester t) =>
        t.getTopLeft(find.text('What is new')).dx -
        t.getRect(find.byKey(const ValueKey('announcement-modal'))).left;

    testWidgets('body inset is 16 with a mouse at 1280x800', (t) async {
      _view(t, const Size(1280, 800));
      await t.pumpWidget(_host(announcement()));
      expect(inset(t), 16);
    });
    for (final (name, size) in _touchSizes) {
      testWidgets('body inset is 20 by touch at $name', (t) async {
        _view(t, size);
        await t.pumpWidget(
          _host(platform: TargetPlatform.android, announcement()),
        );
        expect(inset(t), 20);
      });
    }
    testWidgets('picture is 16:9 and borderless', (t) async {
      _view(t, const Size(1280, 800));
      await t.pumpWidget(
        _host(
          announcement(
            image: const RaftAnnouncementImage(
              url: 'http://localhost/none.png',
              alt: 'pic',
            ),
          ),
        ),
      );
      final pic = find.byKey(const ValueKey('announcement-picture'));
      final size = t.getSize(pic);
      expect(size.width / size.height, closeTo(16 / 9, .01));
      final box = t.widget<Container>(pic);
      expect(
        (box.decoration as BoxDecoration?)?.border,
        isNull,
        reason: 'border-0',
      );
    });
  });
}
