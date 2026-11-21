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
import 'artifact_review_store.dart';

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
  if (starts('GIF87a'.codeUnits) || starts('GIF89a'.codeUnits)) {
    return 'image/gif';
  }
  if (starts('RIFF'.codeUnits) && starts('WEBP'.codeUnits, 8)) {
    return 'image/webp';
  }
  return null;
}

class ArtifactCommentInsert {
  ArtifactCommentInsert(this.text);

  final String text;
  bool _applied = false;
}

typedef ArtifactReviewComposerState = ({bool engaged, bool editingDraft});

class ArtifactCommentComposer extends StatefulWidget {
  const ArtifactCommentComposer({
    super.key,
    required this.store,
    required this.version,
    required this.place,
    this.reply,
    this.edit,
    this.review,
    this.draft,
    this.onCancel,
    this.onDone,
    this.autofocus = false,
    this.standing = false,
    this.insert,
    this.onReviewComposerChanged,
  });

  final ArtifactCommentStore store;
  final int version;
  final ArtifactCommentPlace place;
  final ArtifactComment? reply, edit;
  final ArtifactReviewStore? review;
  final ArtifactReviewDraft? draft;

  bool get editing => edit != null || draft != null;
  final VoidCallback? onCancel, onDone;
  final bool autofocus, standing;
  final ArtifactCommentInsert? insert;
  final void Function(Object, ArtifactReviewComposerState?)?
  onReviewComposerChanged;

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
      'artifact-comment-v1:${jsonEncode([widget.store.workspace.client.origin, widget.store.workspace.client.user?.id, widget.store.serverId, widget.store.api.artifactId, widget.version, widget.place.toJson(), widget.reply?.id, widget.edit?.id, if (widget.draft != null) widget.draft!.id])}';

