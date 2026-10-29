import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/oauth_return_page.dart';

String _hash(String text) =>
    'sha256-${base64.encode(sha256.convert(utf8.encode(text)).bytes)}';

String _between(String html, String open, String close) {
  final start = html.indexOf(open) + open.length;
  return html.substring(start, html.indexOf(close, start));
}

void main() {
  final variants = <String, ({String? language, String? error})>{
    for (final language in ['en', 'zh'])
      for (final error in <String?>[
        null,
        'access_denied',
        'expired',
        'request_not_pending',
        'account_conflict',
        'registration_disabled',
        'provider_exchange_failed',
        'something_new',
      ])
        '$language/${error ?? 'none'}': (language: language, error: error),
  };

  group('every locale and state', () {
    for (final entry in variants.entries) {
      test(entry.key, () {
        final page = OAuthReturnPage.render(
          languageCode: entry.value.language,
          error: entry.value.error,
        );
        final html = page.html;
        // Never an external request: no scheme-qualified or protocol-relative
        // URL, no stylesheet/script/image source, no `url()` / `@import`.
        expect(
          html,
          isNot(matches(RegExp(r'(?:https?:)?//', caseSensitive: false))),
        );
        expect(html, isNot(contains('@import')));
        expect(html, isNot(contains('url(')));
        expect(html, isNot(contains('<script src')));
        expect(html, isNot(contains('<iframe')));
        expect(html, isNot(contains('<form')));
        expect(RegExp(r'<link ').allMatches(html), hasLength(1));
        expect(html, contains('<link rel="icon" href="data:image/svg+xml,'));
        expect(RegExp(r'\b(?:href|src)="(?!data:)').hasMatch(html), isFalse);
        // Inline mark, no tokens or codes.
        expect(html, contains('<svg class="brand"'));
        expect(html, isNot(contains('ephemeral')));
        expect(html, contains('prefers-color-scheme:dark'));
        // The error selects a fixed reason; the initial state follows it.
        final failed = entry.value.error != null;
        expect(
          html,
          contains('<body data-state="${failed ? 'failed' : 'checking'}"'),
        );
        expect(
          html,
          contains('lang="${entry.value.language == 'zh' ? 'zh-CN' : 'en'}"'),
        );
      });
    }
  });

  test('copy is localized: Web zh-cn wording and the English source', () {
    final en = OAuthReturnPage.render(languageCode: 'en').html;
    final zh = OAuthReturnPage.render(languageCode: 'zh').html;
    expect(en, contains('Returning to Raft'));
    expect(en, contains('Finishing sign-in…'));
    expect(
      en,
      contains('Sign-in is complete. You can close this browser page.'),
    );
    expect(en, contains('Failed to finish sign-in'));
    expect(en, contains('Return to Raft and try again.'));
    // Web zh-cn: finishingSignIn, approvedDescription, finishFailed.
    expect(zh, contains('正在完成登录…'));
    expect(zh, contains('登录已完成，你可以关闭此浏览器页面。'));
    expect(zh, contains('完成登录失败'));
    expect(zh, contains('请返回 Raft 重试。'));
    // No locale falls back to English; nothing in zh stays English.
    expect(OAuthReturnPage.render().html, en);
    expect(OAuthReturnPage.render(languageCode: 'fr').html, en);
    final enReasons = RegExp(
      r'class="reason" data-r="(\w+)">([^<]*)<',
    ).allMatches(en).map((m) => m[2]).toList();
    final zhReasons = RegExp(
      r'class="reason" data-r="(\w+)">([^<]*)<',
    ).allMatches(zh).map((m) => m[2]).toList();
    expect(enReasons, hasLength(OAuthReturnPage.reasonIds.length));
    expect(zhReasons, hasLength(enReasons.length));
    for (var i = 0; i < enReasons.length; i++) {
      expect(zhReasons[i], isNot(enReasons[i]));
      expect(zhReasons[i], matches(RegExp(r'[一-鿿]')));
    }
  });

  test('plain-word reasons for the OAuth callback errors', () {
    String reason(String? error) {
      final html = OAuthReturnPage.render(error: error).html;
      final id = _between(html, 'data-reason="', '"');
      return _between(html, 'data-r="$id">', '<');
    }

    expect(
      reason('access_denied'),
      'Sign-in was cancelled, or access was denied.',
    );
    expect(reason('provider_cancelled'), reason('access_denied'));
    expect(reason('expired'), 'This sign-in request has expired.');
    expect(
      reason('request_not_pending'),
      'This sign-in request was already used or is no longer valid.',
    );
    expect(
      reason('account_conflict'),
      'An account with this email already exists.',
    );
    expect(
      reason('registration_disabled'),
      'Registration is currently disabled.',
    );
    expect(
      reason('provider_exchange_failed'),
      contains("couldn&#39;t confirm"),
    );
    expect(reason('unknown_provider_thing'), 'Sign-in could not be completed.');
    // The script alone picks the two browser-side reasons.
    final html = OAuthReturnPage.render().html;
    expect(html, contains("no('mismatch')"));
    expect(html, contains("no('unreachable')"));
    for (final id in ['mismatch', 'unreachable']) {
      expect(html, contains('data-r="$id"'));
      expect(html, contains('body[data-reason=$id] .reason[data-r=$id]'));
    }
  });

  test('reflected values are never rendered; copy is HTML-escaped', () {
    for (final hostile in [
      '<script>alert(1)</script>',
      '"><img src=x onerror=alert(1)>',
      "'; document.cookie='x",
      '&lt;b&gt;',
      'a' * 5000,
    ]) {
      final page = OAuthReturnPage.render(languageCode: 'en', error: hostile);
      expect(page.html, isNot(contains(hostile)));
      expect(page.html, isNot(contains('alert(1)')));
      expect(
        page.html,
        contains('<body data-state="failed" data-reason="generic">'),
      );
      expect(RegExp('<script>').allMatches(page.html), hasLength(1));
    }
    // Apostrophes in the fixed copy are entities, so a quote never ends markup.
    final html = OAuthReturnPage.render().html;
    expect(html, contains('doesn&#39;t match'));
    expect(html, isNot(contains("doesn't match")));
  });

  test(
    'strict CSP: hashes match the inline style and script, nothing else',
    () {
      for (final language in ['en', 'zh']) {
        final page = OAuthReturnPage.render(languageCode: language);
        final script = _between(page.html, '<script>', '</script>');
        final style = _between(page.html, '<style>', '</style>');
        final csp = page.csp;
        expect(csp, contains("default-src 'none'"));
        expect(csp, contains("script-src '${_hash(script)}'"));
        expect(csp, contains("style-src '${_hash(style)}'"));
        expect(csp, contains('img-src data:'));
        expect(csp, contains("connect-src 'self'"));
        expect(csp, contains("base-uri 'none'"));
        expect(csp, contains("form-action 'none'"));
        expect(csp, contains("frame-ancestors 'none'"));
        expect(csp, isNot(contains('unsafe')));
        expect(csp, isNot(contains('*')));
        expect(csp, isNot(matches(RegExp(r'https?:'))));
        // No inline event handler or style attribute (blocked by this CSP).
        expect(page.html, isNot(matches(RegExp(r'\son\w+='))));
        expect(page.html, isNot(matches(RegExp(r'\sstyle='))));
        // One script, one style.
        expect('<script'.allMatches(page.html), hasLength(1));
        expect('<style'.allMatches(page.html), hasLength(1));
      }
    },
  );

  test(
    'the script posts the callback, hides the code, then closes the tab',
    () {
      final script = _between(
        OAuthReturnPage.render().html,
        '<script>',
        '</script>',
      );
      expect(script, contains("location.hash"));
      expect(script, contains("history.replaceState(null,'','/auth/done')"));
      expect(script, contains("fetch('/auth/callback'"));
      expect(script, contains('window.close()'));
      // The tab is closed only after the app accepted a successful callback.
      expect(
        script.indexOf('window.close()'),
        greaterThan(script.indexOf("d.state='done'")),
      );
      expect(script, isNot(contains('localStorage')));
      expect(script, isNot(contains('document.cookie')));
    },
  );

  test('light and dark colours come from the design tokens', () {
    final html = OAuthReturnPage.render().html;
    // Raft 0.7.1 light / dark layer-canvas and foreground-strong.
    expect(html, contains('--canvas:#ffffff'));
    expect(html, contains('--canvas:#1b1b19'));
    expect(html, contains('--ink:#141111'));
    expect(html, contains('--ink:#e5e5e2'));
  });
}
