// The v1.21.12 announcement dialog: label, picture and call to action.
// Mirrors packages/web/tests/announcementModal.behavior.test.tsx.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/announcement_store.dart';
import 'package:raft_flutter/features/announcement_cta.dart';
import 'package:raft_flutter/features/announcement_host.dart';
import 'package:raft_ui/raft_ui.dart';

import 'announcement_host_test.dart' as host;

const assetId = '8d1c2f7e-00a1-4b6a-9d7e-0000000000a1';

Map<String, dynamic> row({
  String? label,
  Map<String, String>? cta,
  Map<String, String>? image,
}) => {
  ...host.announcement('a1', pages: 1),
  'label': ?label,
  'cta': ?cta,
  'image': ?image,
};

Future<(host.Fixture, List<String>)> mount(
  WidgetTester t,
  Map<String, dynamic> announcement,
) async {
  final f = host.Fixture()..active = [announcement];
  final opened = <String>[];
  // A bound workspace, as after sign-in (reading the location binds it).
  expect(f.w.location.uri.path, '/s/visual');
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      builder: (context, child) => RaftToastHost(child: child!),
      home: AnnouncementHost(
        controller: f.w,
        openLink: opened.add,
        child: const Scaffold(body: Text('workspace')),
      ),
    ),
  );
  await host.settle(t);
  return (f, opened);
}

void main() {
  testWidgets('a label replaces "Latest updates"; Got it is the only action', (
    t,
  ) async {
    final (f, _) = await mount(t, row(label: 'Release'));
    expect(find.text('Release'), findsOneWidget);
    expect(find.text('Latest updates'), findsNothing);
    expect(find.text('Got it'), findsOneWidget);
    expect(find.byKey(const ValueKey('announcement-dismiss')), findsNothing);
    expect(f.count('POST'), 0);
  });

  testWidgets('an external CTA opens the URL and records the dismissal', (
    t,
  ) async {
    final (f, opened) = await mount(
      t,
      row(cta: {'label': 'Read more', 'href': 'https://example.com/update'}),
    );
    expect(find.text('Read more'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('announcement-ok')));
    await host.settle(t);
    expect(opened, ['https://example.com/update']);
    expect(f.count('POST /announcements/a1/dismiss'), 1);
    expect(host.modal, findsNothing);
  });

  testWidgets('Enter activates the CTA once', (t) async {
    final (f, opened) = await mount(
      t,
      row(cta: {'label': 'Read more', 'href': 'https://example.com/update'}),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await host.settle(t);
    expect(opened, ['https://example.com/update']);
    expect(f.count('POST /announcements/a1/dismiss'), 1);
  });

  testWidgets('Got it dismisses without opening the CTA', (t) async {
    final (f, opened) = await mount(
      t,
      row(cta: {'label': 'Read more', 'href': 'https://example.com'}),
    );
    await t.tap(find.byKey(const ValueKey('announcement-dismiss')));
    await host.settle(t);
    expect(opened, isEmpty);
    expect(f.count('POST /announcements/a1/dismiss'), 1);
    expect(host.modal, findsNothing);
  });

  testWidgets('an internal CTA inside the server navigates in the app', (
    t,
  ) async {
    final (f, opened) = await mount(
      t,
      row(cta: {'label': 'Open', 'href': '/s/visual/tasks'}),
    );
    await t.tap(find.byKey(const ValueKey('announcement-ok')));
    await host.settle(t);
    expect(opened, isEmpty);
    expect(f.w.location.uri.path, '/s/visual/tasks');
    expect(f.count('POST /announcements/a1/dismiss'), 1);
  });

  testWidgets('an internal CTA the app does not host opens on the Web origin', (
    t,
  ) async {
    final (_, opened) = await mount(
      t,
      row(cta: {'label': 'Open', 'href': '/s/other/channel/c1'}),
    );
    await t.tap(find.byKey(const ValueKey('announcement-ok')));
    await host.settle(t);
    expect(opened, ['https://fixture.invalid/s/other/channel/c1']);
  });

  testWidgets('the picture comes from the public image route with its alt', (
    t,
  ) async {
    await mount(t, row(image: {'assetId': assetId, 'alt': 'Channel diagram'}));
    final image = t.widget<RaftSizedImage>(find.byType(RaftSizedImage));
    expect(
      (image.image as NetworkImage).url,
      'https://fixture.invalid/api/announcements/images/$assetId',
    );
    expect(image.semanticLabel, 'Channel diagram');
    expect(
      announcementImageUrl('https://api.example.com', assetId),
      'https://api.example.com/api/announcements/images/$assetId',
    );
  });

  test('the wire fields parse; malformed ones are dropped', () {
    final full = Announcement.fromJson(
      row(
        label: ' Release ',
        cta: {'label': ' Go ', 'href': '?dialog=create-joint-channel'},
        image: {'assetId': assetId, 'alt': 'x'},
      ),
    )!;
    expect(full.label, 'Release');
    expect(full.cta?.label, 'Go');
    expect(full.cta?.internal, isTrue);
    expect(full.image?.assetId, assetId);
    final bad = Announcement.fromJson({
      ...row(),
      'label': '  ',
      'cta': {'label': '', 'href': 'https://example.com'},
      'image': {'assetId': 3},
    })!;
    expect(bad.label, isNull);
    expect(bad.cta, isNull);
    expect(bad.image, isNull);
    expect(
      Announcement.fromJson(
        row(cta: {'label': 'x', 'href': 'https://example.com'}),
      )!.cta!.internal,
      isFalse,
    );
  });
}
