import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/mobile_route_gate.dart';

/// Stands in for a phone route: it owns the cover flag the gate reads.
class _Route extends StatefulWidget {
  const _Route({super.key, required this.child});
  final Widget child;
  @override
  State<_Route> createState() => _RouteState();
}

class _RouteState extends State<_Route> {
  static final location = RaftLocation.at(
    serverSlug: 'x',
    route: RaftRoute.home,
  );
  @override
  void initState() {
    super.initState();
    MobileRouteGate.write(this, covered: false, location: location);
  }

  void cover(bool covered) =>
      MobileRouteGate.write(this, covered: covered, location: location);

  @override
  Widget build(BuildContext context) => MobileRouteGate(child: widget.child);
}

/// A stand-in for the page content: what it shows follows [value].
class _Page extends PhonePageState<_PageWidget> {
  @override
  Widget buildLive(BuildContext context) => Text('page ${widget.value.value}');
}

class _PageWidget extends StatefulWidget {
  const _PageWidget(this.value);
  final ValueNotifier<String> value;
  @override
  State<_PageWidget> createState() => _Page();
}

void main() {
  for (final page in [false, true]) {
    testWidgets(
      'a retained ${page ? 'page state' : 'subtree'} is built again the moment '
      'its route is current, without any ticker or ancestor change',
      (tester) async {
        final value = ValueNotifier('old');
        addTearDown(value.dispose);
        final routeKey = GlobalKey<State<_Route>>();
        Widget content() => page
            ? _PageWidget(value)
            : RetainWhileCovered(builder: (_) => Text('page ${value.value}'));
        Widget tree() => MaterialApp(
          home: _Route(key: routeKey, child: content()),
        );
        await tester.pumpWidget(tree());
        expect(find.text('page old'), findsOneWidget);

        final route = routeKey.currentState! as _RouteState;
        route.cover(true);
        value.value = 'new';
        // Something above rebuilds the covered page: it keeps its last build.
        await tester.pumpWidget(tree());
        expect(find.text('page old'), findsOneWidget, reason: 'retained');

        // The route is current again. Nothing else changes: no ticker mode,
        // no new widget above.
        route.cover(false);
        await tester.pump();
        expect(find.text('page new'), findsOneWidget, reason: 'refreshed');
        expect(find.text('page old'), findsNothing);
      },
    );
  }
}
