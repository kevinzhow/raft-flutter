import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'support/close_support.dart';
import 'support/no_wait_support.dart';

/// Channel settings (Members / Agents), the members dialog and page, and the
/// create-channel picker open from the loaded workspace directory and the
/// channel roster, with a network that never answers.
void main() {
  Future<void> prepare(WidgetTester t, Size size) async {
    final (w, api) = await mountWorkspace(t, size);
    api.routes['GET /channels/c1/members'] = (_) => {
      'humans': [
        {'userId': 'bob', 'name': 'bob', 'displayName': 'Bob'},
      ],
      'agents': [
        {'id': 'a1', 'name': 'cindy', 'displayName': 'Cindy'},
      ],
    };
    _w = w;
    _api = api;
  }

  testWidgets('members dialog: a revisit shows the roster at once', (t) async {
    await prepare(t, const Size(1280, 800));
    final w = _w, api = _api;
    // First visit reads the roster once.
    final first = ChannelMembers.show(
      t.element(find.byType(WorkspaceView)),
      controller: w,
      channel: w.channel!,
    );
    await frames(t, 8);
    expect(find.text('Cindy'), findsOneWidget);
    await pressEscape(t);
    unawaited(first);
    expect(find.byType(ChannelMembers), findsNothing);

    final held = await expectOpensWithoutNetwork(
      t,
      w,
      api,
      open: (context) =>
          ChannelMembers.show(context, controller: w, channel: w.channel!),
      surface: find.byType(ChannelMembers),
    );
    // The roster rows are in the first frames, not a skeleton.
    expect(find.text('Cindy'), findsOneWidget);
    expect(find.text('Bob'), findsWidgets);
    expect(held, lessThanOrEqualTo(2), reason: 'only the quiet roster refresh');
  });

  testWidgets(
    'members dialog: the very first open is not gated on the network',
    (t) async {
      await prepare(t, const Size(1280, 800));
      await expectOpensWithoutNetwork(
        t,
        _w,
        _api,
        open: (context) =>
            ChannelMembers.show(context, controller: _w, channel: _w.channel!),
        surface: find.byType(ChannelMembers),
      );
    },
  );

  testWidgets('add view lists directory agents and people with no request', (
    t,
  ) async {
    await prepare(t, const Size(1280, 800));
    final w = _w, api = _api;
    // Roster already known, so only the candidates matter.
    final warm = ChannelMembers.show(
      t.element(find.byType(WorkspaceView)),
      controller: w,
      channel: w.channel!,
    );
    await frames(t, 8);
    await pressEscape(t);
    unawaited(warm);
    await expectOpensWithoutNetwork(
      t,
      w,
      api,
      open: (context) => ChannelMembers.show(
        context,
        controller: w,
        channel: w.channel!,
        startInAdd: true,
      ),
      surface: find.byType(ChannelMembers),
    );
    // Dana is in the server directory and not in the channel.
    expect(find.text('Dana'), findsWidgets);
  });

  testWidgets('create channel: the member picker is filled at first frame', (
    t,
  ) async {
    await prepare(t, const Size(1280, 800));
    await expectOpensWithoutNetwork(
      t,
      _w,
      _api,
      open: (context) => CreateChannelDialog.show(context, controller: _w),
      surface: find.byType(CreateChannelDialog),
    );
    expect(find.text('Cindy'), findsWidgets);
    expect(find.text('Dana'), findsWidgets);
  });

  testWidgets('channel settings drawer -> members page opens without waiting', (
    t,
  ) async {
    await prepare(t, const Size(1280, 800));
    await expectOpensWithoutNetwork(
      t,
      _w,
      _api,
      open: (context) =>
          ChannelSettings.show(context, controller: _w, channel: _w.channel!),
      surface: find.byType(ChannelSettings),
    );
    // The drawer's members strip (heading "Members") is part of the surface;
    // the page behind it opens from the same local data.
    final strip = find.text('Members');
    expect(strip, findsWidgets);
  });
}

late WorkspaceController _w;
late MessageAdapter _api;
