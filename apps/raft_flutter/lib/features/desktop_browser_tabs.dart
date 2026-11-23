import 'dart:math' as math;

import 'package:flutter/foundation.dart';

const desktopBrowserTabLimit = 12;

typedef BrowserPageState = ({
  Uri? url,
  String title,
  bool back,
  bool forward,
  bool loading,
});

@immutable
class DesktopBrowserTab {
  const DesktopBrowserTab._({
    required this.id,
    required this.requested,
    required this.navigation,
    required this.page,
  });

  factory DesktopBrowserTab._create(int id, Uri? url) => DesktopBrowserTab._(
    id: id,
    requested: url,
    navigation: url == null ? 0 : 1,
    page: _loading(url),
  );

  final int id;
  final Uri? requested;
  final int navigation;
  final BrowserPageState page;

  Uri? get url => page.url;
  String get title => page.title;
  bool get loading => page.loading;

  DesktopBrowserTab _navigate(Uri url) => DesktopBrowserTab._(
    id: id,
    requested: url,
    navigation: navigation + 1,
    page: _loading(url, back: page.back, forward: page.forward),
  );

  DesktopBrowserTab _report(BrowserPageState state) => DesktopBrowserTab._(
    id: id,
    requested: requested,
    navigation: navigation,
    page: (
      url: state.url ?? url,
      title: state.title,
      back: state.back,
      forward: state.forward,
      loading: state.loading,
    ),
  );

  static BrowserPageState _loading(
    Uri? url, {
    bool back = false,
    bool forward = false,
  }) =>
      (url: url, title: '', back: back, forward: forward, loading: url != null);
}

@immutable
class DesktopBrowser {
  DesktopBrowser._(
    List<DesktopBrowserTab> tabs, {
    required this.activeId,
    required this.frontAt,
    required this.openedAt,
    this.parkedAt = 0,
  }) : tabs = List.unmodifiable(tabs);

  final List<DesktopBrowserTab> tabs;
  final int activeId, frontAt, openedAt, parkedAt;

  DesktopBrowserTab get active => tabs.firstWhere((tab) => tab.id == activeId);

  bool inFrontOf(int artifactOpenedAt) =>
      frontAt >= math.max(artifactOpenedAt, parkedAt);

  DesktopBrowser _with({
    List<DesktopBrowserTab>? tabs,
    int? activeId,
    int? frontAt,
    int? openedAt,
    int? parkedAt,
  }) => DesktopBrowser._(
    tabs ?? this.tabs,
    activeId: activeId ?? this.activeId,
    frontAt: frontAt ?? this.frontAt,
    openedAt: openedAt ?? this.openedAt,
    parkedAt: parkedAt ?? this.parkedAt,
  );

  DesktopBrowser _replace(DesktopBrowserTab replacement) => _with(
    tabs: [
      for (final tab in tabs)
        if (tab.id == replacement.id) replacement else tab,
    ],
  );
}

class DesktopBrowserTabs extends ChangeNotifier {
  final placement = ValueNotifier(0);
  final _browsers = <String, DesktopBrowser>{};
  final _openerFocus = <String, VoidCallback>{};
  int _sequence = 0;
  static int _lastPlacement = 0;

  DesktopBrowser? forConversation(String? conversation) =>
      _browsers[conversation];

  static int nextPlacement() => _lastPlacement = math.max(
    DateTime.now().millisecondsSinceEpoch,
    _lastPlacement + 1,
  );

  void _put(String conversation, DesktopBrowser browser) {
    final previous = _browsers[conversation];
    _browsers[conversation] = browser;
    if (previous?.frontAt != browser.frontAt ||
        previous?.parkedAt != browser.parkedAt) {
      placement.value++;
    }
    notifyListeners();
  }

