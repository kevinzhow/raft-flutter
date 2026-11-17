import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart' show pageIdentity;
import 'sidebar_reorder.dart' show sidebarSectionOrder;

class ChannelSectionSelect extends StatelessWidget {
  const ChannelSectionSelect({
    super.key,
    required this.controller,
    required this.channel,
  });

  final WorkspaceController controller;
  final RaftChannel channel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final order = controller.sidebarOrder;
      final dm = channel.type == 'dm';
      final peer = channel.string('peerId');
      final agent = channel.string('peerType') == 'agent';
      final pin = dm
          ? (peer.isEmpty ? null : (agent ? 'agent' : 'human', peer))
          : ('channel', channel.id);
      final rawPins = _rows(order['pinned']);
      final placements = _rows(order['sectionPlacements']);
      final sections = _rows(order['customSections']);
      bool matches(Map<String, dynamic> row, (String, String)? ref) =>
          ref != null && row['kind'] == ref.$1 && row['id'] == ref.$2;
      final item =
          dm &&
              agent &&
              pin != null &&
              [...rawPins, ...placements].any((row) => matches(row, pin))
          ? pin
          : ('channel', channel.id);
      final placement = placements
          .where((row) => matches(row, item))
          .firstOrNull;
      final sectionId = placement?['sectionId'];
      final homeKey = dm
          ? 'system:dms'
          : channel.type == 'joint'
          ? 'system:joint'
          : 'system:channels';
      final home = dm
          ? 'Direct Messages'
          : channel.type == 'joint'
          ? 'External'
          : 'Channels';
      final selected = rawPins.any((row) => matches(row, pin))
          ? 'system:pinned'
          : sections.any((s) => s['id'] == sectionId)
          ? sectionId as String
          : homeKey;
      final identity = pageIdentity(controller);

      Future<void> choose(String next, {Map<String, dynamic>? section}) async {
        if (identity != pageIdentity(controller)) {
          if (context.mounted) {
            showRaftToast(context, 'The channel is no longer available.');
          }
          return;
        }
        final pins = [
          for (final row in rawPins)
            if (!matches(row, pin) &&
                !(dm && matches(row, ('channel', channel.id))))
              row,
          if (next == 'system:pinned' && pin != null)
            {'kind': pin.$1, 'id': pin.$2},
        ];
        final nextPlacements = [
          for (final row in placements)
            if (!matches(row, item)) row,
          if (next != homeKey && next != 'system:pinned')
            {
              'kind': item.$1,
              'id': item.$2,
              'sectionId': next,
              'position': placements
                  .where(
                    (row) => row['sectionId'] == next && !matches(row, item),
                  )
                  .length,
            },
        ];
        final sectionsOrder = sidebarSectionOrder(order);
        final patch = <String, dynamic>{
          if (next != selected || pins.length != rawPins.length) 'pinned': pins,
          if (next != selected || next == homeKey && placement != null)
            'sectionPlacements': nextPlacements,
          if (section != null) ...{
            'customSections': [...sections, section],
            'sectionOrder': sectionsOrder
              ..insert(sectionsOrder.indexOf(selected), next),
          },
        };
        if (patch.isNotEmpty) await controller.updateSidebarOrder(patch);
      }

      return RaftSelectField<String>(
        key: const Key('channel-settings-section-select'),
        label: raftText(context, 'Move to section'),
        value: selected,
        items: [
          RaftSelectItem(value: homeKey, label: raftText(context, home)),
          if (pin != null)
            RaftSelectItem(
              value: 'system:pinned',
              label: raftText(context, 'Pinned'),
            ),
          for (final section in sections)
            if (section['id'] is String && section['name'] is String)
              RaftSelectItem(
                value: section['id'] as String,
                label: [
                  if (section['emoji'] case final String emoji
                      when emoji.isNotEmpty)
                    emoji,
                  section['name'] as String,
                ].join(' '),
              ),
          RaftSelectItem(
            value: 'create',
            label: raftText(context, 'Create section'),
          ),
        ],
        onChanged: (next) {
          if (next == null) return;
          if (next != 'create') {
            unawaited(choose(next));
            return;
          }
          unawaited(
            showRaftSidebarSectionDialog(
              context,
              title: 'New Section',
              submitLabel: 'Create section',
              onSubmit: (name, emoji) {
                final id =
                    'section-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
                unawaited(
                  choose(
                    id,
                    section: {
                      'id': id,
                      'name': name,
                      'emoji': emoji,
                      'sortMode': 'manual',
                    },
                  ),
                );
              },
            ),
          );
        },
      );
    },
  );
}

List<Map<String, dynamic>> _rows(Object? value) => [
  if (value is List)
    for (final row in value.whereType<Map>()) Map<String, dynamic>.from(row),
];
