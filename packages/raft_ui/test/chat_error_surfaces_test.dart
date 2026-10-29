import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Chat-area error rows use the Web Banner (`intent="warning"`), not hand-rolled
// red text: the action card, the forward composer, the mention-action notice,
// the notification settings card and the selection bar.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: raftTheme(),
    home: Scaffold(body: SizedBox(width: 480, child: child)),
  );

  testWidgets('action card error is a small warning banner', (t) async {
    await t.pumpWidget(
      host(
        const RaftActionCard(
          title: 'Create public channel #design',
          state: 'prepared',
          error: 'Failed to execute action',
        ),
      ),
    );
    expect(find.byType(RaftBanner), findsOneWidget);
    expect(find.text('Failed to execute action'), findsOneWidget);
  });

  testWidgets('forward note bar carries the error banner', (t) async {
    await t.pumpWidget(
      host(
        SizedBox(
          height: 600,
          child: RaftForwardPreviewStep(
            previewLabel: 'Message preview',
            preview: const Text('preview'),
            noteLabel: 'Optional note',
            note: const SizedBox(height: 40),
            send: const SizedBox(width: 28, height: 28),
            error:
                'We couldn\'t confirm whether the forward finished. '
                'It\'s safe to try again.',
          ),
        ),
      ),
    );
    expect(find.byType(RaftBanner), findsOneWidget);
    final banner = t.getRect(find.byType(RaftBanner));
    final label = t.getRect(find.text('Optional note'));
    final preview = t.getRect(find.text('preview'));
    // Web MessageInput's error row sits in the note area, below the label.
    expect(banner.top, greaterThan(label.bottom - 1));
    expect(banner.top, greaterThan(preview.bottom));
  });

  testWidgets('mention action notice is the Web status box', (t) async {
    await t.pumpWidget(
      host(
        const RaftPendingMentionSlot(
          notice: 'This mention action has expired.',
          strip: SizedBox(height: 10),
        ),
      ),
    );
    expect(find.text('This mention action has expired.'), findsOneWidget);
    final text = t.widget<Text>(find.text('This mention action has expired.'));
    expect(text.style?.fontWeight, FontWeight.w700);
    expect(text.style?.fontSize, 11);
  });

  testWidgets('notification settings error uses the shared banner', (t) async {
    await t.pumpWidget(
      host(
        RaftNotificationSettingsCard(
          title: 'DMs',
          description: 'Delivery description',
          status: 'Unavailable',
          actionLabel: 'Enable Notifications',
          muted: false,
          muteDescription: 'Stops notifications.',
          onMutedChanged: (_) {},
          error: 'Failed to update server notification setting.',
        ),
      ),
    );
    expect(find.byType(RaftBanner), findsOneWidget);
    expect(
      find.text('Failed to update server notification setting.'),
      findsOneWidget,
    );
  });
}
