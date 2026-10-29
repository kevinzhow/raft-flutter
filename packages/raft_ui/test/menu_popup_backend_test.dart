import 'dart:ui' show SemanticsRole, Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

const _popupKey = ValueKey('backend-contract-popup');
const _selectedMark = ValueKey('backend-selected-mark');

List<RaftMenuPopupEntry> _choices() => const [
  RaftMenuPopupEntry(key: ValueKey('row-alpha'), label: 'Alpha'),
  RaftMenuPopupEntry(label: 'Beta', enabled: false),
  RaftMenuPopupEntry(
    key: ValueKey('row-gamma'),
    label: 'Gamma',
    selected: true,
    indicator: SizedBox.square(key: _selectedMark, dimension: 12),
  ),
  RaftMenuPopupEntry(label: 'Delta', enabled: false),
  RaftMenuPopupEntry(key: ValueKey('row-epsilon'), label: 'Epsilon'),
];

// This is a caller/owner fixture, not a second popup implementation. It keeps
// typed selection and dismissal decisions outside the backend, and resolves
// the already generated Select slots against the real Raft theme.
class _PopupOwner extends StatefulWidget {
  const _PopupOwner({
    super.key,
    required this.entries,
    this.initialPreferredIndex,
    this.initialAutofocus = true,
    this.initiallyVisible = true,
    this.selectionSemantics = false,
    this.anchorWidth = 300,
    this.maxHeight = 168,
  });

  final List<RaftMenuPopupEntry> entries;
  final int? initialPreferredIndex;
  final bool initialAutofocus, initiallyVisible, selectionSemantics;
  final double anchorWidth, maxHeight;

  @override
  State<_PopupOwner> createState() => _PopupOwnerState();
}

class _PopupOwnerState extends State<_PopupOwner> {
  var triggerFocus = FocusNode(debugLabel: 'fixture trigger');
  final editorFocus = FocusNode(
    debugLabel: 'fixture editor',
    skipTraversal: true,
  );
  final outerScroll = ScrollController();
  final newEditorFocus = FocusNode(debugLabel: 'new destination editor');
  final newEditorScope = FocusScopeNode(debugLabel: 'new destination scope');
  final activations = <int>[];
  final resolutions = <RaftMenuPopupRowState>[];
  late List<RaftMenuPopupEntry> entries;
  late int? preferredIndex;
  late bool autofocus, visible;
  late double anchorWidth;
  var dismissals = 0;
  var removeOnDismiss = false;
  var openNewEditorOnDismiss = false;
  var newEditorVisible = false;
  var newEditorClaims = 0;

  @override
  void initState() {
    super.initState();
    entries = widget.entries;
    preferredIndex = widget.initialPreferredIndex;
    autofocus = widget.initialAutofocus;
    visible = widget.initiallyVisible;
    anchorWidth = widget.anchorWidth;
    newEditorFocus.addListener(() {
      if (newEditorFocus.hasFocus) newEditorClaims++;
    });
  }

  void showPopup(bool value) => setState(() => visible = value);
  void replaceEntries(List<RaftMenuPopupEntry> value) =>
      setState(() => entries = value);
  void prefer(int? value) => setState(() => preferredIndex = value);
  void setAutofocus(bool value) => setState(() => autofocus = value);
  void setWidth(double value) => setState(() => anchorWidth = value);

  RaftMenuPopupSlots resolve(
    BuildContext context,
    RaftMenuPopupRowState state,
  ) {
    resolutions.add(state);
    final tokens = RaftTokens.of(context);
    final slots = RaftSelectRecipe.resolve(
      theme: tokens.recipeTheme,
      tokens: tokens.recipeTokens,
      states: tokens.recipeStates(
        hovered: state.hovered,
        focusVisible: state.focusVisible,
        disabled: state.disabled,
        extra: [
          if (state.selected) 'data-selected',
          if (state.disabled) 'data-disabled',
          if (state.highlighted) 'data-highlighted',
          if (state.lastChild) 'last-child',
        ],
      ),
    );
    // The neutral surface call has index -1. No caller row is looked up here.
    return RaftMenuPopupSlots(
      content: slots.content,
      list: slots.list,
      item: slots.item,
      itemLeading: slots.itemLeading,
      itemText: slots.itemText,
      itemIndicator: slots.itemIndicator,
    );
  }

