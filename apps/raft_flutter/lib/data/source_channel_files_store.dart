import 'package:flutter/foundation.dart';

typedef ChannelFilesGet = Future<dynamic> Function(
  String path, {
  Map<String, dynamic>? query,
});

@immutable
class SourceChannelFileEntry {
  const SourceChannelFileEntry(
    this.metadata,
    this.messageId,
    this.channelId,
    this.sourceChannelId,
    this.parentMessageId,
    this.sourceType,
    this.createdAt,
  );
  final Map<String, dynamic> metadata;
  final String messageId, channelId, sourceChannelId, sourceType, createdAt;
  final String? parentMessageId;
  String get id => metadata['id'] as String;
  String get filename => metadata['filename'] as String;
  String get mimeType => metadata['mimeType'] as String;
  int get sizeBytes => metadata['sizeBytes'] as int;
  static SourceChannelFileEntry parse(dynamic raw) {
    if (raw is! Map || raw['source'] is! Map) {
      throw const FormatException('Invalid files response.');
    }
    final row = Map<String, dynamic>.from(raw);
    final source = Map<String, dynamic>.from(row['source'] as Map);
    String requiredString(Map<String, dynamic> map, String key) {
      final value = map[key];
      if (value is! String || value.isEmpty) {
        throw const FormatException('Invalid files response.');
      }
      return value;
    }

    final id = requiredString(row, 'id'),
        message = requiredString(row, 'messageId');
    final channel = requiredString(row, 'channelId'),
        sourceChannel = requiredString(source, 'channelId');
    final kind = requiredString(source, 'type');
    if (kind != 'channel' && kind != 'thread') {
      throw const FormatException('Invalid files source.');
    }
    final parent = source['parentMessageId'];
    if (kind == 'thread' && (parent is! String || parent.isEmpty)) {
      throw const FormatException('Invalid thread source.');
    }
    final name = requiredString(row, 'filename'),
        mime = requiredString(row, 'mimeType');
    final size = row['sizeBytes'];
    final created = requiredString(row, 'createdAt');
    if (size is! num ||
        !size.isFinite ||
        size < 0 ||
        DateTime.tryParse(created) == null) {
      throw const FormatException('Invalid files metadata.');
    }
    return SourceChannelFileEntry(
      Map.unmodifiable({
        'id': id,
        'filename': name,
        'mimeType': mime,
        'sizeBytes': size.toInt(),
        for (final key in ['width', 'height', 'thumbnailUrl'])
          if (row[key] != null) key: row[key],
      }),
      message,
      channel,
      sourceChannel,
      parent is String ? parent : null,
      kind,
      created,
    );
  }
}

enum ChannelFilesFailure { unavailable, unauthorized, malformed }

class ChannelFilesRequestFailure implements Exception {
  const ChannelFilesRequestFailure(this.failure);
  final ChannelFilesFailure failure;
}

/// Account/window-owned in-memory projection. No disk persistence or resolved
/// signed capabilities; backend thumbnail projection stays in this live view only.
class SourceChannelFilesStore extends ChangeNotifier {
  SourceChannelFilesStore({
    required this.channelId,
    required this.get,
    required this.authority,
  }) : _authority = authority();
  final String channelId;
  final ChannelFilesGet get;
  final String? Function() authority;
  String? _authority;
  int _epoch = 0, _request = 0;
  bool _disposed = false;
  bool loading = false, loadingMore = false;
  ChannelFilesFailure? error;
  String? nextCursor;
  List<SourceChannelFileEntry> _files = const [];
  List<SourceChannelFileEntry> get files => _files;
  bool get authorized =>
      !_disposed && _authority != null && _authority == authority();
  bool contains(SourceChannelFileEntry file) =>
      authorized && _files.any((current) => identical(current, file));
  bool syncAuthority() {
    if (_disposed) return false;
    final current = authority();
    if (current == _authority) return false;
    _authority = current;
    _epoch++;
    _request++;
    _files = const [];
    nextCursor = null;
    error = null;
    loading = false;
    loadingMore = false;
    notifyListeners();
    return true;
  }

  Future<void> load({bool more = false}) async {
    syncAuthority();
    if (!authorized || (more && (loading || loadingMore || nextCursor == null))) {
      return;
    }
    final epoch = _epoch, request = ++_request, owner = _authority;
    final cursor = more ? nextCursor : null;
    if (more) {
      loadingMore = true;
    } else {
      loading = true;
      nextCursor = null;
      _files = const [];
    }
    error = null;
    notifyListeners();
    bool current() =>
        !_disposed &&
        authorized &&
        owner == _authority &&
        epoch == _epoch &&
        request == _request;
    try {
      final data = await get(
        '/channels/${Uri.encodeComponent(channelId)}/files',
        query: {'limit': 50, 'cursor': ?cursor},
      );
      if (!current()) return;
      if (data is! Map ||
          data['files'] is! List ||
          (data['nextCursor'] != null && data['nextCursor'] is! String)) {
        throw const FormatException('Invalid files response.');
      }
      final next = data['nextCursor'];
      if (next is String && (next.isEmpty || (more && next == cursor))) {
        throw const FormatException('Invalid files cursor.');
      }
      final page = (data['files'] as List)
          .map(SourceChannelFileEntry.parse)
          .toList();
      // Direct rows must belong to the requested channel; thread rows require
      // the backend-projected parent/thread source metadata, not guessed IDs.
      if (page.any(
        (file) =>
            file.channelId != file.sourceChannelId ||
            (file.sourceType == 'channel' && file.sourceChannelId != channelId),
      )) {
        throw const FormatException('Invalid files source.');
      }
      final byId = {
        if (more)
          for (final file in _files) file.id: file,
        for (final file in page) file.id: file,
      };
      _files = List.unmodifiable(byId.values);
      nextCursor = data['nextCursor'] as String?;
    } on ChannelFilesRequestFailure catch (failure) {
      if (current()) {
        error = failure.failure;
        if (failure.failure == ChannelFilesFailure.unauthorized) {
          _files = const [];
          nextCursor = null;
        }
      }
    } on FormatException {
      if (current()) error = ChannelFilesFailure.malformed;
    } catch (_) {
      if (current()) error = ChannelFilesFailure.unavailable;
    } finally {
      if (current()) {
        loading = false;
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _request++;
    _authority = null;
    _files = const [];
    nextCursor = null;
    error = null;
    super.dispose();
  }
}
