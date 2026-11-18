import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

RaftComposerSendKey accountComposerSendKey(RaftClient? client) =>
    RaftUserFields(client?.user?.json ?? const {}).composerSendKey ==
        'mod_enter'
    ? RaftComposerSendKey.modifiedEnter
    : RaftComposerSendKey.enter;

class ComposerSendKeySetting extends StatefulWidget {
  const ComposerSendKeySetting({super.key, required this.client});

  final RaftClient client;

  @override
  State<ComposerSendKeySetting> createState() => _ComposerSendKeySettingState();
}

class _ComposerSendKeySettingState extends State<ComposerSendKeySetting> {
  RaftComposerSendKey? saving;
  bool failed = false;

  Future<void> change(RaftComposerSendKey next) async {
    final client = widget.client;
    final user = client.user;
    if (user == null ||
        saving != null ||
        next == accountComposerSendKey(client)) {
      return;
    }
    final generation = client.generation;
    final fields = {
      'composerSendKey': next == RaftComposerSendKey.enter
          ? 'enter'
          : 'mod_enter',
    };
    setState(() {
      saving = next;
      failed = false;
    });
    try {
      final response = await client.patch('/auth/me', data: fields);
      final current = client.user;
      if (client.generation != generation || current?.id != user.id) return;
      await client.replaceUser({
        ...current!.json,
        ...fields,
        if (response is Map<String, dynamic>) ...response,
      });
    } catch (_) {
      if (mounted && identical(client, widget.client)) {
        setState(() => failed = true);
      }
    } finally {
      if (mounted) setState(() => saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apple = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: RaftSpace.x6),
        const RaftSettingsSectionHeader(
          label: 'Keyboard',
          glyph: RaftGlyph.keyboard,
        ),
        RaftListRowGroup(
          children: [
            RaftListRow(
              variant: RaftListRowVariant.plain,
              interactive: false,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, box) {
                      final title = RaftListRowBody(
                        children: [
                          const RaftListRowTitle('Send messages with'),
                          if (failed)
                            const RaftSaveStatus(
                              'Couldn’t change how messages send. Try again.',
                            ),
                        ],
                      );
                      final control = RaftSegmentedControl<RaftComposerSendKey>(
                        label: 'Send messages with',
                        value: saving ?? accountComposerSendKey(widget.client),
                        onChanged: saving == null ? change : null,
                        items: [
                          const RaftSegmentedOption(
                            value: RaftComposerSendKey.enter,
                            label: 'Enter',
                          ),
                          RaftSegmentedOption(
                            value: RaftComposerSendKey.modifiedEnter,
                            label: apple ? '⌘Enter' : 'Ctrl+Enter',
                          ),
                        ],
                      );
                      return box.maxWidth < 512
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: RaftSpace.x2,
                              children: [title, control],
                            )
                          : Row(
                              spacing: RaftSpace.x3,
                              children: [
                                Expanded(child: title),
                                control,
                              ],
                            );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
