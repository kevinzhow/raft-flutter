import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/cause_notice.dart';
import '../../data/device_preferences.dart';
import '../../platform/file_selection.dart';
import 'artifact_comment_api.dart';
import 'artifact_comment_models.dart';
import 'artifact_comment_store.dart';
import 'artifact_models.dart';

String artifactCommentActorName(BuildContext context, ArtifactActor actor) =>
    actor.shownName(
      deletedAgent: raftText(context, 'Deleted agent'),
      deletedUser: raftText(context, 'Deleted user'),
      system: raftText(context, 'System'),
    );

String? _imageType(List<int> bytes) {
  bool starts(List<int> signature, [int offset = 0]) =>
      bytes.length >= offset + signature.length &&
      Iterable<int>.generate(signature.length)
          .every((index) => bytes[offset + index] == signature[index]);

  if (starts([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return 'image/png';
  }
  if (starts([0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (starts('GIF87a'.codeUnits) || starts('GIF89a'.codeUnits))
    return 'image/gif';
  if (starts('RIFF'.codeUnits) && starts('WEBP'.codeUnits, 8))
    return 'image/webp';
  return null;
}

class ArtifactCommentComposer extends StatefulWidget {
  const ArtifactCommentComposer({
    super.key,
    required this.store,
    required this.version,
    required this.place,
    this.reply,
    this.edit,
    this.onCancel,
    this.onDone,
    this.autofocus = false,
  });

  final ArtifactCommentStore store;
  final int version;
  final ArtifactCommentPlace place;
  final ArtifactComment? reply, edit;
  final VoidCallback? onCancel, onDone;
  final bool autofocus;

  @override
  State<ArtifactCommentComposer> createState() =>
      _ArtifactCommentComposerState();
}

class _ArtifactCommentComposerState extends State<ArtifactCommentComposer> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _mentions = <({int start, ArtifactActor actor})>[];
  final _images = <({String id, String name})>[];
  List<ArtifactActor> _matches = const [];
  List<({ArtifactActor actor, String reason})>? _recipients;
  String _before = '';
  String? _lookup;
  static const _visibleMentionResults = 4;
  int _option = 0;
  Timer? _debounce;
  bool _busy = false, _uploading = false;
  final _problem = CauseNotice();

  late final String _key =
      'artifact-comment-v1:${jsonEncode([widget.store.workspace.client.origin, widget.store.workspace.client.user?.id, widget.store.serverId, widget.store.api.artifactId, widget.version, widget.place.toJson(), widget.reply?.id, widget.edit?.id])}';

  @override
  void initState() {
    super.initState();
    final prefs = DevicePreferences.current;
    final kept = prefs?.getString(_key);
    if (kept != null) {
      try {
        final row = commentMap(jsonDecode(kept));
        _text.text = row['text'] as String? ?? '';
        for (final part in commentRows(row['mentions'])) {
          _mentions.add((
            start: part['start'] as int,
            actor: ArtifactActor.fromJson(part['actor']),
          ));
        }
        for (final part in commentRows(row['images'])) {
          _images.add((id: part['id'] as String, name: part['name'] as String));
        }
      } on FormatException {
        _text.clear();
      }
    } else if (widget.edit case final edit?) {
      var offset = 0;
      for (final part in edit.body) {
        if (part.actor case final actor?) {
          _mentions.add((start: offset, actor: actor));
        }
        offset += part.display.length;
      }
      _text.text = edit.body.map((part) => part.display).join();
    }
    _before = _text.text;
    _text.addListener(_changed);
    _focus.addListener(_changed);
    if (widget.edit == null) unawaited(_readRecipients());
  }

  Future<void> _readRecipients() async {
    try {
      final value = await widget.store.api.willNotify(
        path: widget.reply == null ? widget.place.path : null,
        replyTo: widget.reply?.id,
      );
      if (mounted && widget.store.current) setState(() => _recipients = value);
    } catch (_) {
      // The preview is advisory. The post always rechecks its audience.
    }
  }

  void _save() {
    if (!widget.store.current) return;
    final prefs = DevicePreferences.current;
    if (_text.text.isEmpty && _images.isEmpty) {
      unawaited(prefs?.remove(_key));
      return;
    }
    unawaited(
      prefs?.setString(
        _key,
        jsonEncode({
          'text': _text.text,
          'mentions': [
            for (final mention in _mentions)
              {
                'start': mention.start,
                'actor': {
                  'id': mention.actor.id,
                  'type': mention.actor.type,
                  'name': mention.actor.name,
                  'displayName': mention.actor.displayName,
                },
              },
          ],
          'images': [
            for (final image in _images) {'id': image.id, 'name': image.name},
          ],
        }),
      ),
    );
  }

  void _changed() {
    final next = _text.text;
    if (next != _before) {
      var prefix = 0;
      while (prefix < next.length &&
          prefix < _before.length &&
          next.codeUnitAt(prefix) == _before.codeUnitAt(prefix)) {
        prefix++;
      }
      var beforeEnd = _before.length, afterEnd = next.length;
      while (beforeEnd > prefix &&
          afterEnd > prefix &&
          next.codeUnitAt(afterEnd - 1) == _before.codeUnitAt(beforeEnd - 1)) {
        beforeEnd--;
        afterEnd--;
      }
      for (var i = _mentions.length - 1; i >= 0; i--) {
        final token = _mentions[i];
        final end = token.start + token.actor.name.length + 1;
        if (token.start >= beforeEnd) {
          _mentions[i] = (
            start: token.start + afterEnd - beforeEnd,
            actor: token.actor,
          );
        } else if (end > prefix) {
          _mentions.removeAt(i);
        }
      }
      _before = next;
      _save();
      _problem.clear();
    }
    final query = _focus.hasFocus ? _query : null;
    if (_lookup != query?.group(1)) {
      _lookup = query?.group(1);
      _matches = const [];
      _option = 0;
      _debounce?.cancel();
      if (_lookup case final term?) {
        _debounce = Timer(
          const Duration(milliseconds: 150),
          () => _search(term),
        );
      }
    }
    setState(() {});
  }

  RegExpMatch? get _query {
    final selection = _text.selection;
    if (!selection.isCollapsed || selection.baseOffset < 0) return null;
    final match = RegExp(r'(?<!\S)@([\w.\-]*)$')
        .firstMatch(_text.text.substring(0, selection.baseOffset));
    if (match == null || _mentions.any((token) => token.start == match.start)) {
      return null;
    }
    return match;
  }

  Future<void> _search(String term) async {
    if (!mounted || !widget.store.current) return;
    final ArtifactMentionAudience audience = widget.store.api;
    try {
      final matches = await audience.candidates(term);
      if (!mounted || !widget.store.current || _lookup != term) return;
      setState(() => _matches = matches.take(20).toList());
    } catch (_) {
      if (mounted && _lookup == term) setState(() => _matches = const []);
    }
  }

  void _choose(ArtifactActor actor) {
    final query = _query;
    if (query == null) return;
    final insert = '@${actor.name} ';
    final next = _text.text.replaceRange(query.start, query.end, insert);
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: query.start + insert.length),
    );
    _mentions.add((start: query.start, actor: actor));
    _mentions.sort((a, b) => a.start.compareTo(b.start));
    _save();
    _focus.requestFocus();
  }

  List<ArtifactCommentPart> get _body {
    final text = _text.text;
    final parts = <ArtifactCommentPart>[];
    var offset = 0;
    for (final token in _mentions) {
      final label = '@${token.actor.name}';
      if (token.start < offset || !text.startsWith(label, token.start))
        continue;
      if (token.start > offset) {
        parts.add(
          ArtifactCommentPart.text(text.substring(offset, token.start)),
        );
      }
      parts.add(ArtifactCommentPart.mention(token.actor));
      offset = token.start + label.length;
    }
    if (offset < text.length)
      parts.add(ArtifactCommentPart.text(text.substring(offset)));
    return parts;
  }

  bool get _canSend =>
      !_busy &&
      !_uploading &&
      (_text.text.trim().isNotEmpty ||
          _images.isNotEmpty ||
          widget.edit?.images.isNotEmpty == true);

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() {
      _busy = true;
      _problem.clear();
    });
    try {
      if (widget.edit case final edit?) {
        await widget.store.edit(edit.id, _body);
      } else {
        await widget.store.send(
          ArtifactCommentInput(
            version: widget.version,
            place: widget.place,
            replyTo: widget.reply?.id,
            body: _body,
            images: _images.map((image) => image.id).toList(),
          ),
        );
      }
      if (!mounted || !widget.store.current) return;
      _images.clear();
      _text.clear();
      _save();
      widget.onDone?.call();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _problem.raise(switch (error) {
          RaftApiException(code: 'MENTION_NOT_VISIBLE') =>
            "Someone mentioned can't see this Artifact.",
          RaftApiException(code: 'FIELD_TOO_LONG') =>
            'This comment is too long.',
          RaftApiException(code: 'IMAGE_NOT_FOUND') => 'This image expired before it was sent. Remove it and attach it again.',
          _ => "Couldn't send the comment. Try again.",
        }),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach() async {
    if (_uploading || _images.length >= 4) return;
    setState(() {
      _uploading = true;
      _problem.clear();
    });
    try {
      final files = await selectImages(
        typeGroup: const XTypeGroup(
          label: 'Images',
          extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
          mimeTypes: ['image/png', 'image/jpeg', 'image/webp', 'image/gif'],
          uniformTypeIdentifiers: [
            'public.png',
            'public.jpeg',
            'org.webmproject.webp',
            'com.compuserve.gif',
          ],
        ),
      );
      final room = 4 - _images.length;
      if (files.length > room && mounted) {
        setState(() => _problem.raise('A comment can have up to 4 images.'));
      }
      for (final file in files.take(room)) {
        if (!mounted || !widget.store.current) return;
        if (await file.length() > 10 * 1024 * 1024) {
          if (!mounted) return;
          setState(() => _problem.raise('An image can be up to 10 MB.'));
          continue;
        }
        final bytes = await file.readAsBytes();
        final type = _imageType(bytes);
        if (![
          'image/png',
          'image/jpeg',
          'image/webp',
          'image/gif',
        ].contains(type)) {
          if (mounted)
            setState(
              () => _problem.raise(
                'Only PNG, JPEG, WebP and GIF images can be attached.',
              ),
            );
          continue;
        }
        if (!mounted || !widget.store.current) return;
        final id = await widget.store.api.upload(bytes, type!);
        if (!mounted || !widget.store.current) return;
        setState(() => _images.add((id: id, name: file.name)));
        _save();
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _problem.raise("It didn't upload. Retry, or remove it."),
        );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && _lookup != null) {
      _debounce?.cancel();
      setState(() {
        _lookup = null;
        _matches = const [];
      });
      return KeyEventResult.handled;
    }
    if (_matches.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowUp) {
        final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
        setState(() => _option = (_option + step) % _matches.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.tab) {
        _choose(_matches[_option]);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.escape && widget.onCancel != null) {
      widget.onCancel!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      unawaited(_send());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_changed);
    _focus.dispose();
    _text.removeListener(_changed);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final placeholder = raftText(
      context,
      widget.reply == null ? 'Comment' : 'Reply',
    );
    final recipients = {
      for (final entry
          in _recipients ?? const <({ArtifactActor actor, String reason})>[])
        (entry.actor.type, entry.actor.id): entry.actor,
      for (final token in _mentions)
        (token.actor.type, token.actor.id): token.actor,
    };
    return Focus(
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.reply case final reply?)
            Text(
              raftFormat(context, 'Replying to {name}', {
                'name': artifactCommentActorName(context, reply.author),
              }),
            ),
          if (_matches.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: RaftMetrics.buttonMd * _visibleMentionResults,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _matches.length,
                itemBuilder: (context, index) {
                  final actor = _matches[index];
                  return RaftButton(
                    key: ValueKey('artifact-mention-${actor.id}'),
                    tone: _option == index
                        ? RaftButtonRecipeVariant.muted
                        : RaftButtonRecipeVariant.ghost,
                    label:
                        '${artifactCommentActorName(context, actor)} @${actor.name}',
                    glyph: actor.type == 'agent' ? RaftGlyph.bot : null,
                    onPressed: () => _choose(actor),
                  );
                },
              ),
            ),
          RaftTextarea(
            fieldKey: const ValueKey('artifact-comment-input'),
            controller: _text,
            focusNode: _focus,
            autofocus: widget.autofocus,
            enabled: !_busy,
            hintText: placeholder,
            semanticLabel: placeholder,
            rows: 2,
            growsWithScale: true,
          ),
          for (final image in _images)
            Row(
              children: [
                Expanded(child: Text(image.name)),
                RaftButton(
                  glyph: RaftGlyph.x,
                  semanticLabel: raftText(context, 'Remove image'),
                  tone: RaftButtonRecipeVariant.ghost,
                  size: RaftButtonRecipeSize.iconSm,
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            _images.remove(image);
                            _problem.clear();
                          });
                          _save();
                        },
                ),
              ],
            ),
          if (_problem.message case final message?)
            Semantics(
              liveRegion: true,
              child: Text(
                raftText(context, message),
                style: t.scale(
                  RaftTypeScale.footnote,
                  color: t.semantic.dangerStrong,
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: RaftSpace.x1,
            children: [
              if (widget.onCancel != null)
                RaftButton(
                  label: raftText(context, 'Cancel'),
                  tone: RaftButtonRecipeVariant.ghost,
                  onPressed: _busy ? null : widget.onCancel,
                ),
              if (widget.edit == null)
                RaftButton(
                  key: const ValueKey('artifact-comment-attach'),
                  glyph: RaftGlyph.paperclip,
                  semanticLabel: raftText(context, 'Add image'),
                  tooltip: raftText(context, 'Add image'),
                  tone: RaftButtonRecipeVariant.ghost,
                  size: RaftButtonRecipeSize.iconSm,
                  onPressed: _busy || _uploading || _images.length == 4
                      ? null
                      : _attach,
                ),
              RaftButton(
                key: const ValueKey('artifact-comment-send'),
                glyph: widget.edit == null ? RaftGlyph.send : RaftGlyph.check,
                semanticLabel: raftText(
                  context,
                  widget.edit == null ? 'Send' : 'Save',
                ),
                size: RaftButtonRecipeSize.iconSm,
                onPressed: _canSend ? _send : null,
              ),
            ],
          ),
          if (_recipients != null || recipients.isNotEmpty)
            Text(
              recipients.isEmpty
                  ? raftText(context, "Won't notify anyone.")
                  : raftFormat(context, 'Will notify: {names}', {
                      'names': recipients.values
                          .map(
                            (actor) => artifactCommentActorName(context, actor),
                          )
                          .join(', '),
                    }),
              style: t.scale(RaftTypeScale.footnote, color: t.muted),
            ),
        ],
      ),
    );
  }
}
