import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import '../../../tool/testing/vertical_alignment.dart';

/// Rows, cards and notices with a trailing action keep the action on the same
/// vertical centre as their copy (Web: `flex items-center` rows and the
/// banner's `flex items-center` action group). The copy block of a two-line row
/// is its title and description together.
const _action = ValueKey('trailing-action');

bool _androidZh = false;
double _scale = 1;

Widget _host(bool dark, Widget child, {double width = 700, String? themeId}) =>
    MaterialApp(
      locale: _androidZh ? const Locale('zh') : null,
      theme: raftTheme(
        pack: themeId == null ? null : packForThemeId(themeId),
        dark: dark,
        locale: _androidZh ? const Locale('zh') : null,
        platform: _androidZh ? TargetPlatform.android : null,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(_scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

Widget _button([String label = 'Retry']) => RaftRecipeButton(
  key: _action,
  label: label,
  variant: RaftButtonRecipeVariant.outline,
  size: RaftButtonRecipeSize.sm,
  onPressed: () {},
);

Finder _block(String first) =>
    find.ancestor(of: find.text(first), matching: find.byType(Column)).first;

void main() {
  for (final (zh, scale) in [(false, 1.0), (true, 1.0)]) {
    setUp(() {
      _androidZh = zh;
      _scale = scale;
    });
    for (final theme in raftThemeMatrix([(false), (true)])) {
      final (dark) = theme;

      for (final small in [false, true]) {
        testWidgets(
          'RaftErrorBanner message and retry: $theme zh=$zh x$scale small=$small',
          (tester) async {
            for (final id in raftThemeMatrix([raftThemePackId])) {
              await tester.pumpWidget(
                _host(
                  dark,
                  RaftErrorBanner(
                    'Could not load',
                    small: small,
                    onRetry: () {},
                    retryLabel: 'Retry',
                  ),
                  width: 600,
                  themeId: id,
                ),
              );
              await tester.pumpAndSettle();
              await tester.pumpAndSettle();
              {
                // raft-ui 0.95.3 `BannerAction`: in a banner of 452px or more
                // whose copy is one line, the action sits after the copy on
                // its last line (`@min-[452px]:not-data-wrap:col-start-…
                // row-start-(--banner-last-row) h-lh self-end`).
                final action = tester.getRect(find.byType(RaftRecipeButton));
                final copy = tester.getRect(find.text('Could not load'));
                expect(action.left, greaterThanOrEqualTo(copy.right));
                expect(action.center.dy, greaterThanOrEqualTo(copy.top));
                expect(action.center.dy, lessThanOrEqualTo(copy.bottom));
              }
            }
          },
        );
      }

      testWidgets(
        'RaftBanner composer notice message and dismiss: $theme zh=$zh x$scale',
        (tester) async {
          for (final id in raftThemeMatrix([raftThemePackId])) {
            await tester.pumpWidget(
              _host(
                dark,
                RaftBanner(
                  status: RaftBannerRecipeStatus.warning,
                  size: RaftBannerRecipeSize.sm,
                  description: 'Attachment too large',
                  onClose: () {},
                  closeLabel: 'Dismiss',
                ),
                width: 600,
                themeId: id,
              ),
            );
            await tester.pumpAndSettle();
            final copy = tester.getRect(find.text('Attachment too large'));
            final close = tester.getRect(find.byType(RaftButton));
            expect(close.center.dy, closeTo(copy.center.dy, 2));
          }
        },
      );

      testWidgets(
        'RaftSettingsActionCard copy and action: $theme zh=$zh x$scale',
        (tester) async {
          await tester.pumpWidget(
            _host(
              dark,
              RaftSettingsActionCard(
                title: 'Delete workspace',
                description: 'This cannot be undone.',
                action: _button('Delete'),
              ),
            ),
          );
          expectVerticallyCentered(tester, [
            _block('Delete workspace'),
            find.byKey(_action),
          ], reason: 'RaftSettingsActionCard');
        },
      );

      testWidgets(
        'RaftConnectedAppDangerRow copy and action: $theme zh=$zh x$scale',
        (tester) async {
          await tester.pumpWidget(
            _host(
              dark,
              RaftConnectedAppDangerRow(
                description: 'Removing the app revokes its access.',
                action: _button('Remove'),
              ),
            ),
          );
          expectVerticallyCentered(tester, [
            find.text('Removing the app revokes its access.'),
            find.byKey(_action),
          ], reason: 'RaftConnectedAppDangerRow');
        },
      );
    }
  }
}