  void dismiss() {
    dismissals++;
    if (openNewEditorOnDismiss) {
      setState(() {
        visible = false;
        newEditorVisible = true;
      });
      // Register the destination's focus claim before the disappearing popup's
      // disposal callbacks. This models opening an editor in the same action.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !newEditorVisible) return;
        newEditorFocus.requestFocus();
        // Apply the new owner's claim in this post-frame phase, so the test
        // observes actual ownership before later restoration callbacks run.
        FocusManager.instance.applyFocusChangesIfNeeded();
      });
      return;
    }
    if (removeOnDismiss) showPopup(false);
  }

  FocusNode closeAndReplaceTrigger() {
    final retired = triggerFocus;
    setState(() {
      visible = false;
      triggerFocus = FocusNode(debugLabel: 'replacement trigger');
    });
    // The old button's context remains mounted while its caller-owned node is
    // replaced. Dispose before the popup's deferred restoration is delivered.
    WidgetsBinding.instance.addPostFrameCallback((_) => retired.dispose());
    return retired;
  }

  @override
  void dispose() {
    triggerFocus.dispose();
    editorFocus.dispose();
    outerScroll.dispose();
    newEditorFocus.dispose();
    newEditorScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: outerScroll,
    child: SizedBox(
      height: 1400,
      child: Stack(
        children: [
          Positioned(
            left: 40,
            top: 16,
            child: RaftButton(
              label: 'Popup trigger',
              focusNode: triggerFocus,
              onPressed: () => showPopup(true),
            ),
          ),
          Positioned(
            left: 400,
            top: 16,
            child: Focus(focusNode: editorFocus, child: const Text('Editor')),
          ),
          if (newEditorVisible)
            Positioned(
              left: 400,
              top: 80,
              child: SizedBox(
                width: 240,
                child: FocusScope(
                  node: newEditorScope,
                  child: TextField(
                    key: const ValueKey('new-destination-editor'),
                    focusNode: newEditorFocus,
                    decoration: const InputDecoration(labelText: 'New editor'),
                  ),
                ),
              ),
            ),
          if (visible)
            Positioned(
              left: 40,
              top: 100,
              child: RaftMenuPopupBackend(
                key: _popupKey,
                entries: entries,
                resolveSlots: (state) => resolve(context, state),
                onActivate: activations.add,
                onDismiss: dismiss,
                anchorWidth: anchorWidth,
                maxHeight: widget.maxHeight,
                preferredIndex: preferredIndex,
                triggerFocus: triggerFocus,
                autofocus: autofocus,
                semanticRole: widget.selectionSemantics
                    ? SemanticsRole.list
                    : SemanticsRole.menu,
                itemSemanticRole: widget.selectionSemantics
                    ? SemanticsRole.listItem
                    : SemanticsRole.menuItem,
                selectionSemantics: widget.selectionSemantics,
              ),
            ),
        ],
      ),
    ),
  );
}

