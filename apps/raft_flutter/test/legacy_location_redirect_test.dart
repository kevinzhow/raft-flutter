import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

// Web useRailLegacyRedirect29–64 (mounted once in MainLayout, REPLACE only):
//   /s/<slug>/machine/<id>          -> /s/<slug>/computer/<id>
//   /s/<slug>?sidebarTab=members    -> /s/<slug>/members
//   /s/<slug>?sidebarTab=computers  -> /s/<slug>/computers
//   /s/<slug>?tab=machines          -> /s/<slug>/computers
//   any other path: drop sidebarTab and tab=machines|messages
// All other query keys stay intact. Driven through the actual RaftApp with
// its initial platform route and a later engine pushRouteInformation.
const _cases = [
  ('/s/alpha/machine/m1?keep=one', '/s/alpha/computer/m1?keep=one'),
  ('/s/alpha?sidebarTab=members&keep=one', '/s/alpha/members?keep=one'),
  ('/s/alpha?sidebarTab=computers', '/s/alpha/computers'),
  ('/s/alpha?tab=machines&keep=one', '/s/alpha/computers?keep=one'),
  (
    '/s/alpha/channel/ca?sidebarTab=members&keep=one&q=two',
    '/s/alpha/channel/ca?keep=one&q=two',
  ),
  ('/s/alpha/channel/ca?tab=messages&keep=one', '/s/alpha/channel/ca?keep=one'),
];

bool _same(Uri actual, String expected) {
  final want = Uri.parse(expected);
  return actual.path == want.path &&
      actual.queryParameters.length == want.queryParameters.length &&
      want.queryParameters.entries.every(
        (e) => actual.queryParameters[e.key] == e.value,
      );
}

void main() {
  for (final theme in ['brutal', 'elegant-light']) {
    for (final (legacy, expected) in _cases) {
      testWidgets('[N10] $theme cold start $legacy is replaced by $expected', (
        t,
      ) async {
        final f = RootFixture();
        await f.mount(t, theme, 1280, uri: Uri.parse(legacy));
        expect(find.byType(WorkspaceView), findsOneWidget);
        final w = f.workspace(t);
        expect(
          _same(w.location.uri, expected),
          isTrue,
          reason: 'location ${w.location}',
        );
        expect(
          _same(f.router(t).currentConfiguration, expected),
          isTrue,
          reason: 'router ${f.router(t).currentConfiguration}',
        );
        // Replace-only: the legacy shape never owns a history entry; the
        // canonical location replaces it (same entries as a canonical
        // cold start: the bound server root, then the requested surface).
        expect(
          w.navigation.entries.where((e) => _same(e.uri, legacy)),
          isEmpty,
        );
        expect(
          w.navigation.entries.where((e) => _same(e.uri, expected)),
          hasLength(1),
        );
        expect(_same(w.navigation.entries.last.uri, expected), isTrue);
        final reported = f.engineRoutes.last;
        expect(_same(Uri.parse('${reported['uri']}'), expected), isTrue);
        expect(f.engineRoutes.every((r) => r['replace'] == true), isTrue);
        expect(
          f.engineRoutes.where((r) => _same(Uri.parse('${r['uri']}'), legacy)),
          isEmpty,
        );
        await f.close(t);
      });
    }
    testWidgets('[N10] $theme a later legacy link is canonicalized in place', (
      t,
    ) async {
      final f = RootFixture();
      await f.mount(t, theme, 1280, uri: Uri.parse('/s/alpha/channel/ca'));
      final w = f.workspace(t);
      final entries = w.navigation.entries.length;
      for (final (legacy, expected) in _cases) {
        await f.pushUri(t, legacy);
        expect(
          _same(w.location.uri, expected),
          isTrue,
          reason: '$legacy -> ${w.location}',
        );
        expect(_same(f.router(t).currentConfiguration, expected), isTrue);
        expect(
          w.navigation.entries.where((e) => _same(e.uri, legacy)),
          isEmpty,
        );
      }
      // Each delivered link owns at most its own entry; the legacy shape none.
      expect(
        w.navigation.entries.length,
        lessThanOrEqualTo(entries + _cases.length),
      );
      await f.close(t);
    });
  }
}
