// The heading sticker of the pending and requested pages (Web
// AccountDeletionFrame.tsx: `rounded-sticker border-[1.5px]
// border-sticker-ink bg-you shadow-sticker`): its only shadow is the
// --elevation-sticker token of the theme, in light and in dark.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/account_deletion_frame.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('${dark ? 'dark' : 'light'}: shadow-sticker, no ring', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: const Scaffold(
            body: AccountDeletionHeading(
              glyph: RaftGlyph.calendarCheck,
              title: 'Deletion scheduled',
            ),
          ),
        ),
      );
      final sticker = t.widget<Container>(
        find.byKey(const ValueKey('account-deletion-sticker')),
      );
      final decoration = sticker.decoration! as BoxDecoration;
      final token = dark
          ? RaftDark.elevationSticker
          : RaftLight.elevationSticker;
      expect(decoration.boxShadow, token.paintOrder);
      expect(decoration.boxShadow!.single.offset, const Offset(4, 4));
      expect(decoration.boxShadow!.single.spreadRadius, 0);
    });
  }
}
