import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/personal_presentation.dart';
import 'message_presentation.dart';
import 'message_preparation.dart';
import 'message_type_scale.dart';

/// Owns optional text preparation for a mounted timeline, independently of its
/// message authority. Cache warming never gates publication or creates rows.
class ChatBodyPreparation {
  final _worker = RaftMessageBodyWorker();
  late final _idle = MessagePreparation(
    isIdle: () => _options?.idle() ?? false,
  );
  _BodyOptions? _options;
  Object? _inputs;

  void schedule(
    BuildContext context, {
    required WorkspaceController workspace,
    required List<RaftMessage> rows,
    required bool thread,
    required Object scope,
    required int revision,
    required Object taskRevision,
    required List<RaftTextReference> references,
    required Map<String, dynamic>? Function(int) taskByNumber,
    required ValueChanged<String> onLink,
    required bool Function() current,
    required bool Function() idle,
  }) {
    if (kDebugMode) return;
    final tokens = RaftTokens.of(context);
    final size = messagePreferenceDisplaySize(
      context,
      PersonalPresentationScope.bodyFontSize(
        context,
        workspace.client.user?.string('preferredMessageBodyFontSize'),
      ),
    );
    final key = (scope, revision, taskRevision, references, tokens, size);
    if (key == _inputs) return;
    _inputs = key;
    final options = _options = _BodyOptions(
      scope,
      workspace,
      tokens,
      size,
      references,
      taskByNumber,
      onLink,
      current,
      idle,
    );
    final nearest = thread ? rows : rows.reversed;
    _idle.replace(
      nearest
          .take(64)
          .map(
            (m) => () {
              if (_inputs != key || !options.current()) return;
              if (options.workspace.services.translations.present(m).skeleton) {
                return;
              }
              options.presentation(m).prepareCache(tokens);
            },
          ),
    );
  }

  void incoming(Iterable<RaftMessage> rows, Object scope) {
    final options = _options;
    if (options == null || options.scope != scope || !options.current()) return;
    _worker.prepare(
      rows.map(
        (m) =>
            () => options.request(m),
      ),
      current: options.current,
    );
  }

  void cancel() {
    _inputs = null;
    _options = null;
    _idle.cancel();
    _worker.cancel();
  }

  void dispose() {
    _idle.dispose();
    _worker.dispose();
    _options = null;
  }
}

class _BodyOptions {
  const _BodyOptions(
    this.scope,
    this.workspace,
    this.tokens,
    this.fontSize,
    this.references,
    this.taskByNumber,
    this.onLink,
    this.current,
    this.idle,
  );
  final Object scope;
  final WorkspaceController workspace;
  final RaftTokens tokens;
  final double fontSize;
  final List<RaftTextReference> references;
  final Map<String, dynamic>? Function(int) taskByNumber;
  final ValueChanged<String> onLink;
  final bool Function() current, idle;
  RaftMessageBodyRequest? request(RaftMessage m) {
    final translation = workspace.services.translations.present(m);
    final content = translation.translatedContent ?? m.content;
    if (translation.skeleton || content.length > 64 * 1024) return null;
    return presentation(m).bodyRequest(tokens);
  }

  MessagePresentation presentation(RaftMessage m) => MessagePresentation(
    controller: workspace,
    message: m,
    onExternalLink: onLink,
    content: workspace.services.translations.present(m).translatedContent,
    taskByNumber: taskByNumber,
    directoryReferences: references,
    fontSize: fontSize,
  );
}
