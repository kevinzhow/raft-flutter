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
            for (final id in [elegantThemePackId, raftThemePackId]) {
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
              if (id == elegantThemePackId) {
                expectVerticallyCentered(tester, [
                  find.text('Could not load'),
                  find.byType(RaftRecipeButton),
                ], reason: 'legacy Elegant RaftErrorBanner small=$small');
              } else {
                // raft-ui 0.7 `BannerAction` is `col-start-(--banner-text-col) mt-2`:
                // a row under the copy, starting at its left edge.
                expect(
                  tester.getTopLeft(find.byType(RaftRecipeButton)).dy,
                  greaterThanOrEqualTo(
                    tester.getBottomLeft(find.text('Could not load')).dy,
                  ),
                );
                expect(
                  tester.getTopLeft(find.byType(RaftRecipeButton)).dx,
                  tester.getTopLeft(find.text('Could not load')).dx,
                );
              }
            }
          },
        );
      }

      testWidgets(
        'RaftComposerNotice message and dismiss: $theme zh=$zh x$scale',
        (tester) async {
          for (final id in [elegantThemePackId, raftThemePackId]) {
            await tester.pumpWidget(
              _host(
                dark,
                RaftComposerNotice(
                  message: 'Attachment too large',
                  onDismiss: () {},
                  dismissLabel: 'Dismiss',
                ),
                width: 600,
                themeId: id,
              ),
            );
            await tester.pumpAndSettle();
            if (id == elegantThemePackId) {
              expectVerticallyCentered(tester, [
                find.text('Attachment too large'),
                find.byType(RaftRecipeButton),
              ], reason: 'legacy Elegant RaftComposerNotice');
            } else {
              expect(
                tester.getTopLeft(find.text('Attachment too large')).dy,
                tester.getTopLeft(find.byType(RaftButton)).dy,
              );
            }
          }
        },
      );

      testWidgets(
        'RaftAvatarListRow name and trailing action: $theme zh=$zh x$scale',
        (tester) async {
          await tester.pumpWidget(
            _host(
              dark,
              RaftAvatarListRow(
                avatar: const SizedBox.square(dimension: 32),
                name: 'Cindy',
                subtitle: '@cindy',
                actionContent: [_button('Remove')],
              ),
              // The recipe look centres the name with the action; the Raft
              // `ListRow` centres the action on the whole two-line row.
              themeId: elegantThemePackId,
            ),
          );
          expectVerticallyCentered(tester, [
            find.text('Cindy'),
            find.byKey(_action),
          ], reason: 'RaftAvatarListRow');
        },
      );

      testWidgets(
        'RaftSettingsActionCard copy and action: $theme zh=$zh x$scale',
        (tester) async {
          await tester.pumpWidget(
            _host(
              dark,
              RaftSettingsActionCard(
                title: 'Delete Workspace',
                description: 'This cannot be undone.',
                action: _button('Delete'),
              ),
            ),
          );
          expectVerticallyCentered(tester, [
            _block('Delete Workspace'),
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
