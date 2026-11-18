import 'package:raft_ui/raft_ui.dart';

import 'message_card_read.dart';

enum AppLinkPlacement { hover, block }

typedef LinkApp = ({String id, String name, String? icon});

sealed class AppLinkResult {
  const AppLinkResult(this.url, this.app);
  final String url;
  final LinkApp app;
}

final class AppLinkConsent extends AppLinkResult {
  const AppLinkConsent(super.url, super.app);
}

final class AppLinkConnect extends AppLinkResult {
  const AppLinkConnect(super.url, super.app, this.connectUrl);
  final String connectUrl;
}

final class AppLinkPreview extends AppLinkResult {
  const AppLinkPreview(
    super.url,
    super.app, {
    required this.title,
    required this.chipTitle,
    required this.placement,
    this.tree,
    this.buttons = const {},
    this.revision,
    this.ticket,
    this.readAt,
  });

  final String title;
  final String? chipTitle, revision, ticket;
  final AppLinkPlacement? placement;
  final RaftCardElement? tree;
  final Map<RaftCardButton, AppLinkAction> buttons;
  final DateTime? readAt;
}

sealed class AppLinkAction {
  const AppLinkAction();
}

final class AppLinkOpen extends AppLinkAction {
  const AppLinkOpen(this.url);
  final String url;
}

final class AppLinkRefresh extends AppLinkAction {
  const AppLinkRefresh();
}

final class AppLinkExecute extends AppLinkAction {
  const AppLinkExecute(this.id, this.handle, {this.undoWindow});
  final String id;
  final String? handle;
  final Duration? undoWindow;
}

String? appLinkKey(String raw) {
  final uri = publicCardUrl(raw);
  if (uri == null) return null;
  return (uri.path.isEmpty ? uri.replace(path: '/') : uri).toString();
}

LinkApp? _app(Object? value) {
  if (value case {'id': final String id, 'name': final String name}) {
    return (id: id, name: name, icon: _text((value as Map)['icon'], 2000));
  }
  return null;
}

String? _text(Object? value, int max) =>
    value is String && value.isNotEmpty && value.runes.length <= max
    ? value
    : null;

typedef AppLinkAnswer = ({
  Map<String, AppLinkResult> links,
  Map<String, int> retrySeconds,
});

AppLinkAnswer readAppLinkAnswer(Object? json, {required bool interactive}) {
  final links = <String, AppLinkResult>{};
  final retrySeconds = <String, int>{};
  if (json is! Map) return (links: links, retrySeconds: retrySeconds);
  final rows = json[interactive ? 'items' : 'previews'];
  if (rows is List) {
    for (final row in rows.take(10)) {
      if (row is! Map || row['url'] is! String) continue;
      final url = appLinkKey(row['url'] as String);
      if (url == null || links.containsKey(url)) continue;
      if (interactive && row['kind'] == 'rate_limited') {
        if (row['retry_after'] case final int seconds) {
          retrySeconds[url] = seconds.clamp(1, 60);
        }
        continue;
      }
      final icons = json['appIcons'];
      final app = interactive
          ? _app(row['app'])
          : switch (row['appName']) {
              final String name => (
                id: name,
                name: name,
                icon: icons is Map ? _text(icons[row['url']], 2000) : null,
              ),
              _ => null,
            };
      if (app == null) continue;
      final preview = interactive ? row['preview'] : row;
      if (preview is! Map) continue;
      final result = _preview(url, app, preview, row, interactive);
      if (result != null) links[url] = result;
    }
  }
  final prompts = json['prompts'];
  if (prompts is List) {
    for (final prompt in prompts.take(10)) {
      if (prompt is! Map || prompt['url'] is! String) continue;
      final app = _app(prompt['app']);
      final url = appLinkKey(prompt['url'] as String);
      if (app != null && url != null) {
        links.putIfAbsent(url, () => AppLinkConsent(url, app));
      }
    }
  }
  return (links: links, retrySeconds: retrySeconds);
}

AppLinkResult? _preview(
  String url,
  LinkApp app,
  Map preview,
  Map row,
  bool interactive,
) {
  final version = interactive ? row['kind'] : 'v1';
  final items = preview['items'];
  final inline = version == 'v3' && items is List
      ? items
            .whereType<Map>()
            .where((item) => item['type'] == 'inline')
            .firstOrNull
      : preview['inline'];
  final card = version == 'v3' && items is List
      ? items
            .whereType<Map>()
            .where((item) => item['type'] == 'card')
            .firstOrNull
      : preview;
  final connect = version == 'v3' && items is List
      ? items
            .whereType<Map>()
            .where((item) => item['type'] == 'connect_account')
            .firstOrNull
      : preview['display'] == 'connect_account'
      ? preview
      : null;
  if (connect != null) {
    final address = _text(connect['connect_url'], 2000);
    return address == null || publicCardUrl(address) == null
        ? null
        : AppLinkConnect(url, app, address);
  }
  if (version == 'v2' && preview['display'] != 'card') return null;
  if (version != 'v1' && version != 'v2' && version != 'v3') return null;
  final inlineTitle = inline is Map ? _text(inline['title'], 200) : null;
  final title = _text(card?['title'], 200) ?? inlineTitle;
  if (title == null) return null;
  final placement = card == null
      ? null
      : card['placement'] == 'block'
      ? AppLinkPlacement.block
      : AppLinkPlacement.hover;
  final actions = row['actions'];
  final handles = {
    if (actions is List)
      for (final action in actions.take(4))
        if (action
            case {'action_id': final String id, 'handle': final String handle}
            when handle.isNotEmpty && handle.length <= 4096)
          id: handle,
  };
  final buttons = <RaftCardButton, AppLinkAction>{};
  final rawTree = card?['card'];
  RaftCardElement? tree;
  if (rawTree is Map) {
    tree = readMessageCard(
      {
        'kind': messageCardKind,
        'revision': 1,
        'card': {'version': 1, ...rawTree},
      },
      linkButton: (props) {
        final label = _text(props['label'], 40);
        if (label == null) return null;
        final action = switch (props['action']) {
          {'kind': 'navigate', 'url': final String address}
              when publicCardUrl(address) != null =>
            AppLinkOpen(address),
          {'kind': 'read'} => const AppLinkRefresh(),
          {
            'kind': 'execute',
            'action_id': final String id,
            'confirm': 'prepare',
          } =>
            AppLinkExecute(id, handles[id]),
          {
            'kind': 'execute',
            'action_id': final String id,
            'undoWindowMs': final int ms,
          }
              when ms >= 1000 && ms <= 10000 =>
            AppLinkExecute(
              id,
              handles[id],
              undoWindow: Duration(milliseconds: ms),
            ),
          _ => AppLinkOpen(url),
        };
        final button = RaftCardButton(
          label: label,
          url: action is AppLinkOpen ? action.url : url,
          domain: Uri.parse(url).host,
          ghost: props['variant'] == 'ghost',
          disabledReason: _text(props['disabledReason'], 200),
        );
        buttons[button] = action;
        return button;
      },
    )?.root;
    if (tree == null) return null;
  }
  return AppLinkPreview(
    url,
    app,
    title: title,
    chipTitle:
        inlineTitle ??
        (version == 'v3' && placement == AppLinkPlacement.block ? null : title),
    placement: placement,
    tree: tree,
    buttons: buttons,
    revision: _text(card?['business_revision'], 512),
    ticket: _text(row['ticket'], 4096),
    readAt: DateTime.now(),
  );
}
