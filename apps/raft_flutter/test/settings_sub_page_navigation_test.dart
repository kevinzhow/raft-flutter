// A level-2 Settings page (`/settings/account/delete`) goes back to its tab
// (SettingsPanel `useMobileBack("/s/<slug>/settings/account")`), not to the
// Settings list, and a tab with no such page keeps the list as its parent.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/data/workspace_navigation.dart';
import 'package:raft_flutter/features/settings_sub_pages.dart';

RaftLocation settings(List<String> path, {String? fragment}) => RaftLocation.at(
  serverSlug: 'acme',
  route: RaftRoute.settings,
  settingsPath: path,
  fragment: fragment,
);

void main() {
  test('the location of a sub-page parses back to its path', () {
    final page = settingsSubPageById('account/delete')!;
    final location = settingsSubPageLocation(
      'acme',
      page,
      query: const {'from': 'row'},
    );
    expect(location.uri.path, '/s/acme/settings/account/delete');
    expect(location.settingsPath, ['account', 'delete']);
    expect(location.query('from'), 'row');
  });

  test('a cold sub-page returns to its parent tab, a tab to the list', () {
    expect(
      WorkspaceNavigation.parentPageOf(settings(['account', 'delete']))
          ?.uri
          .path,
      '/s/acme/settings/account',
    );
    expect(
      WorkspaceNavigation.parentPageOf(settings(['account']))?.uri.path,
      '/s/acme/settings',
    );
    // Not a registered sub-page: unchanged (feedback tickets, unknown slugs).
    expect(
      WorkspaceNavigation.parentPageOf(settings(['account', 'nope']))?.uri.path,
      '/s/acme/settings',
    );
    expect(
      WorkspaceNavigation.parentPageOf(settings(['feedback', 'ticket', 'x']))
          ?.uri
          .path,
      '/s/acme/settings',
    );
  });

  test('Back from a cold sub-page lands on its tab', () {
    final navigation = WorkspaceNavigation(
      initial: settings(['account', 'delete']),
    );
    navigation.mobileTabs = const {'settings'};
    expect(navigation.back().uri.path, '/s/acme/settings/account');
  });

  test('Back from a sub-page opened from its tab returns there', () {
    final navigation = WorkspaceNavigation(initial: settings(['account']));
    navigation.navigate(
      settings(['account', 'delete']),
      kind: RaftNavigationKind.push,
    );
    expect(navigation.back().uri.path, '/s/acme/settings/account');
  });

  test('a section link keeps its fragment in the location', () {
    final location = settings(['account'], fragment: 'two-step');
    expect(location.uri.fragment, 'two-step');
    expect(location.uri.path, '/s/acme/settings/account');
  });
}
