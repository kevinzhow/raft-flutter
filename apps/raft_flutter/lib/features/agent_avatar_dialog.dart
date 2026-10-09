// One-field staged avatar editing, matching AgentProfileEditDialog.tsx.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

class AgentAvatarUpload {
  const AgentAvatarUpload(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

Future<AgentAvatarUpload?> pickAgentAvatar() async {
  final f = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(
        label: 'Images',
        extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'avif'],
        mimeTypes: ['image/*'],
      ),
    ],
  );
  if (f == null) return null;
  // Reject before reading potentially large native files into memory.
  if (await f.length() > 5 * 1024 * 1024) {
    throw const RaftApiException('Image must be at most 5 MB.');
  }
  return AgentAvatarUpload(f.name, await f.readAsBytes());
}

String? agentProfileAvatarUrl(String origin, String? stored) {
  if (stored == null || stored.startsWith('pixel:')) return stored;
  final uri = Uri.tryParse(stored);
  if (uri == null || uri.userInfo.isNotEmpty) return null;
  final resolved = Uri.parse(origin).resolveUri(uri);
  return ['https', 'http'].contains(resolved.scheme)
      ? resolved.toString()
      : null;
}

class AgentAvatarDialog extends StatefulWidget {
  const AgentAvatarDialog({
    super.key,
    required this.controller,
    required this.agent,
    required this.authorized,
    required this.onSaved,
    this.pickUpload = pickAgentAvatar,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> agent;
  final bool Function() authorized;
  final ValueChanged<Map<String, dynamic>> onSaved;
  final Future<AgentAvatarUpload?> Function() pickUpload;
  @override
  State<AgentAvatarDialog> createState() => _AgentAvatarDialogState();
}

class _AgentAvatarDialogState extends State<AgentAvatarDialog> {
  String? preset;
  bool changed = false, busy = false, confirming = false;
  AgentAvatarUpload? upload;
  String? error;
  int ticket = 0;
  DialogRoute<bool>? discardRoute;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(authorityChanged);
  }

  void authorityChanged() {
    if (!widget.authorized()) {
      ++ticket;
      final route = discardRoute;
      if (route?.isActive == true) {
        route!.navigator?.removeRoute(route);
      }
      if (mounted) {
        setState(() {
          busy = false;
          changed = false;
          upload = null;
        });
      }
    }
  }

  bool get valid => mounted && widget.authorized();
  @override
  void dispose() {
    ++ticket;
    widget.controller.removeListener(authorityChanged);
    final route = discardRoute;
    if (route?.isActive == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route!.isActive) route.navigator?.removeRoute(route);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    upload = null;
    super.dispose();
  }

  Future<void> chooseUpload() async {
    if (!valid || busy) return;
    final own = ++ticket;
    try {
      final next = await widget.pickUpload();
      if (!valid || own != ticket || next == null) return;
      if (next.bytes.length > 5 * 1024 * 1024) {
        throw const RaftApiException('Image must be at most 5 MB.');
      }
      setState(() {
        upload = next;
        preset = null;
        changed = true;
        error = null;
      });
    } catch (e) {
      if (valid && own == ticket) setState(() => error = '$e');
    }
  }

  Future<void> close() async {
    if (!valid || busy || confirming) return;
    if (changed) {
      confirming = true;
      final route = DialogRoute<bool>(
        context: context,
        builder: (c) => RaftAvatarDiscardConfirmation(
          onKeep: () => Navigator.pop(c, false),
          onDiscard: () => Navigator.pop(c, true),
        ),
      );
      discardRoute = route;
      final discard = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(route);
      discardRoute = null;
      confirming = false;
      if (!mounted || !valid || discard != true) return;
    }
    if (!mounted || !valid) return;
    changed = false;
    Navigator.pop(context);
  }

  Future<void> save() async {
    if (!valid || busy || !changed) return;
    setState(() {
      busy = true;
      error = null;
    });
    final own = ++ticket;
    try {
      final id = widget.agent['id'];
      final data = upload == null
          ? {
              'avatarUrl': preset == null || preset == 'robot'
                  ? null
                  : 'pixel:$preset',
            }
          : FormData.fromMap({
              'avatar': MultipartFile.fromBytes(
                upload!.bytes,
                filename: upload!.name,
              ),
            });
      final result = await widget.controller.command(
        upload == null ? 'PATCH' : 'POST',
        upload == null ? '/agents/$id' : '/agents/$id/avatar',
        data: data,
      );
      if (!mounted || !valid || own != ticket) return;
      widget.onSaved({
        ...widget.agent,
        if (result is Map) ...Map<String, dynamic>.from(result),
        if (upload == null &&
            !(result is Map && result.containsKey('avatarUrl')))
          'avatarUrl': preset == null || preset == 'robot'
              ? null
              : 'pixel:$preset',
      });
      if (!mounted || !valid) return;
      changed = false;
      Navigator.pop(context);
    } catch (e) {
      if (valid && own == ticket) setState(() => error = '$e');
    } finally {
      if (valid && own == ticket) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.authorized()) return const SizedBox.shrink();
    final stored = widget.agent['avatarUrl'] as String?;
    final current = changed
        ? preset
        : RaftAvatarSlot.pixelKey(stored) ?? (stored == null ? 'robot' : null);
    final url = changed && upload == null
        ? (preset == null ? null : 'pixel:$preset')
        : agentProfileAvatarUrl(widget.controller.client.origin, stored);
    final preview = upload == null
        ? RaftAvatarSlot(
            name: '${widget.agent['name']}',
            avatarUrl: url,
            slot: RaftAvatarSlotContext.profileTile,
          )
        : RaftAvatarSlot(
            name: '${widget.agent['name']}',
            slot: RaftAvatarSlotContext.profileTile,
            content: Image.memory(
              upload!.bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, e, s) =>
                  const RaftIcon(RaftGlyph.imageOff, size: 24),
            ),
          );
    return PopScope(
      canPop: !busy && !changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: RaftAgentAvatarPicker(
        name: '${widget.agent['name']}',
        preview: preview,
        selectedKey: current,
        uploadSelected:
            upload != null ||
            !changed && stored != null && !stored.startsWith('pixel:'),
        dirty: changed,
        busy: busy,
        error: error,
        onChoice: (key) {
          if (!valid || busy) return;
          ++ticket;
          setState(() {
            changed = true;
            preset = key;
            upload = null;
            error = null;
          });
        },
        onUpload: chooseUpload,
        onClose: close,
        onSave: save,
      ),
    );
  }
}
