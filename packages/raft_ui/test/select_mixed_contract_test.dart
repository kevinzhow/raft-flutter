import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

/// The frozen looks (Elegant, Brutal) read the Select trigger's fill and elevation from their pack tokens
/// (`layer-select*`, `shadow.select*`), whatever their edge and motion options say. The Raft look draws the
/// trigger from the `select` and `button` recipes (raft_select_spec_test).
void main() {
  for (final pack in [builtInElegantTheme, builtInBrutalTheme]) {
    testWidgets('${pack.id} Select trigger reads its pack elevation and fill', (
      t,
    ) async {
      TestGesture? mouse;
      addTearDown(() async {
        if (mouse != null) await mouse.removePointer();
        await t.pumpWidget(const SizedBox());
      });
      late RaftTokens tokens;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: pack).copyWith(platform: TargetPlatform.linux),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: Builder(
                  builder: (context) {
                    tokens = RaftTokens.of(context);
                    return RaftSelectField<String>(
                      value: 'a',
                      items: const [RaftSelectItem(value: 'a', label: 'Alpha')],
                      onChanged: (_) {},
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      void expectElevation(String role) {
        final box = t.widget<RaftRecipeBox>(find.byType(RaftRecipeBox).first);
        final layers = box.style.cssShadows(box.tokens);
        for (final want in tokens.shadowLayers(role)) {
          expect(
            layers.where(
              (l) => l.offset == want.offset && l.color == want.color,
            ),
            isNotEmpty,
            reason: '$role ${want.offset}',
          );
        }
      }

      Color? fill() {
        final box = t.widget<RaftRecipeBox>(find.byType(RaftRecipeBox).first);
        return box.style.backgroundColor?.resolve(box.tokens);
      }

      expectElevation('shadow.select');
      expect(fill(), tokens.colors['layer-select']);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      expectElevation('shadow.selectFocus');
      mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      final center = t.getCenter(find.byType(RaftSelectField<String>));
      await mouse.moveTo(center);
      await t.pump(const Duration(milliseconds: 200));
      expect(fill(), tokens.colors['layer-select-hover']);
      await mouse.down(center);
      await t.pump(const Duration(milliseconds: 200));
      await mouse.up();
      expect(t.takeException(), isNull);
    });
  }
}
