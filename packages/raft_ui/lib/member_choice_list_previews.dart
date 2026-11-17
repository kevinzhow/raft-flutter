import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Channel member choices', size: Size(390, 500))
Widget memberChoiceListPreview() => const _MemberChoicePreview();

@RaftPreviews('Channel member choices empty', size: Size(390, 320))
Widget memberChoiceListEmptyPreview() =>
    const _MemberChoicePreview(empty: true);

@RaftPreviews('Channel member choices disabled', size: Size(390, 500))
Widget memberChoiceListDisabledPreview() =>
    const _MemberChoicePreview(disabled: true);

class _MemberChoicePreview extends StatefulWidget {
  const _MemberChoicePreview({this.empty = false, this.disabled = false});
  final bool empty, disabled;
  @override
  State<_MemberChoicePreview> createState() => _MemberChoicePreviewState();
}

class _MemberChoicePreviewState extends State<_MemberChoicePreview> {
  final search = TextEditingController();
  final selected = {'agent:helper'};
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: RaftMemberPickerContent(
      search: search,
      agents: widget.empty
          ? const []
          : const [
              RaftPickerItem(
                key: 'agent:helper',
                label: 'Release helper',
                avatar: RaftAvatar(name: 'Release helper'),
              ),
            ],
      humans: widget.empty
          ? const []
          : const [
              RaftPickerItem(
                key: 'human:alice',
                label: 'Alice',
                avatar: RaftAvatar(name: 'Alice'),
              ),
            ],
      hasCandidates: !widget.empty,
      isSelected: selected.contains,
      onToggle: widget.disabled
          ? null
          : (key) => setState(() {
              if (!selected.remove(key)) selected.add(key);
            }),
    ),
  );
}
