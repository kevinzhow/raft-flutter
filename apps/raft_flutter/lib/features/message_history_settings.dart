import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/history_capacity.dart';
import '../data/cause_notice.dart';
import '../data/message_history_pages.dart';
import '../data/workspace_controller.dart';
import 'computer_detail_view.dart' show computerFileSize;

/// Account-wide history capacity, separate from attachment storage.
class MessageHistorySettings extends StatefulWidget {
  const MessageHistorySettings({
    super.key,
    required this.capacity,
    required this.account,
  });
  final HistoryCapacity capacity;
  final HistoryAccount account;

  static Widget forWorkspace(WorkspaceController w) {
    final db = MessageHistoryPages.storage(w.deviceStore.cache),
        user = w.client.user?.id;
    if (db == null || user == null) return const SizedBox.shrink();
    final account = HistoryAccount(w.client.origin, user);
    return MessageHistorySettings(
      key: ValueKey(account),
      capacity: db.capacity,
      account: account,
    );
  }

  @override
  State<MessageHistorySettings> createState() => _MessageHistorySettingsState();
}

class _MessageHistorySettingsState extends State<MessageHistorySettings> {
  HistoryDiskUsage? usage;
  bool busy = false, measuring = true;
  final _action = CauseNotice();
  String? get error => _action.message;
  int _read = 0, _operation = 0;
  Object get _identity => (widget.capacity, widget.account);

  void raise(CauseNotice target, String message, {int? read}) {
    final identity = _identity, operation = _operation;
    target.raise(
      message,
      whileTrue: () =>
          mounted &&
          identity == _identity &&
          operation == _operation &&
          (read == null || read == _read),
    );
  }

  @override
  void initState() {
    super.initState();
    measure();
  }

  @override
  void didUpdateWidget(MessageHistorySettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.capacity != widget.capacity ||
        oldWidget.account != widget.account) {
      usage = null;
      measuring = true;
      _operation++;
      busy = false;
      measure();
    }
  }

  Future<void> measure() async {
    final read = ++_read;
    try {
      final value = await widget.capacity.usage(widget.account);
      if (!mounted || read != _read) return;
      setState(() {
        usage = value;
        measuring = false;
      });
    } catch (_) {
      // Metering is advisory. Reopening or a capacity change reads it again;
      // neither message correctness nor a capacity choice depends on it.
      if (mounted && read == _read) setState(() => measuring = false);
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    final operation = ++_operation, identity = _identity;
    _read++;
    bool current() =>
        mounted && operation == _operation && identity == _identity;
    setState(() {
      busy = true;
    });
    try {
      await action();
      if (current()) await measure();
    } catch (cause) {
      if (current()) {
        setState(
          () => raise(
            _action,
            raftDefaultErrorText(
              cause,
              fallback: 'Message storage could not be updated. Existing messages and drafts are kept. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (current()) setState(() => busy = false);
    }
  }

  Future<void> chooseBudget(int tier) => run(() async {
    final identity = _identity, operation = _operation;
    final capacity = widget.capacity, account = widget.account;
    bool current() =>
        mounted && identity == _identity && operation == _operation;
    Future<void> apply() async {
      if (!current()) {
        throw const RaftUserError(
          'The account changed. Close this dialog and try again.',
        );
      }
      await capacity.setBudget(account, tier);
    }

    final previous = usage?.budget ?? 0;
    if (tier != 0 && (previous == 0 || tier < previous)) {
      await RaftConfirmDialog.show(
        context,
        RaftConfirmDialog(
          surfaceKey: const ValueKey('history-lower-dialog'),
          confirmKey: const Key('history-lower-confirm'),
          title: raftText(context, 'Lower message history limit'),
          message: raftText(
            context,
            'Older unused messages may be removed and need a connection to open again. Conversations opened in the last seven days, pinned conversations, drafts, uploads, unread messages, mentions and open windows are protected.',
          ),
          confirmLabel: raftText(context, 'Lower Limit'),
          cancelLabel: raftText(context, 'Keep Limit'),
          loadingLabel: raftText(context, 'Updating…'),
          onConfirm: apply,
        ),
      );
    } else {
      await apply();
    }
  });

  @override
  Widget build(BuildContext context) {
    final text = RaftSettingsText(RaftTokens.of(context));
    final value = usage;
    final disabled = busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RaftSettingsSectionHeader(
          label: 'Messages on this device',
          glyph: RaftGlyph.messageSquareText,
        ),
        RaftSettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftSettingsPreference(
                title: 'Message history',
                description: 'Messages are managed automatically across this account. Recently opened and important conversations stay available offline. Attachments and previews use the separate cache below.',
                error: error,
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  child: Text(
                    value == null
                        ? raftText(
                            context,
                            measuring
                                ? 'Calculating…'
                                : 'Storage estimate unavailable',
                          )
                        : raftFormat(
                            context,
                            'Estimated message storage: {size}',
                            {'size': computerFileSize(value.budgetCharge)},
                          ),
                    key: const Key('history-size'),
                    style: text.description,
                  ),
                ),
              ),
              if (value != null) ...[
                const SizedBox(height: RaftSpace.x2),
                Text(
                  raftFormat(
                    context,
                    'Shared database and pending writes: {size}',
                    {
                      'size': computerFileSize(
                        value.databaseBytes + value.walBytes,
                      ),
                    },
                  ),
                  key: const Key('history-device-size'),
                  style: text.description,
                ),
                Text(
                  raftText(
                    context,
                    'The account estimate includes message indexes and space reserved for writes. The shared database also holds drafts, settings and other accounts.',
                  ),
                  style: text.description,
                ),
                if (value.hardFull || value.protectedFull)
                  Padding(
                    padding: const EdgeInsets.only(top: RaftSpace.x2),
                    child: Text(
                      raftText(
                        context,
                        value.hardFull
                            ? 'Storage limit reached. New messages are not being saved offline; existing messages and drafts are kept.'
                            : 'Protected conversations exceed the selected limit. They stay available offline; only older unused messages are removed.',
                      ),
                      key: const Key('history-protected-full'),
                      style: text.alert,
                    ),
                  ),
              ],
              const SizedBox(height: RaftSpace.x4),
              RaftSettingsPreference(
                title: 'Message history limit',
                description: 'Older unused messages are removed first. Conversations opened in the last seven days, pinned conversations, drafts, uploads, unread messages, mentions and open windows are protected, even when they exceed this limit.',
                child: RaftSelectField<int>(
                  key: const Key('history-budget'),
                  label: 'Message history limit',
                  value: value?.budget ?? historyBudgetTiers.first,
                  items: [
                    for (final tier in historyBudgetTiers)
                      RaftSelectItem(
                        value: tier,
                        label: tier == 0
                            ? raftText(context, 'Keep all')
                            : tier < (1 << 30)
                            ? '512 MiB'
                            : '${tier >> 30} GiB',
                        labelKey: Key('history-budget-$tier'),
                      ),
                  ],
                  onChanged: disabled
                      ? null
                      : (tier) {
                          if (tier != null) {
                            chooseBudget(tier);
                          }
                        },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RaftSpace.x6),
      ],
    );
  }
}
