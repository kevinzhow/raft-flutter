import 'package:flutter/material.dart';

import 'icons.dart';
import 'localization.dart';
import 'raft/avatar.dart';
import 'raft/status.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'tokens/tokens.dart';
import 'tooltip.dart';

class RaftReadFace {
  const RaftReadFace({
    required this.id,
    required this.name,
    required this.avatar,
    this.working = false,
    this.activity,
  });

  final String id, name;
  final Widget avatar;
  final bool working;
  final String? activity;
}

String readAgentNames(
  BuildContext context,
  List<String> names, {
  bool open = false,
}) {
  if (names.length < 2) return names.join();
  if (Localizations.localeOf(context).languageCode == 'zh') {
    if (open) return names.join('、');
    return '${names.take(names.length - 1).join('、')}和${names.last}';
  }
  if (open) return names.join(', ');
  if (names.length == 2) return '${names.first} and ${names.last}';
  return '${names.take(names.length - 1).join(', ')}, and ${names.last}';
}

String readAgentName(BuildContext context, String name) =>
    name.isEmpty ? raftText(context, 'Agent') : name;

class RaftMessageReadFaces extends StatelessWidget {
  const RaftMessageReadFaces({super.key, required this.faces});

  final List<RaftReadFace> faces;
  static const _size = RaftAvatarSize.xxs;
  static final _mark = RaftScale.space(3);
  static final _gap = RaftScale.space(1);

  @override
  Widget build(BuildContext context) {
    const slotKey = ValueKey('agent-read-column');
    if (faces.isEmpty) {
      return SizedBox(key: slotKey, width: _mark + _gap + _size.extent);
    }
    final tokens = RaftTokens.of(context);
    final cap = MediaQuery.sizeOf(context).width < 768 ? 2 : 3;
    final visible = faces.take(cap);
    final rest = faces.skip(cap).toList();
    final names = [for (final face in faces) readAgentName(context, face.name)];
    final label = raftFormat(context, '{names} read up to here', {
      'names': readAgentNames(context, names),
    });
    final children = [
      for (final face in visible) _avatar(context, face),
      if (rest.isNotEmpty)
        RaftTooltip(
          message: raftFormat(context, '{names} also read up to here', {
            'names': readAgentNames(context, names.skip(cap).toList()),
          }),
          child: RaftStickerAvatar(
            type: RaftAvatarType.human,
            size: _size,
            child: RaftAvatarInitials(
              raftFormat(context, '+{count}', {'count': rest.length}),
              size: _size,
            ),
          ),
        ),
    ];
    final step = _size.extent - _gap;
    return Semantics(
      key: slotKey,
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftIcon(
              RaftGlyph.checkCheck,
              size: _mark,
              color: tokens.ui.foregroundHint,
            ),
            SizedBox(width: _gap),
            SizedBox(
              width: _size.extent + step * (children.length - 1),
              height: _size.extent,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var index = 0; index < children.length; index++)
                    PositionedDirectional(
                      start: step * index,
                      child: children[index],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context, RaftReadFace face) {
    final name = readAgentName(context, face.name);
    final activity = face.activity;
    return RaftTooltip(
      key: ValueKey('agent-read-face-${face.id}'),
      message: face.working
          ? raftFormat(context, '{name} read up to here · {activity}', {
              'name': name,
              'activity': activity == null || activity.isEmpty
                  ? raftText(context, 'Working')
                  : activity,
            })
          : raftFormat(context, '{name} read up to here', {'name': name}),
      child: RaftStickerAvatar(
        size: _size,
        presence: face.working ? RaftPresence.busy : null,
        child: face.avatar,
      ),
    );
  }
}

class RaftMessageSystemTrailing extends StatelessWidget {
  const RaftMessageSystemTrailing({
    super.key,
    required this.trailing,
    required this.child,
  });

  final Widget trailing, child;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: child),
      trailing,
    ],
  );
}