  @override
  void initState() {
    super.initState();
    if (widget.insert != null) _trackReportFocus(true);
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
    } else if ((widget.edit?.body ?? widget.draft?.body) case final body?) {
      var offset = 0;
      for (final part in body) {
        if (part.actor case final actor?) {
          _mentions.add((start: offset, actor: actor));
        }
        offset += part.display.length;
      }
      _text.text = body.map((part) => part.display).join();
    }
    _before = _text.text;
    _text.addListener(_changed);
    _focus.addListener(_changed);
    _reportReviewComposer(false);
    if (!widget.editing) unawaited(_readRecipients());
    _applyInsert();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.store.current) return;
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
        _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ArtifactCommentComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.insert == null) != (widget.insert == null)) {
      _trackReportFocus(widget.insert != null);
    }
    if (oldWidget.insert != widget.insert) _applyInsert();
    final previous = oldWidget.onReviewComposerChanged;
    if (previous != widget.onReviewComposerChanged) {
      if (previous != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => previous(this, null),
        );
      }
      _reportReviewComposer(_focus.hasFocus);
    }
  }

  void _trackReportFocus(bool track) {
    final modality = RaftFocusVisible.shared;
    if (track) {
      modality.addRingListener(_reportFocusChanged);
    } else {
      modality.removeRingListener(_reportFocusChanged);
    }
  }

  void _reportFocusChanged() {
    if (_focus.hasFocus) setState(() {});
  }

  void _applyInsert() {
    final insert = widget.insert;
    if (insert == null || insert._applied) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.store.current ||
          _busy ||
          insert._applied ||
          widget.insert != insert) {
        return;
      }
      final draft = _text.text;
      final text = draft.isEmpty ? insert.text : '$draft\n\n${insert.text}';
      insert._applied = true;
      _text.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      if (!RaftInteraction.of(context).touch) _focus.requestFocus();
    });
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
      if (token.start < offset || !text.startsWith(label, token.start)) {
        continue;
      }
      if (token.start > offset) {
        parts.add(
          ArtifactCommentPart.text(text.substring(offset, token.start)),
        );
      }
      parts.add(ArtifactCommentPart.mention(token.actor));
      offset = token.start + label.length;
    }
    if (offset < text.length) {
      parts.add(ArtifactCommentPart.text(text.substring(offset)));
    }
    return parts;
  }

  bool get _canSend =>
      !_busy &&
      !_uploading &&
      (_text.text.trim().isNotEmpty ||
          _images.isNotEmpty ||
          widget.edit?.images.isNotEmpty == true ||
          widget.draft?.images.isNotEmpty == true);

  Future<void> _send({bool asDraft = false}) async {
    if (!_canSend ||
        ((asDraft || widget.draft != null) && widget.review?.busy == true)) {
      return;
    }
    setState(() {
      _busy = true;
      _problem.clear();
    });
    try {
      final body = _body;
      if (widget.edit case final edit?) {
        await widget.store.edit(edit.id, body);
      } else if (widget.draft case final draft?) {
        await widget.review!.edit(draft.id, body);
      } else {
        final input = ArtifactCommentInput(
          version: widget.version,
          place: widget.place,
          replyTo: widget.reply?.id,
          body: body,
          images: _images.map((image) => image.id).toList(),
        );
        if (asDraft) {
          await widget.review!.save(input);
        } else {
          await widget.store.send(input);
        }
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
          _ when asDraft || widget.draft != null =>
            "Couldn't save the draft. Try again.",
          _ => "Couldn't send the comment. Try again.",
        }),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _applyInsert();
      }
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
          if (mounted) {
            setState(
              () => _problem.raise(
                'Only PNG, JPEG, WebP and GIF images can be attached.',
              ),
            );
          }
          continue;
        }
        if (!mounted || !widget.store.current) return;
        final id = await widget.store.api.upload(bytes, type!);
        if (!mounted || !widget.store.current) return;
        setState(() => _images.add((id: id, name: file.name)));
        _save();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _problem.raise("It didn't upload. Retry, or remove it."),
        );
      }
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
    if (widget.insert != null) _trackReportFocus(false);
    _reportReviewComposer(false, disposing: true);
    _debounce?.cancel();
    _focus.removeListener(_changed);
    _focus.dispose();
    _text.removeListener(_changed);
    _text.dispose();
    super.dispose();
  }

  void _reportReviewComposer(bool focused, {bool disposing = false}) {
    final report = widget.onReviewComposerChanged;
    if (report == null) return;
    final value = disposing
        ? null
        : (
            engaged: focused || !widget.standing,
            editingDraft: widget.draft != null,
          );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted || disposing) report(this, value);
    });
  }

  String? _audienceDescription(BuildContext context) {
    if (_recipients == null && !widget.editing) return null;
    final recipients = {
      for (final entry
          in _recipients ?? const <({ArtifactActor actor, String reason})>[])
        (entry.actor.type, entry.actor.id): entry.actor,
      for (final token in _mentions)
        (token.actor.type, token.actor.id): token.actor,
    };
    if (recipients.isNotEmpty) {
      return raftFormat(context, 'Will notify: {names}', {
        'names': recipients.values
            .map((actor) => artifactCommentActorName(context, actor))
            .join(', '),
      });
    }
    return _recipients == null
        ? null
        : raftText(context, "Won't notify anyone.");
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final placeholder = raftText(
      context,
      widget.reply == null ? 'Comment' : 'Reply',
    );
    final audience = _audienceDescription(context);
    return Focus(
      onKeyEvent: _onKey,
      onFocusChange: _reportReviewComposer,
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
          _composerBox(placeholder, audience: audience),
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
        ],
      ),
    );
  }

  VoidCallback? get _attachAction =>
      _busy || _uploading || _images.length == 4 ? null : _attach;

  bool get _hasDraftAction => !widget.editing && widget.review != null;

  Widget _cancel() => RaftButton(
    label: 'Cancel',
    tone: RaftButtonRecipeVariant.ghost,
    onPressed: _busy ? null : widget.onCancel,
  );

  Widget _saveDraft() => RaftButton(
    key: const ValueKey('artifact-comment-save-draft'),
    label: 'Save draft',
    tone: RaftButtonRecipeVariant.outline,
    size: RaftButtonRecipeSize.md,
    onPressed: _canSend && widget.review!.loaded && !widget.review!.busy
        ? () => unawaited(_send(asDraft: true))
        : null,
  );

  Widget _sendButton({required bool text, String? recipientTooltip}) {
    final label = widget.editing ? 'Save' : 'Send';
    return RaftButton(
      key: const ValueKey('artifact-comment-send'),
      label: text ? label : '',
      glyph: text ? null : (widget.editing ? RaftGlyph.check : RaftGlyph.send),
      semanticLabel: text ? null : raftText(context, label),
      tooltip: recipientTooltip,
      size: text ? RaftButtonRecipeSize.md : RaftButtonRecipeSize.iconSm,
      onPressed: _canSend ? _send : null,
    );
  }

  Widget _composerBox(String placeholder, {String? audience}) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final reporting = widget.insert != null;
    final slots = RaftComposerRecipe.compactSlots(
      t,
      focusVisible:
          _focus.hasFocus &&
          (!reporting || RaftFocusVisible.shared.ringVisible),
    );
    final input = slots.input;
    var style = input.text(tokens, base: DefaultTextStyle.of(context).style);
    // The CSS body's fine-pointer tier keeps report facts on their own lines.
    // Continue using the recipe for the font family's ink and other properties.
    if (reporting && t.desktop) {
      final body = t.typeSlot('body');
      style = style.copyWith(fontSize: body.fontSize, height: body.height);
    }
    // CSS extends the toolbar into the box's side padding. Give the editor
    // that padding back while keeping the toolbar inside its hit bounds.
    final margin = slots.toolbar.margin;
    return RaftTapSlopHost(
      child: RaftRecipeBox(
        key: const ValueKey('artifact-comment-frame'),
        style: slots.root,
        tokens: tokens,
        declareSurface: true,
        decorationOverride: (decoration) => raftSnapBorder(context, decoration),
        padding: slots.root.padding + margin,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: slots.root.rowGap ?? RaftSpace.x2,
          children: [
            Padding(
              padding: input.padding - margin,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: input.minHeight!,
                  // The editor scrolls within its viewport so enlarged text
                  // leaves the toolbar reachable in the comments sheet.
                  maxHeight: input.maxHeight!,
                ),
                child: Semantics(
                  label: placeholder,
                  hint: audience,
                  child: RaftBareInput(
                    fieldKey: const ValueKey('artifact-comment-input'),
                    controller: _text,
                    focusNode: _focus,
                    enabled: !_busy,
                    multiline: true,
                    textAlignVertical: TextAlignVertical.top,
                    hintText: placeholder,
                    style: style,
                    hintStyle: style.copyWith(
                      color: input
                          .target('::placeholder')
                          ?.color
                          ?.resolve(tokens),
                    ),
                    cursorColor: style.color,
                  ),
                ),
              ),
            ),
            Row(
              spacing: slots.toolbar.columnGap ?? RaftSpace.x1,
              children: [
                if (!widget.editing)
                  RaftComposerAction(
                    key: const ValueKey('artifact-comment-attach'),
                    glyph: RaftGlyph.imagePlus,
                    tooltip: 'Add image',
                    onPressed: _attachAction,
                  ),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: slots.meta.columnGap ?? RaftSpace.x1,
                    runSpacing: slots.meta.rowGap ?? RaftSpace.x1,
                    children: [
                      if (widget.onCancel != null) _cancel(),
                      if (_hasDraftAction) _saveDraft(),
                      _sendButton(
                        text: _hasDraftAction,
                        recipientTooltip: RaftInteraction.of(context).pointer
                            ? audience
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
