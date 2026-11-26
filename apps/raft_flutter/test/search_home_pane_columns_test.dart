import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_search.dart';
import 'package:raft_flutter/features/search_home.dart';
import 'package:raft_ui/raft_ui.dart';

/// Search home is the master column of the desktop split (400-720 px wide),
/// so its tile grid must count its columns from its own width. Reading the
/// window gave two columns inside a pane that only fits one.
void main() {
  const frequent = [
    SearchEntity('channel', 'c1', 'design', 'Channel', {}),
    SearchEntity('user', 'u1', 'Alice', 'Member', {}),
    SearchEntity('agent', 'a1', 'Cindy', 'Agent', {}),
  ];

  Future<void> mount(WidgetTester t, {required double pane}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1280, 900);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: pane,
                child: const ResourceSearchHome(
                  history: [],
                  frequent: frequent,
                  origin: 'https://fixture.invalid',
                  onQuery: _ignoreQuery,
                  onRemove: _ignoreQuery,
                  onClear: _ignore,
                  onEntity: _ignoreEntity,
                ),
              ),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );
    await t.pump();
  }

  final first = find.byKey(const ValueKey('search-frequent-channel:c1'));
  final second = find.byKey(const ValueKey('search-frequent-user:u1'));

  testWidgets('a narrow pane inside a wide window stacks the tiles', (t) async {
    await mount(t, pane: 420);
    expect(t.getRect(first).left, t.getRect(second).left);
    expect(t.getRect(second).top, greaterThan(t.getRect(first).top));
  });

  testWidgets('a pane wide enough for two columns still pairs them', (t) async {
    await mount(t, pane: 760);
    expect(t.getRect(second).left, greaterThan(t.getRect(first).left));
    expect(t.getRect(second).top, t.getRect(first).top);
  });
}

void _ignore() {}
void _ignoreQuery(String _) {}
void _ignoreEntity(SearchEntity _) {}
