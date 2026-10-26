import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

// The channel / DM settings drawer as Web mounts it (ChannelOverflowMenu ->
// OverflowSheet + EditChannelDialog presentation="panel").

const _ownerCaps = {
  'editChannelMetadata': true,
  'archiveChannels': true,
  'deleteChannels': true,
  'changeChannelVisibility': true,
  'manageGuestAccess': true,
  'federateChannels': false,
  'addChannelMembers': true,
  'removeChannelMembers': true,
  'changeChannelMemberRoles': true,
};

Map<String, dynamic> _row({
  String id = 'c1',
  String name = 'work',
  String type = 'channel',
  String description = 'Release gates',
  Map<String, dynamic>? caps = _ownerCaps,
  Map<String, dynamic> extra = const {},
}) => {
  'id': id,
  'name': name,
  'type': type,
  'description': description,
  'joined': true,
  'activityMuteSupported': true,
  'channelCapabilities': ?caps,
  ...extra,
};

void _routes(MessageAdapter api, {List<Map<String, dynamic>>? channels}) {
  api.routes['GET /channels/c1/members'] = (_) => {
    'humans': [
      {'id': 'u1', 'userId': 'u1', 'name': 'ana', 'displayName': 'Ana'},
      {'id': 'u2', 'userId': 'u2', 'name': 'bo', 'displayName': 'Bo'},
    ],
    'agents': [
      {'id': 'a1', 'name': 'cindy', 'displayName': 'Cindy', 'status': 'active'},
    ],
  };
  api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
  api.routes['GET /channels/c1/message-display-settings'] = (_) => {
    'collapseLongMessages': true,
  };
  api.routes['GET /channels/c1/notification-settings'] = (_) => {
    'activityMuted': false,
  };
  api.routes['POST /feature-flags/evaluate'] = (_) => {
    'evaluations': [
      {'key': 'server_guest_v0', 'enabled': true},
    ],
  };
  api.routes['GET /channels'] = (_) => channels ?? [_row()];
  api.routes['GET /channels/dm'] = (_) => [];
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
}

/// Opens the drawer through its real route, from a host page.
Future<(WorkspaceController, MessageAdapter)> _open(
  WidgetTester t, {
  String role = 'owner',
  Map<String, dynamic>? row,
  String? dmName,
  Size size = const Size(1280, 1800),
  bool dark = false,
  Locale locale = const Locale('en'),
  RaftThemePack? pack,
}) async {
  final (w, api) = (await t.runAsync(() => fixture(role)))!;
  addTearDown(w.dispose);
  final data = row ?? _row();
  _routes(api, channels: [data]);
  final channel = RaftChannel(data);
  if (channel.type == 'dm') {
    w
      ..channels = []
      ..dms = [channel];
  } else {
    w.channels = [channel];
  }
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark, pack: pack, locale: locale),
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('host-open'),
              onPressed: () => ChannelSettings.show(
                context,
                controller: w,
                channel: channel,
                dmName: dmName,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.byKey(const ValueKey('host-open')));
  await t.pumpAndSettle();
  return (w, api);
}

Finder _id(String id) => find.byKey(ValueKey(id));
List<RequestOptions> _writes(MessageAdapter api) => api.calls
    .where(
      (c) =>
          c.method != 'GET' &&
          !c.path.startsWith('/auth/') &&
          !c.path.startsWith('/feature-flags/'),
    )
    .toList();

TextEditingController _controller(WidgetTester t, String id) => t
    .widget<TextField>(
      find
              .descendant(of: _id(id), matching: find.byType(TextField))
              .evaluate()
              .isEmpty
          ? _id(id)
          : find.descendant(of: _id(id), matching: find.byType(TextField)),
    )
    .controller!;

