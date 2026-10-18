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

Widget _host(
  RaftFamily family,
  bool dark,
  Widget child, {
  double width = 700,
}) => MaterialApp(
  locale: _androidZh ? const Locale('zh') : null,
  theme: raftTheme(
    family,
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
    for (final theme in raftThemeMatrix([
      (RaftFamily.brutal, false),
      (RaftFamily.elegant, false),
      (RaftFamily.elegant, true),
    ])) {
      final (family, dark) = theme;

      for (final small in [false, true]) {
        testWidgets(
          'RaftErrorBanner message and retry: $theme zh=$zh x$scale small=$small',
          (tester) async {
            await tester.pumpWidget(
              _host(
                family,
                dark,
                RaftErrorBanner(
                  'Could not load',
                  small: small,
                  onRetry: () {},
                  retryLabel: 'Retry',
                ),
                width: 600,
              ),
            );
            expectVerticallyCentered(tester, [
              find.text('Could not load'),
              find.byType(RaftRecipeButton),
            ], reason: 'RaftErrorBanner small=$small');
          },
        );
      }

      testWidgets(
        'RaftComposerNotice message and dismiss: $theme zh=$zh x$scale',
        (tester) async {
          await tester.pumpWidget(
            _host(
              family,
              dark,
              RaftComposerNotice(
                message: 'Attachment too large',
                onDismiss: () {},
                dismissLabel: 'Dismiss',
              ),
              width: 600,
            ),
          );
          expectVerticallyCentered(tester, [
            find.text('Attachment too large'),
            find.byType(RaftRecipeButton),
          ], reason: 'RaftComposerNotice');
        },
      );

      testWidgets(
        'RaftAvatarListRow name and trailing action: $theme zh=$zh x$scale',
        (tester) async {
          await tester.pumpWidget(
            _host(
              family,
              dark,
              RaftAvatarListRow(
                avatar: const SizedBox.square(dimension: 32),
                name: 'Cindy',
                subtitle: '@cindy',
                actionContent: [_button('Remove')],
              ),
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
              family,
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
              family,
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
