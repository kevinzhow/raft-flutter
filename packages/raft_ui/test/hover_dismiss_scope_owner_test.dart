import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

class _Navigation extends ValueNotifier<String> {
  _Navigation() : super('/channel/a');
  bool get observed => hasListeners;
  void refresh() => notifyListeners();
}

Widget scope(
  _Navigation navigation,
  ValueChanged<RaftHoverDismissController> capture, {
  RaftHoverDismissController? controller,
  String label = 'Body',
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: RaftHoverDismissScope(
    controller: controller,
    navigation: navigation,
    location: () => navigation.value,
    child: Builder(
      builder: (context) {
        capture(RaftHoverDismissScope.maybeOf(context)!);
        return Text(label);
      },
    ),
  ),
);

void main() {
  testWidgets('scope owns one stable controller and releases it on unmount', (
    t,
  ) async {
    final navigation = _Navigation();
    addTearDown(navigation.dispose);
    late RaftHoverDismissController captured;
    await t.pumpWidget(scope(navigation, (value) => captured = value));
    final owned = captured;
    var dismissed = 0;
    owned.addListener(() => dismissed++);
    expect(navigation.observed, isTrue);
    navigation.refresh();
    expect(dismissed, 0);
    navigation.value = '/channel/b';
    expect(dismissed, 1);
    await t.pumpWidget(
      scope(navigation, (value) => captured = value, label: 'Updated body'),
    );
    expect(captured, same(owned));
    expect(dismissed, 1);
    await t.pumpWidget(const SizedBox());
    expect(navigation.observed, isFalse);
    owned.dismiss();
    expect(dismissed, 1);
  });

  testWidgets('an explicit controller remains owned by its caller', (t) async {
    final navigation = _Navigation();
    final external = RaftHoverDismissController();
    addTearDown(navigation.dispose);
    addTearDown(external.dispose);
    var dismissed = 0;
    external.addListener(() => dismissed++);
    await t.pumpWidget(
      scope(
        navigation,
        (value) => expect(value, same(external)),
        controller: external,
      ),
    );
    await t.pumpWidget(const SizedBox());
    expect(navigation.observed, isFalse);
    external.dismiss();
    expect(dismissed, 1);
  });

  testWidgets('switching external ownership preserves the scope controller', (
    t,
  ) async {
    final navigation = _Navigation();
    final external = RaftHoverDismissController();
    addTearDown(navigation.dispose);
    addTearDown(external.dispose);
    late RaftHoverDismissController captured;
    await t.pumpWidget(scope(navigation, (value) => captured = value));
    final owned = captured;
    var ownDismissals = 0, externalDismissals = 0;
    owned.addListener(() => ownDismissals++);
    external.addListener(() => externalDismissals++);
    await t.pumpWidget(
      scope(navigation, (value) => captured = value, controller: external),
    );
    expect(captured, same(external));
    navigation.value = '/agents';
    expect((ownDismissals, externalDismissals), (0, 1));
    await t.pumpWidget(scope(navigation, (value) => captured = value));
    expect(captured, same(owned));
    navigation.value = '/channel/a';
    expect((ownDismissals, externalDismissals), (1, 1));
    await t.pumpWidget(const SizedBox());
    owned.dismiss();
    external.dismiss();
    expect((ownDismissals, externalDismissals), (1, 2));
  });

  testWidgets('changing navigation moves its sole listener to the new owner', (
    t,
  ) async {
    final first = _Navigation(), second = _Navigation();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    late RaftHoverDismissController captured;
    await t.pumpWidget(scope(first, (value) => captured = value));
    final owned = captured;
    var dismissed = 0;
    owned.addListener(() => dismissed++);
    await t.pumpWidget(scope(second, (value) => captured = value));
    expect(captured, same(owned));
    expect(first.observed, isFalse);
    expect(second.observed, isTrue);
    first.value = '/inactive';
    second.refresh();
    expect(dismissed, 0);
    second.value = '/active';
    expect(dismissed, 1);
    await t.pumpWidget(const SizedBox());
    expect(second.observed, isFalse);
  });
}
