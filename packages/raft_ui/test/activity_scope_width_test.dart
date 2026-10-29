import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

class _AnyLocale<T> extends LocalizationsDelegate<T> {
  const _AnyLocale(this.loadLocale);
  final Future<T> Function(Locale) loadLocale;
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<T> load(Locale locale) => loadLocale(const Locale('en'));
  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

void main() {
  for (final width in [768.0, 816.0]) {
    for (final (language, scale) in [('en', 1.0), ('zh', 1.3)]) {
      for (final withSearch in [false, true]) {
        testWidgets('$width $language $scale search=$withSearch '
            'keeps the read action visible and clickable', (t) async {
          t.view.physicalSize = Size(width, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final query = TextEditingController();
          final focus = FocusNode();
          addTearDown(query.dispose);
          addTearDown(focus.dispose);
          var reads = 0;
          final masterWidth = (width - 132) / 2;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(),
              locale: Locale(language),
              supportedLocales: const [Locale('en'), Locale('zh')],
              localizationsDelegates: [
                _AnyLocale<MaterialLocalizations>(
                  DefaultMaterialLocalizations.delegate.load,
                ),
                _AnyLocale<WidgetsLocalizations>(
                  DefaultWidgetsLocalizations.delegate.load,
                ),
                _AnyLocale<CupertinoLocalizations>(
                  DefaultCupertinoLocalizations.delegate.load,
                ),
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: masterWidth,
                    child: RaftActivityScopeToolbar(
                      compact: true,
                      view: RaftActivityView.all,
                      onView: (_) {},
                      onOpenSwitcher: () {},
                      sort: 'desc',
                      onSort: (_) {},
                      search: withSearch
                          ? RaftActivitySearchInput(
                              controller: query,
                              focusNode: focus,
                              onChanged: (_) {},
                              onDismissEmpty: () {},
                            )
                          : null,
                      markAllRead: RaftTextButton(
                        key: const ValueKey('read-all'),
                        label: 'Mark All Read',
                        visualHeight: 32,
                        minimumTargetSize: 32,
                        onPressed: () => reads++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          if (withSearch) {
            final input = find.byType(RaftActivitySearchInput);
            expect(t.getSize(input).width, greaterThanOrEqualTo(64));
            await t.tap(input);
            await t.enterText(find.byType(EditableText), 'meeting');
            await t.pump();
            expect(focus.hasFocus, isTrue);
            expect(query.text, 'meeting');
          }
          final action = find.byKey(const ValueKey('read-all'));
          final toolbar = t.getRect(find.byType(RaftActivityScopeToolbar));
          final bounds = t.getRect(action);
          expect(bounds.left, greaterThanOrEqualTo(toolbar.left + 16));
          expect(bounds.right, lessThanOrEqualTo(toolbar.right - 16));
          final label = find.text(language == 'zh' ? '全部已读' : 'Mark All Read');
          expect(
            t.renderObject<RenderParagraph>(label).didExceedMaxLines,
            isFalse,
          );
          await t.tap(action);
          await t.pump();
          expect(reads, 1);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  for (final (language, scale) in [
    ('en', 1.0),
    ('en', 1.3),
    ('zh', 1.3),
    ('zh', 3.1),
  ]) {
    testWidgets('$language $scale search wraps only below its '
        'usable width and keeps input focus', (t) async {
      t.view.physicalSize = const Size(1200, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final query = TextEditingController();
      final focus = FocusNode();
      addTearDown(query.dispose);
      addTearDown(focus.dispose);
      var width = 1000.0, reads = 0, dismissals = 0;
      var sort = 'desc';
      late StateSetter resize;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          locale: Locale(language),
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: [
            _AnyLocale<MaterialLocalizations>(
              DefaultMaterialLocalizations.delegate.load,
            ),
            _AnyLocale<WidgetsLocalizations>(
              DefaultWidgetsLocalizations.delegate.load,
            ),
            _AnyLocale<CupertinoLocalizations>(
              DefaultCupertinoLocalizations.delegate.load,
            ),
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) {
                resize = update;
                return Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: RaftActivityScopeToolbar(
                      compact: true,
                      view: RaftActivityView.all,
                      onView: (_) {},
                      onOpenSwitcher: () {},
                      sort: sort,
                      onSort: (value) => update(() => sort = value),
                      search: RaftActivitySearchInput(
                        controller: query,
                        focusNode: focus,
                        onChanged: (_) {},
                        onDismissEmpty: () => dismissals++,
                      ),
                      markAllRead: RaftTextButton(
                        key: const ValueKey('read-all'),
                        label: 'Mark All Read',
                        visualHeight: 32,
                        minimumTargetSize: 32,
                        onPressed: () => reads++,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final input = find.byType(RaftActivitySearchInput);
      final action = find.byKey(const ValueKey('read-all'));
      final sortField = find.byType(RaftSelectField<String>);
      // Read the real themed/localized action width. Both fields need at
      // least 64px, with two 8px gaps and the toolbar's 32px horizontal inset.
      final fits = t.getSize(action).width + 64 + 64 + 16 + 32;
      await t.tap(input);
      await t.enterText(find.byType(EditableText), 'meeting');
      final editor = t.state<EditableTextState>(find.byType(EditableText));
      query.selection = const TextSelection.collapsed(offset: 3);
      for (final nextWidth in [fits, fits - 1, fits]) {
        resize(() => width = nextWidth);
        await t.pumpAndSettle();
        final inputBounds = t.getRect(input);
        final sortBounds = t.getRect(sortField);
        final readBounds = t.getRect(action);
        expect(inputBounds.width, greaterThanOrEqualTo(64));
        expect(sortBounds.center.dy, closeTo(readBounds.center.dy, .001));
        if (nextWidth == fits) {
          expect(inputBounds.width, closeTo(64, .001));
          expect(inputBounds.center.dy, closeTo(readBounds.center.dy, .001));
        } else {
          expect(inputBounds.bottom, lessThanOrEqualTo(readBounds.top - 8));
          expect(inputBounds.width, closeTo(nextWidth - 32, .001));
        }
        expect(
          t.state<EditableTextState>(find.byType(EditableText)),
          same(editor),
        );
        expect(focus.hasFocus, isTrue);
        expect(query.text, 'meeting');
        expect(query.selection.baseOffset, 3);
        expect(t.takeException(), isNull);
      }
      // A shrinking sort field still opens and accepts keyboard input.
      await t.tap(sortField);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(sort, 'asc');
      await t.tap(action);
      await t.pump();
      expect(reads, 1);
      await t.tap(input);
      await t.enterText(find.byType(EditableText), '');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(dismissals, 1);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
}