  void open(String conversation, Uri target, {VoidCallback? onClose}) {
    final url = _browserAddress(target);
    if (url == null) return;
    if (onClose == null) {
      _openerFocus.remove(conversation);
    } else {
      _openerFocus[conversation] = onClose;
    }
    final browser = forConversation(conversation);
    final frontAt = nextPlacement();
    if (browser == null) {
      final tab = DesktopBrowserTab._create(++_sequence, url);
      _put(
        conversation,
        DesktopBrowser._(
          [tab],
          activeId: tab.id,
          frontAt: frontAt,
          openedAt: frontAt,
        ),
      );
      return;
    }
    final existing = browser.tabs
        .where((tab) => tab.url == url || tab.requested == url)
        .firstOrNull;
    if (existing != null) {
      _put(
        conversation,
        browser._with(activeId: existing.id, frontAt: frontAt),
      );
    } else if (browser.tabs.length == desktopBrowserTabLimit) {
      _put(
        conversation,
        browser
            ._replace(browser.active._navigate(url))
            ._with(frontAt: frontAt, openedAt: frontAt),
      );
    } else {
      final tab = DesktopBrowserTab._create(++_sequence, url);
      _put(
        conversation,
        browser._with(
          tabs: [...browser.tabs, tab],
          activeId: tab.id,
          frontAt: frontAt,
          openedAt: frontAt,
        ),
      );
    }
  }

  void newTab(String conversation) {
    final browser = forConversation(conversation);
    if (browser == null || browser.tabs.length >= desktopBrowserTabLimit) {
      return;
    }
    final tab = DesktopBrowserTab._create(++_sequence, null);
    _put(
      conversation,
      browser._with(tabs: [...browser.tabs, tab], activeId: tab.id),
    );
  }

  void activate(String conversation, int id) {
    final browser = forConversation(conversation);
    if (browser == null ||
        browser.activeId == id ||
        !browser.tabs.any((tab) => tab.id == id)) {
      return;
    }
    _put(conversation, browser._with(activeId: id));
  }

  void navigate(String conversation, int id, Uri target) {
    final browser = forConversation(conversation);
    final url = _browserAddress(target);
    final tab = browser?.tabs.where((tab) => tab.id == id).firstOrNull;
    if (browser == null || tab == null || url == null) return;
    _put(conversation, browser._replace(tab._navigate(url)));
  }

  void report(String conversation, int id, BrowserPageState state) {
    final browser = forConversation(conversation);
    final tab = browser?.tabs.where((tab) => tab.id == id).firstOrNull;
    if (browser == null || tab == null) return;
    final next = tab._report((
      url: _browserAddress(state.url),
      title: state.title,
      back: state.back,
      forward: state.forward,
      loading: state.loading,
    ));
    if (next.page != tab.page) _put(conversation, browser._replace(next));
  }

  void closeTab(String conversation, int id) {
    final browser = forConversation(conversation);
    if (browser == null) return;
    final index = browser.tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    if (browser.tabs.length == 1) {
      close(conversation);
      return;
    }
    final remaining = [...browser.tabs]..removeAt(index);
    _put(
      conversation,
      browser._with(
        tabs: remaining,
        activeId: browser.activeId == id
            ? remaining[math.min(index, remaining.length - 1)].id
            : browser.activeId,
      ),
    );
  }

  void close(String conversation) {
    if (_browsers.remove(conversation) == null) return;
    final returnFocus = _openerFocus.remove(conversation);
    placement.value++;
    notifyListeners();
    returnFocus?.call();
  }

  void clear() {
    if (_browsers.isEmpty) return;
    _browsers.clear();
    _openerFocus.clear();
    placement.value++;
    notifyListeners();
  }

  void raise(String conversation) {
    final browser = forConversation(conversation);
    if (browser != null) {
      _put(conversation, browser._with(frontAt: nextPlacement()));
    }
  }

  void park(String conversation) {
    final browser = forConversation(conversation);
    if (browser != null) {
      _put(conversation, browser._with(parkedAt: nextPlacement()));
    }
  }

  @override
  void dispose() {
    placement.dispose();
    super.dispose();
  }
}

Uri? _browserAddress(Uri? uri) {
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri.path.isEmpty ? uri.replace(path: '/') : uri;
}