Future<_PopupOwnerState> _mount(
  WidgetTester tester, {
  List<RaftMenuPopupEntry>? entries,
  int? preferredIndex,
  bool autofocus = true,
  bool initiallyVisible = true,
  bool selectionSemantics = false,
  double anchorWidth = 300,
  double maxHeight = 168,
}) async {
  final owner = GlobalKey<_PopupOwnerState>();
  tester.view.physicalSize = const Size(800, 800);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: TargetPlatform.linux),
      home: Scaffold(
        body: _PopupOwner(
          key: owner,
          entries: entries ?? _choices(),
          initialPreferredIndex: preferredIndex,
          initialAutofocus: autofocus,
          initiallyVisible: initiallyVisible,
          selectionSemantics: selectionSemantics,
          anchorWidth: anchorWidth,
          maxHeight: maxHeight,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return owner.currentState!;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  // Focus changes are delivered between frames; the next input must go to the
  // row the user can now interact with, not its previous focus owner.
  await tester.pumpAndSettle();
}

Finder _row(String label) => find.bySemanticsLabel(RegExp('^$label\$'));

RaftMenuPopupRowState _lastState(_PopupOwnerState owner, int index) =>
    owner.resolutions.lastWhere((state) => state.index == index);

void _contractTest(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      try {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        semantics.dispose();
        tester.view.reset();
      }
    }
  });
}

