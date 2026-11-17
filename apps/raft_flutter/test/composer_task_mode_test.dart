// The composer's As task toggle offers As task to the Tasks card's "+"
// (Web useComposerTaskModeTarget): registered while mounted, for its channel.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/composer_task_mode.dart';

void main() {
  Widget target(String? channelId, VoidCallback onTurnOn) => Directionality(
    textDirection: TextDirection.ltr,
    child: ComposerTaskModeTarget(
      channelId: channelId,
      onTurnOn: onTurnOn,
      child: const SizedBox(),
    ),
  );

  testWidgets('a mounted toggle takes the request for its channel', (t) async {
    var on = 0;
    await t.pumpWidget(target('c1', () => on++));
    expect(ComposerTaskModeTargets.request('c2'), isFalse);
    expect(ComposerTaskModeTargets.request('c1'), isTrue);
    expect(on, 1);
  });

  testWidgets('switching channel moves the offer; unmounting withdraws it', (
    t,
  ) async {
    var on = 0;
    await t.pumpWidget(target('c1', () => on++));
    await t.pumpWidget(target('c2', () => on++));
    expect(ComposerTaskModeTargets.request('c1'), isFalse);
    expect(ComposerTaskModeTargets.request('c2'), isTrue);
    await t.pumpWidget(const SizedBox());
    expect(ComposerTaskModeTargets.request('c2'), isFalse);
    expect(on, 1);
  });

  testWidgets('no channel offers nothing', (t) async {
    await t.pumpWidget(target(null, () {}));
    expect(ComposerTaskModeTargets.request('c1'), isFalse);
  });
}
