import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} compact menu retains touch and keyboard actions',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final focus = FocusNode();
        var calls = 0;
        var enabled = true;
        late StateSetter update;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Center(
                child: RaftDensityScope(
                  density: RaftDensity.touch,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return Semantics(
                        role: SemanticsRole.menu,
                        child: SizedBox(
                          width: 200,
                          height: 80,
                          child: Center(
                            child: RaftMenuItem(
                              label: 'Direct message',
                              leading: const RaftDirectMessageIcon(size: 14),
                              focusNode: focus,
                              onPressed: enabled ? () => calls++ : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final row = find.byType(RaftMenuItem);
        final rect = t.getRect(row);
        final tokens = raftTheme(dark: dark).extension<RaftTokens>()!;
        expect(rect.height, tokens.isRaftLook ? 36 : 31.5);
        await t.tapAt(Offset(rect.center.dx, rect.bottom + 5));
        await t.pump();
        expect(calls, 1);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(calls, 2);
        final semantics = t.ensureSemantics();
        try {
          expect(t, meetsGuideline(androidTapTargetGuideline));
          expect(t, meetsGuideline(labeledTapTargetGuideline));
        } finally {
          semantics.dispose();
        }
        update(() => enabled = false);
        await t.pump();
        await t.tap(row);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(calls, 2);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        focus.dispose();
      },
    );
  }
}