void main() {
  _contractTest(
    'caller labels, keys, indicators and choice semantics survive',
    (tester) async {
      const cssKey = ValueKey('caller-css-label');
      const textKey = ValueKey('caller-text-label');
      const unusedMark = ValueKey('unselected-mark');
      const css = RaftCssText('Rendered code', key: cssKey);
      const plain = Text('Rendered text', key: textKey);
      await _mount(
        tester,
        selectionSemantics: true,
        entries: const [
          RaftMenuPopupEntry(
            key: ValueKey('caller-row'),
            label: 'Accessible code',
            labelChild: css,
            selected: true,
            indicator: SizedBox.square(key: _selectedMark, dimension: 12),
          ),
          RaftMenuPopupEntry(
            label: 'Accessible text',
            labelChild: plain,
            enabled: false,
            indicator: SizedBox.square(key: unusedMark, dimension: 12),
          ),
        ],
      );
      expect(tester.widget<RaftCssText>(find.byKey(cssKey)), same(css));
      expect(tester.widget<Text>(find.byKey(textKey)), same(plain));
      expect(find.byKey(const ValueKey('caller-row')), findsOneWidget);
      expect(find.byKey(_selectedMark), findsOneWidget);
      expect(find.byKey(unusedMark), findsNothing);
      final selected = tester.getSemantics(_row('Accessible code'));
      final disabled = tester.getSemantics(_row('Accessible text'));
      expect(selected.getSemanticsData().role, SemanticsRole.listItem);
      expect(selected.flagsCollection.isSelected, Tristate.isTrue);
      expect(disabled.flagsCollection.isSelected, Tristate.isFalse);
      expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  _contractTest('action semantics do not silently announce typed selection', (
    tester,
  ) async {
    await _mount(tester);
    final selected = tester.getSemantics(_row('Gamma'));
    expect(selected.getSemanticsData().role, SemanticsRole.menuItem);
    expect(selected.flagsCollection.isSelected, Tristate.none);
    expect(find.byKey(_selectedMark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  _contractTest('resolver receives neutral and actual row interaction states', (
    tester,
  ) async {
    final owner = await _mount(tester, autofocus: false);
    final neutral = owner.resolutions.where((state) => state.index == -1);
    expect(neutral, isNotEmpty);
    expect(
      neutral.every(
        (state) =>
            !state.selected &&
            !state.disabled &&
            !state.highlighted &&
            !state.hovered &&
            !state.focusVisible &&
            !state.lastChild,
      ),
      isTrue,
    );
    expect(_lastState(owner, 2).selected, isTrue);
    expect(_lastState(owner, 1).disabled, isTrue);
    expect(_lastState(owner, 4).lastChild, isTrue);
    expect(_lastState(owner, 0).lastChild, isFalse);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(780, 780));
    try {
      await mouse.moveTo(tester.getCenter(_row('Alpha')));
      await tester.pumpAndSettle();
      expect(_lastState(owner, 0).hovered, isTrue);
      expect(_lastState(owner, 0).highlighted, isTrue);
      await mouse.moveTo(tester.getCenter(_row('Beta')));
      await tester.pumpAndSettle();
      expect(_lastState(owner, 1).disabled, isTrue);
      expect(_lastState(owner, 1).highlighted, isFalse);
      expect(_lastState(owner, 0).hovered, isFalse);
    } finally {
      await mouse.removePointer();
    }
    owner.setAutofocus(true);
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.home);
    expect(_lastState(owner, 0).focusVisible, isTrue);
    expect(_lastState(owner, 0).highlighted, isTrue);
    expect(tester.takeException(), isNull);
  });

  _contractTest('anchor minimum and bounded scrolling stay inside the popup', (
    tester,
  ) async {
    final owner = await _mount(
      tester,
      maxHeight: 168,
      entries: [
        for (var i = 0; i < 30; i++)
          RaftMenuPopupEntry(label: 'Choice $i', selected: i == 29),
      ],
    );
    final popup = find.byKey(_popupKey);
    final scroll = find.descendant(
      of: popup,
      matching: find.byType(Scrollable),
    );
    expect(scroll, findsOneWidget);
    expect(tester.getSize(popup).width, 300);
    expect(tester.getSize(popup).height, lessThanOrEqualTo(168));
    expect(
      tester.state<ScrollableState>(scroll).position.pixels,
      greaterThan(0),
      reason: 'The selected last row is revealed in the popup itself.',
    );
    final viewport = tester.getRect(scroll);
    final last = tester.getRect(_row('Choice 29'));
    expect(last.top, greaterThanOrEqualTo(viewport.top));
    expect(last.bottom, lessThanOrEqualTo(viewport.bottom + .01));
    expect(owner.outerScroll.offset, 0);
    await _press(tester, LogicalKeyboardKey.home);
    expect(
      tester.getRect(_row('Choice 0')).top,
      greaterThanOrEqualTo(viewport.top),
    );
    expect(owner.outerScroll.offset, 0);
    owner.setWidth(180);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(popup).width,
      220,
      reason: 'The generated Select minimum is retained for narrow anchors.',
    );
    expect(tester.takeException(), isNull);
  });

  _contractTest('explicit preference precedes selected and enabled fallbacks', (
    tester,
  ) async {
    final owner = await _mount(tester, preferredIndex: 0);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(owner.activations, [0]);
    expect(find.byKey(_popupKey), findsOneWidget);
    owner.prefer(null);
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.enter);
    expect(owner.activations, [0, 2]);
    owner.prefer(1); // Disabled preferences cannot take input ownership.
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.enter);
    expect(owner.activations, [0, 2, 2]);
    owner.replaceEntries(const [
      RaftMenuPopupEntry(label: 'Disabled first', enabled: false),
      RaftMenuPopupEntry(label: 'Enabled fallback'),
    ]);
    owner.prefer(99);
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.enter);
    expect(owner.activations, [0, 2, 2, 1]);
    expect(tester.takeException(), isNull);
  });

  _contractTest('arrows, Home, End, Enter and Space preserve owner decisions', (
    tester,
  ) async {
    final owner = await _mount(tester);
    // The selected third row is the initial input owner.
    await _press(tester, LogicalKeyboardKey.enter);
    expect(owner.activations, [2]);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.home);
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.end);
    await _press(tester, LogicalKeyboardKey.space);
    expect(owner.activations, [2, 4, 0, 4, 0, 4]);
    expect(owner.entries.map((entry) => entry.selected), [
      false,
      false,
      true,
      false,
      false,
    ]);
    expect(find.byKey(_selectedMark), findsOneWidget);
    expect(find.byKey(_popupKey), findsOneWidget);
    expect(owner.dismissals, 0);
    expect(tester.takeException(), isNull);
  });

  _contractTest('Escape asks the owner; real removal restores trigger focus', (
    tester,
  ) async {
    final owner = await _mount(tester);
    await _press(tester, LogicalKeyboardKey.escape);
    expect(owner.dismissals, 1);
    expect(find.byKey(_popupKey), findsOneWidget);
    // A guard may retain the popup. Dismissal must not leave activation inert.
    await _press(tester, LogicalKeyboardKey.enter);
    expect(owner.activations, [2]);
    owner.removeOnDismiss = true;
    await _press(tester, LogicalKeyboardKey.escape);
    expect(owner.dismissals, 2);
    expect(find.byKey(_popupKey), findsNothing);
    expect(owner.triggerFocus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  _contractTest('hover mode keeps outside focus before and after removal', (
    tester,
  ) async {
    final owner = await _mount(
      tester,
      autofocus: false,
      initiallyVisible: false,
    );
    owner.editorFocus.requestFocus();
    await tester.pumpAndSettle();
    expect(owner.editorFocus.hasFocus, isTrue);
    owner.showPopup(true);
    await tester.pumpAndSettle();
    expect(owner.editorFocus.hasFocus, isTrue);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(780, 780));
    try {
      await mouse.moveTo(tester.getCenter(_row('Alpha')));
      await tester.pumpAndSettle();
      expect(owner.editorFocus.hasFocus, isTrue);
      owner.showPopup(false);
      await tester.pumpAndSettle();
      expect(owner.editorFocus.hasFocus, isTrue);
      expect(owner.triggerFocus.hasFocus, isFalse);
    } finally {
      await mouse.removePointer();
    }
    expect(tester.takeException(), isNull);
  });

  _contractTest('shrinking, all-disabled and empty entries remain safe', (
    tester,
  ) async {
    final owner = await _mount(tester, preferredIndex: 4);
    owner.replaceEntries(const [
      RaftMenuPopupEntry(label: 'Only remaining', selected: true),
    ]);
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.enter);
    expect(owner.activations, [0]);
    owner.replaceEntries(const [
      RaftMenuPopupEntry(
        label: 'Disabled selected',
        selected: true,
        enabled: false,
      ),
      RaftMenuPopupEntry(label: 'Disabled second', enabled: false),
    ]);
    await tester.pumpAndSettle();
    for (final key in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
    ]) {
      await _press(tester, key);
    }
    expect(owner.activations, [0]);
    await _press(tester, LogicalKeyboardKey.escape);
    expect(owner.dismissals, 1);
    owner.replaceEntries(const []);
    await tester.pumpAndSettle();
    for (final key in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
    ]) {
      await _press(tester, key);
    }
    await _press(tester, LogicalKeyboardKey.escape);
    expect(owner.activations, [0]);
    expect(owner.dismissals, 2);
    expect(tester.takeException(), isNull);
  });

  _contractTest(
    'stable row keys preserve input ownership across reorder and prepend',
    (tester) async {
      const alpha = RaftMenuPopupEntry(
        key: ValueKey('identity-alpha'),
        label: 'Identity Alpha',
        selected: true,
      );
      const beta = RaftMenuPopupEntry(
        key: ValueKey('identity-beta'),
        label: 'Identity Beta',
      );
      const gamma = RaftMenuPopupEntry(
        key: ValueKey('identity-gamma'),
        label: 'Identity Gamma',
      );
      const inserted = RaftMenuPopupEntry(
        key: ValueKey('identity-inserted'),
        label: 'Inserted first',
      );
      final owner = await _mount(tester, entries: const [alpha, beta, gamma]);
      // Move away from selection before updating. Resetting to the selected row
      // on every rebuild would lose the user's current input owner.
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(owner.activations, [1]);
      owner.replaceEntries(const [beta, gamma, alpha]);
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.enter);
      expect(owner.activations, [
        1,
        0,
      ], reason: 'The same keyed Beta row now reports its new index.');
      owner.replaceEntries(const [inserted, beta, gamma, alpha]);
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.enter);
      expect(owner.activations, [
        1,
        0,
        1,
      ], reason: 'Prepending a row preserves the active Beta identity.');
      expect(owner.entries.map((entry) => entry.selected), [
        false,
        false,
        false,
        true,
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  _contractTest(
    'generated Select scroll padding keeps interior focused rows clear',
    (tester) async {
      final owner = await _mount(
        tester,
        maxHeight: 168,
        entries: [
          for (var i = 0; i < 30; i++)
            RaftMenuPopupEntry(label: 'Padded choice $i', selected: i == 15),
        ],
      );
      final scroll = find.descendant(
        of: find.byKey(_popupKey),
        matching: find.byType(Scrollable),
      );
      final viewport = tester.getRect(scroll);
      // The actual generated Select list carries scroll-py-6 (24px). These
      // interior rows have scroll range on both sides, so clamping at the first
      // or final item cannot explain missing reveal padding.
      final selected = tester.getRect(_row('Padded choice 15'));
      expect(selected.top, greaterThanOrEqualTo(viewport.top + 24 - .01));
      expect(selected.bottom, lessThanOrEqualTo(viewport.bottom - 24 + .01));
      for (var i = 0; i < 8; i++) {
        await _press(tester, LogicalKeyboardKey.arrowUp);
      }
      final earlier = tester.getRect(_row('Padded choice 7'));
      expect(earlier.top, greaterThanOrEqualTo(viewport.top + 24 - .01));
      expect(earlier.bottom, lessThanOrEqualTo(viewport.bottom - 24 + .01));
      expect(owner.outerScroll.offset, 0);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(owner.activations, [7]);
      expect(tester.takeException(), isNull);
    },
  );

  _contractTest('closing popup never steals focus from the new editor owner', (
    tester,
  ) async {
    final owner = await _mount(tester);
    owner.openNewEditorOnDismiss = true;
    await _press(tester, LogicalKeyboardKey.escape);
    expect(find.byKey(_popupKey), findsNothing);
    expect(
      find.byKey(const ValueKey('new-destination-editor')),
      findsOneWidget,
    );
    expect(
      owner.newEditorClaims,
      greaterThan(0),
      reason: 'The new scope actually acquired focus in the closing frame.',
    );
    expect(
      owner.newEditorFocus.hasFocus,
      isTrue,
      reason: 'Deferred fallback restoration cannot override a newer owner.',
    );
    expect(owner.triggerFocus.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
  });

  _contractTest(
    'queued focus work is safe after whole-owner or trigger disposal',
    (tester) async {
      await _mount(tester);
      // Queue focused-row reveal, then remove its complete owner before the next
      // frame. Trigger and all caller-owned nodes are disposed with that owner.
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(find.byKey(_popupKey), findsNothing);
      expect(tester.takeException(), isNull);

      final owner = await _mount(tester);
      final retired = owner.closeAndReplaceTrigger();
      await tester.pumpAndSettle();
      expect(find.byKey(_popupKey), findsNothing);
      expect(find.widgetWithText(RaftButton, 'Popup trigger'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, isNot(same(retired)));
      expect(tester.takeException(), isNull);
    },
  );

  _contractTest(
    'a focused keyed row moved far away remains visible and active',
    (tester) async {
      final initial = [
        for (var i = 0; i < 40; i++)
          RaftMenuPopupEntry(
            key: ValueKey('distant-row-$i'),
            label: 'Distant choice $i',
            selected: i == 10,
          ),
      ];
      final owner = await _mount(tester, entries: initial);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(owner.activations, [11]);
      final reordered = List<RaftMenuPopupEntry>.of(initial);
      final active = reordered.removeAt(11);
      reordered.insert(33, active);
      owner.replaceEntries(reordered);
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.enter);
      expect(
        owner.activations,
        [11, 33],
        reason: 'The focused identity survives instead of resetting selection.',
      );
      final scroll = find.descendant(
        of: find.byKey(_popupKey),
        matching: find.byType(Scrollable),
      );
      final viewport = tester.getRect(scroll);
      final moved = tester.getRect(
        find.byKey(const ValueKey('distant-row-11')),
      );
      expect(moved.top, greaterThanOrEqualTo(viewport.top + 24 - .01));
      expect(moved.bottom, lessThanOrEqualTo(viewport.bottom - 24 + .01));
      expect(owner.outerScroll.offset, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