void main() {
  testWidgets(
    'owner drawer: identity header, members, info, preferences, actions in Web order',
    (t) async {
      await _open(t);
      final sheet = t.widget<RaftOverflowSheet>(find.byType(RaftOverflowSheet));
      expect(sheet.title, '#work');
      expect(sheet.badge, 'Public');
      expect(sheet.subtitle, 'Release gates');
      expect(find.text('3 humans · 1 agent'), findsNothing);
      expect(find.text('2 humans · 1 agent'), findsOneWidget);
      // Sections top to bottom: Members, Info, Preferences, Actions.
      double y(Finder f) => t.getTopLeft(f).dy;
      expect(y(find.text('Members')) < y(find.text('Info')), isTrue);
      expect(y(find.text('Info')) < y(find.text('Preferences')), isTrue);
      expect(y(find.text('Preferences')) < y(find.text('Actions')), isTrue);
      // Action rows: visibility, archive, leave, stop agents, delete (filled).
      final order = [
        'channel-settings-visibility-action',
        'channel-overflow-leave',
        'channel-overflow-stop-agents',
        'channel-settings-delete-action',
      ];
      final archiveY = y(_id('channel-settings-archive-action'));
      expect(y(_id(order[0])) < archiveY, isTrue);
      expect(archiveY < y(_id(order[1])), isTrue);
      for (var i = 1; i < order.length - 1; i++) {
        expect(
          y(_id(order[i])) < y(_id(order[i + 1])),
          isTrue,
          reason: order[i],
        );
      }
      // Only Delete is a filled danger button; the rest are outline.
      RaftButtonRecipeVariant variant(String id) =>
          t.widget<RaftSettingsRecipeButton>(_id(id)).variant;
      expect(
        variant('channel-settings-delete-action'),
        RaftButtonRecipeVariant.danger,
      );
      for (final id in order.take(3)) {
        expect(variant(id), RaftButtonRecipeVariant.outline, reason: id);
      }
      // Pin, mute and collapse live in Preferences.
      for (final label in [
        'Pin Channel',
        'Mute activity',
        'Collapse long messages',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    },
  );

  testWidgets('member drawer shows only members, preferences and Leave', (
    t,
  ) async {
    await _open(
      t,
      role: 'member',
      row: _row(caps: {'addChannelMembers': true}),
    );
    expect(find.byType(RaftChannelInfoForm), findsNothing);
    expect(find.text('Info'), findsNothing);
    expect(_id('channel-overflow-leave'), findsOneWidget);
    expect(_id('channel-overflow-stop-agents'), findsOneWidget);
    for (final id in [
      'channel-settings-visibility-action',
      'channel-settings-archive-action',
      'channel-settings-delete-action',
    ]) {
      expect(_id(id), findsNothing, reason: id);
    }
    expect(find.text('Guest access'), findsNothing);
  });

  testWidgets('DM drawer: peer name, Direct message badge, preferences only', (
    t,
  ) async {
    await _open(
      t,
      row: _row(
        id: 'c1',
        name: 'dm-cindy',
        type: 'dm',
        description: '',
        caps: null,
        extra: {'activityMuteSupported': false},
      ),
      dmName: 'Cindy',
    );
    final sheet = t.widget<RaftOverflowSheet>(find.byType(RaftOverflowSheet));
    expect(sheet.title, 'Cindy');
    expect(sheet.badge, 'Direct message');
    expect(find.byType(RaftMembersStrip), findsNothing);
    expect(find.byType(RaftChannelInfoForm), findsNothing);
    expect(find.text('Actions'), findsNothing);
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Pin Channel'), findsOneWidget);
    expect(find.text('Collapse long messages'), findsOneWidget);
    expect(find.text('Mute activity'), findsNothing);
    // A DM never asks for the roster.
    expect(
      t
          .widget<RaftSwitch>(
            find.byWidgetPredicate(
              (w) => w is RaftSwitch && w.semanticLabel == 'Pin Channel',
            ),
          )
          .value,
      false,
    );
  });

  testWidgets('private channel offers Make Public with the private badge', (
    t,
  ) async {
    await _open(t, row: _row(type: 'private'));
    expect(
      t.widget<RaftOverflowSheet>(find.byType(RaftOverflowSheet)).badge,
      'Private',
    );
    expect(find.text('Make Public'), findsOneWidget);
    expect(find.text('Make Private'), findsNothing);
    // A private channel has no guest policy.
    expect(find.text('Guest access'), findsNothing);
  });

  testWidgets(
    'an authored newline stays in the field and is collapsed in the header',
    (t) async {
      await _open(t, row: _row(description: 'line one\nline two'));
      expect(
        t.widget<RaftOverflowSheet>(find.byType(RaftOverflowSheet)).subtitle,
        'line one\nline two',
      );
      expect(find.text('line one line two'), findsOneWidget);
      expect(
        _controller(t, 'channel-settings-description').text,
        'line one\nline two',
      );
    },
  );

  testWidgets(
    'inline Save sends only the changed field and keeps the drawer open',
    (t) async {
      final (w, api) = await _open(t);
      api.routes['PATCH /channels/c1'] = (_) => _row(name: 'renamed');
      api.routes['GET /channels'] = (_) => [_row(name: 'renamed')];
      final save = _id('channel-settings-save-inline');
      expect(t.widget<RaftSettingsRecipeButton>(save).onPressed, isNull);
      await t.enterText(_id('channel-settings-name'), 'renamed');
      await t.pump();
      expect(t.widget<RaftSettingsRecipeButton>(save).onPressed, isNotNull);
      await t.tap(save);
      await t.pumpAndSettle(const Duration(milliseconds: 100));
      final patch = _writes(api).single;
      expect(patch.path, '/channels/c1');
      expect(patch.data, {'name': 'renamed'});
      expect(find.byType(RaftOverflowSheet), findsOneWidget);
      expect(w.channels.single.name, 'renamed');
      // "Changes saved" shows on the button, then Save is clean again.
      expect(find.text('Changes saved'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1600));
      expect(find.text('Save'), findsOneWidget);
      expect(t.widget<RaftSettingsRecipeButton>(save).onPressed, isNull);
    },
  );

  testWidgets('Cancel restores the saved name and description', (t) async {
    await _open(t);
    await t.enterText(_id('channel-settings-name'), 'draft');
    await t.enterText(_id('channel-settings-description'), 'draft description');
    await t.pump();
    await t.tap(_id('channel-settings-discard-draft'));
    await t.pump();
    expect(_controller(t, 'channel-settings-name').text, 'work');
    expect(
      _controller(t, 'channel-settings-description').text,
      'Release gates',
    );
    expect(
      t
          .widget<RaftSettingsRecipeButton>(_id('channel-settings-save-inline'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('an invalid name is rejected before any request', (t) async {
    final (_, api) = await _open(t);
    await t.enterText(_id('channel-settings-name'), '1bad name');
    await t.pump();
    await t.tap(_id('channel-settings-save-inline'));
    await t.pumpAndSettle();
    expect(_writes(api), isEmpty);
    expect(
      find.text('Start with a letter, then letters, numbers, - or _'),
      findsOneWidget,
    );
    await t.enterText(_id('channel-settings-name'), '   ');
    await t.pump();
    await t.tap(_id('channel-settings-save-inline'));
    await t.pumpAndSettle();
    expect(find.text('Channel name is required'), findsOneWidget);
  });

  group('unsaved draft guard', () {
    testWidgets('Keep editing stays; Discard closes without saving', (t) async {
      final (_, api) = await _open(t);
      await t.enterText(_id('channel-settings-name'), 'draft');
      await t.pump();
      await t.tapAt(const Offset(20, 20)); // the scrim
      await t.pumpAndSettle();
      expect(_id('channel-overflow-unsaved-prompt'), findsOneWidget);
      await t.tap(find.text('Keep Editing'));
      await t.pumpAndSettle();
      expect(find.byType(RaftOverflowSheet), findsOneWidget);
      expect(_controller(t, 'channel-settings-name').text, 'draft');
      await t.tap(_id('channel-overflow-scrim'));
      await t.pumpAndSettle();
      await t.tap(_id('channel-overflow-unsaved-discard'));
      await t.pumpAndSettle();
      expect(find.byType(RaftOverflowSheet), findsNothing);
      expect(_writes(api), isEmpty);
    });

    testWidgets('Save and close saves, then closes', (t) async {
      final (_, api) = await _open(t);
      api.routes['PATCH /channels/c1'] = (_) => _row(name: 'draft');
      api.routes['GET /channels'] = (_) => [_row(name: 'draft')];
      await t.enterText(_id('channel-settings-name'), 'draft');
      await t.pump();
      await t.tap(_id('channel-overflow-scrim'));
      await t.pumpAndSettle();
      await t.tap(_id('channel-overflow-unsaved-save'));
      await t.pumpAndSettle(const Duration(milliseconds: 100));
      expect(_writes(api).single.data, {'name': 'draft'});
      expect(find.byType(RaftOverflowSheet), findsNothing);
    });

    testWidgets('a clean drawer closes straight from the scrim', (t) async {
      await _open(t);
      await t.tap(_id('channel-overflow-scrim'));
      await t.pumpAndSettle();
      expect(find.byType(RaftOverflowSheet), findsNothing);
      expect(_id('channel-overflow-unsaved-prompt'), findsNothing);
    });
  });

  group('confirmations', () {
    Future<void> press(WidgetTester t, String id) async {
      await t.ensureVisible(_id(id));
      await t.tap(_id(id));
      await t.pumpAndSettle();
      expect(_id('channel-settings-confirm-dialog'), findsOneWidget);
    }

    Future<void> confirm(WidgetTester t, String label) async {
      await t.tap(
        find
            .descendant(
              of: _id('channel-settings-confirm-dialog'),
              matching: find.text(label),
            )
            .last,
      );
      await t.pumpAndSettle(const Duration(milliseconds: 100));
    }

    testWidgets('archive: warning copy, POST, then the drawer closes', (
      t,
    ) async {
      final (_, api) = await _open(t);
      api.routes['POST /channels/c1/archive'] = (_) => _row();
      await press(t, 'channel-settings-archive-action');
      expect(
        find.textContaining('Members keep read access to "work"'),
        findsOneWidget,
      );
      await confirm(t, 'Archive Channel');
      expect(_writes(api).map((c) => '${c.method} ${c.path}'), [
        'POST /channels/c1/archive',
      ]);
      expect(find.byType(RaftOverflowSheet), findsNothing);
    });

    testWidgets('a failed archive keeps the drawer open with the error', (
      t,
    ) async {
      final (_, api) = await _open(t);
      api.routes['POST /channels/c1/archive'] = (_) => throw StateError('x');
      await press(t, 'channel-settings-archive-action');
      await confirm(t, 'Archive Channel');
      expect(find.byType(RaftOverflowSheet), findsOneWidget);
      expect(_id('channel-settings-confirm-dialog'), findsNothing);
      expect(find.byType(RaftErrorBanner), findsOneWidget);
    });

    testWidgets('visibility PATCHes the opposite visibility', (t) async {
      final (_, api) = await _open(t);
      api.routes['PATCH /channels/c1'] = (_) => _row(type: 'private');
      await press(t, 'channel-settings-visibility-action');
      expect(find.text('Make Private'), findsNWidgets(3));
      await confirm(t, 'Make Private');
      final patch = _writes(api).single;
      expect(patch.path, '/channels/c1');
      expect(patch.data, {'visibility': 'private'});
      expect(find.byType(RaftOverflowSheet), findsNothing);
    });

    testWidgets('leave closes the drawer', (t) async {
      final (_, api) = await _open(
        t,
        role: 'member',
        row: _row(caps: {'addChannelMembers': true}),
      );
      api.routes['POST /channels/c1/leave'] = (_) => {};
      await press(t, 'channel-overflow-leave');
      await confirm(t, 'Leave Channel');
      expect(_writes(api).single.path, '/channels/c1/leave');
      expect(find.byType(RaftOverflowSheet), findsNothing);
    });

    for (final dark in [false, true]) {
      for (final locale in [const Locale('en'), const Locale('zh')]) {
        testWidgets('Web delete confirmation ${locale.languageCode}/$dark', (
          t,
        ) async {
          final (_, api) = await _open(t, dark: dark, locale: locale);
          api.routes['DELETE /channels/c1'] = (_) => {};
          api.routes['GET /channels'] = (_) => [];
          final cancel = locale.languageCode == 'zh' ? '取消' : 'Cancel';
          final delete = locale.languageCode == 'zh' ? '删除' : 'Delete';
          Finder inDialog(String text) => find.descendant(
            of: _id('channel-settings-confirm-dialog'),
            matching: find.text(text),
          );

          await press(t, 'channel-settings-delete-action');
          expect(inDialog(cancel), findsOneWidget);
          expect(inDialog(delete), findsOneWidget);
          expect(_writes(api), isEmpty);
          await t.tap(inDialog(cancel));
          await t.pumpAndSettle();
          expect(_id('channel-settings-confirm-dialog'), findsNothing);
          expect(find.byType(RaftOverflowSheet), findsOneWidget);
          expect(_writes(api), isEmpty);

          await press(t, 'channel-settings-delete-action');
          await t.tap(inDialog(delete));
          await t.pumpAndSettle(const Duration(milliseconds: 100));
          expect(_writes(api).map((c) => '${c.method} ${c.path}'), [
            'DELETE /channels/c1',
          ]);
          expect(find.byType(RaftOverflowSheet), findsNothing);
          expect(_id('channel-settings-confirm-dialog'), findsNothing);
        });
      }
    }

    for (final id in [elegantThemePackId, brutalThemePackId]) {
      testWidgets('legacy delete confirmation keeps existing copy $id', (
        t,
      ) async {
        final (_, api) = await _open(t, pack: packForThemeId(id));
        api.routes['DELETE /channels/c1'] = (_) => {};
        api.routes['GET /channels'] = (_) => [];
        Finder inDialog(String text) => find.descendant(
          of: _id('channel-settings-confirm-dialog'),
          matching: find.text(text),
        );
        await press(t, 'channel-settings-delete-action');
        expect(inDialog('Keep Channel'), findsOneWidget);
        await t.tap(inDialog('Keep Channel'));
        await t.pumpAndSettle();
        expect(_writes(api), isEmpty);
        await press(t, 'channel-settings-delete-action');
        await t.tap(inDialog('Delete Channel').last);
        await t.pumpAndSettle(const Duration(milliseconds: 100));
        expect(_writes(api).map((c) => '${c.method} ${c.path}'), [
          'DELETE /channels/c1',
        ]);
        expect(find.byType(RaftOverflowSheet), findsNothing);
      });
    }

    testWidgets('delete asks first and DELETEs the channel', (t) async {
      final (_, api) = await _open(t);
      api.routes['DELETE /channels/c1'] = (_) => {};
      api.routes['GET /channels'] = (_) => [];
      await press(t, 'channel-settings-delete-action');
      expect(find.textContaining('permanently deleted'), findsOneWidget);
      expect(_writes(api), isEmpty);
      await confirm(t, 'Delete');
      expect(_writes(api).single.method, 'DELETE');
      expect(find.byType(RaftOverflowSheet), findsNothing);
    });

    testWidgets(
      '#all: name locked with its hint, Hide #all uses the dedicated endpoint',
      (t) async {
        final (_, api) = await _open(t, row: _row(name: 'all'));
        expect(find.text('The #all channel cannot be renamed'), findsOneWidget);
        expect(
          t
              .widget<TextField>(
                find
                        .descendant(
                          of: _id('channel-settings-name'),
                          matching: find.byType(TextField),
                        )
                        .evaluate()
                        .isEmpty
                    ? _id('channel-settings-name')
                    : find.descendant(
                        of: _id('channel-settings-name'),
                        matching: find.byType(TextField),
                      ),
              )
              .enabled,
          isFalse,
        );
        for (final id in [
          'channel-settings-archive-action',
          'channel-overflow-leave',
          'channel-settings-delete-action',
        ]) {
          expect(_id(id), findsNothing, reason: id);
        }
        api.routes['POST /channels/system/all/hide'] = (_) =>
            _row(name: 'all', type: 'private');
        await press(t, 'channel-settings-visibility-action');
        await confirm(t, 'Hide #all');
        expect(_writes(api).single.path, '/channels/system/all/hide');
      },
    );
  });

  testWidgets('archived channel: fields disabled, Unarchive and no Save', (
    t,
  ) async {
    final (_, api) = await _open(
      t,
      row: _row(extra: {'archivedAt': '2026-01-01T00:00:00Z'}),
    );
    expect(
      find.text('Info'),
      findsNothing,
      reason: 'no manage group when archived',
    );
    expect(
      t
          .widget<RaftSettingsRecipeButton>(_id('channel-settings-save-inline'))
          .onPressed,
      isNull,
    );
    expect(_id('channel-settings-archive-action'), findsOneWidget);
    expect(find.text('Unarchive Channel'), findsOneWidget);
    for (final id in [
      'channel-settings-delete-action',
      'channel-overflow-leave',
      'channel-overflow-stop-agents',
    ]) {
      expect(_id(id), findsNothing, reason: id);
    }
    api.routes['POST /channels/c1/unarchive'] = (_) => _row();
    await t.ensureVisible(_id('channel-settings-archive-action'));
    await t.tap(_id('channel-settings-archive-action'));
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    // Unarchive has no confirmation and the drawer stays.
    expect(_writes(api).single.path, '/channels/c1/unarchive');
    expect(find.byType(RaftOverflowSheet), findsOneWidget);
  });

  testWidgets('Guest access switches send the Web payloads', (t) async {
    final (_, api) = await _open(t);
    expect(find.text('Guest access'), findsOneWidget);
    api.routes['PATCH /channels/c1'] = (_) => _row();
    await t.ensureVisible(_id('channel-settings-guest-joinable-switch'));
    await t.tap(_id('channel-settings-guest-joinable-switch'));
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(_writes(api).last.data, {
      'guestVisible': true,
      'guestJoinable': true,
    });
  });

  testWidgets(
    'the members strip opens the roster; the add tile opens its add view',
    (t) async {
      await _open(t);
      expect(_id('channel-overflow-members-add-tile'), findsOneWidget);
      await t.tap(_id('channel-overflow-members-entry'));
      await t.pumpAndSettle();
      expect(find.byType(RaftChannelMembersModal), findsOneWidget);
    },
  );

  // ChannelMembers presentation="page" mounted bare in the drawer. Its insets
  // differ by design (Web): header and search px-4, member rows and the bottom
  // Add button px-3 / p-3, the group header's chevron box at 8 + 2.
  testWidgets('members page keeps the Web column insets', (t) async {
    final (_, api) = await _open(t, size: const Size(1280, 800));
    api.routes['GET /servers/s1/members'] = (_) => [
      {'userId': 'u9', 'name': 'zed', 'displayName': 'Zed'},
    ];
    await t.tap(_id('channel-overflow-members-entry'));
    await t.pumpAndSettle();
    final left = t.getTopLeft(_id('channel-overflow-sheet')).dx;
    final right = t.getTopRight(_id('channel-overflow-sheet')).dx;
    double inset(Finder f) => t.getTopLeft(f).dx - left;
    double insetEnd(Finder f) => right - t.getTopRight(f).dx;
    expect(inset(_id('member-page-back')), 16, reason: 'header px-4');
    expect(
      inset(
        find.descendant(
          of: _id('member-page-search'),
          matching: find.byType(RaftDialogTextInput),
        ),
      ),
      16,
      reason: 'search px-4',
    );
    expect(
      insetEnd(
        find.descendant(
          of: _id('member-page-search'),
          matching: find.byType(RaftDialogTextInput),
        ),
      ),
      16,
    );
    expect(
      inset(find.byType(RaftMountedAvatarFrame).first),
      12,
      reason: 'ChannelMemberRow px-3',
    );
    expect(inset(_id('add-member-open')), 12, reason: 'footer p-3');
    expect(insetEnd(_id('add-member-open')), 12);
    // Role tag of the owner row ends at the row's 12px inset.
    expect(find.text('Channel Admin'), findsNothing);
    await t.tap(_id('add-member-open'));
    await t.pumpAndSettle();
    expect(inset(_id('add-member-back')), 16);
    expect(
      inset(find.byKey(const ValueKey('add-member-confirm'))),
      16,
      reason: 'add view px-4',
    );
    expect(insetEnd(find.byKey(const ValueKey('add-member-confirm'))), 16);
  });

  testWidgets('members page back returns to the drawer root with its draft', (
    t,
  ) async {
    await _open(t);
    await t.enterText(_id('channel-settings-name'), 'draft');
    await t.pump();
    await t.tap(_id('channel-overflow-members-entry'));
    await t.pumpAndSettle();
    expect(_id('member-page'), findsOneWidget);
    await t.tap(_id('member-page-back'));
    await t.pumpAndSettle();
    expect(_id('member-page'), findsNothing);
    expect(_controller(t, 'channel-settings-name').text, 'draft');
  });

  testWidgets('mobile: the drawer is the page with a back button', (t) async {
    await _open(t, size: const Size(390, 1800));
    expect(_id('channel-overflow-back'), findsOneWidget);
    expect(t.getSize(_id('channel-overflow-sheet')).width, 390);
    await t.tap(_id('channel-overflow-back'));
    await t.pumpAndSettle();
    expect(find.byType(RaftOverflowSheet), findsNothing);
  });

  testWidgets('drawer is 420 wide on desktop', (t) async {
    await _open(t);
    // The default Raft pack sets size.channelOverflowDrawer to 420 (Web
    // OverflowSheet: "420 wide, the whole width on a phone"); the 448 width
    // belongs to the Elegant pack.
    expect(t.getSize(_id('channel-overflow-sheet')).width, 420.0);
  });
}
