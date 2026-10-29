import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:raft_ui/raft_ui.dart';

/// The page the browser lands on at `http://127.0.0.1:<port>/auth/done` after a
/// desktop social sign-in (see `NativeOAuthBroker`).
///
/// Self-contained: inline CSS, an inline brand mark, a small inline script and
/// no network request except the same-origin callback POST. Colours are the
/// elegant light/dark design tokens, switched by `prefers-color-scheme`; the
/// banners reuse the raft-ui `banner` recipe colours. The layout follows Web's
/// auth pages (`AuthBrandIntro`: brand icon, bold title, muted text; the
/// device-login "you can close this browser page" and the app-login
/// "Returning to the app" screens).
///
/// The page never shows a value from the URL: the `error` query parameter only
/// selects one of the fixed reasons below, and the code and state are only
/// posted back to the app.
abstract final class OAuthReturnPage {
  static const path = '/auth/done';

  /// Renders the page for [languageCode] (`zh` or anything else for English).
  /// [error] is the callback's `error` query parameter, if any: the page then
  /// starts in the failed state with that reason, with or without script.
  static ({String html, String csp}) render({
    String? languageCode,
    String? error,
  }) {
    final zh = languageCode == 'zh';
    final copy = zh ? _zh : _en;
    final reason = reasonFor(error);
    final css = _css();
    final html = StringBuffer()
      ..write('<!doctype html><html lang="${zh ? 'zh-CN' : 'en'}"><head>')
      ..write('<meta charset="utf-8">')
      ..write(
        '<meta name="viewport" content="width=device-width,initial-scale=1">',
      )
      ..write('<meta name="color-scheme" content="light dark">')
      ..write('<meta name="referrer" content="no-referrer">')
      ..write('<title>Raft</title>')
      ..write('<link rel="icon" href="${_favicon()}">')
      ..write('<style>$css</style></head>')
      ..write(
        '<body data-state="${reason == null ? 'checking' : 'failed'}" '
        'data-reason="${reason ?? 'generic'}"><main role="status" aria-live="polite">',
      )
      ..write(_brandMark())
      ..write('<section class="s-checking">')
      ..write('<h1>${_e(copy.returning)}</h1>')
      ..write(
        '<p class="wait"><span class="spin" aria-hidden="true"></span>'
        '${_e(copy.finishing)}</p></section>',
      )
      ..write('<section class="s-done"><h1>${_e(copy.returning)}</h1>')
      ..write(
        '<div class="banner ok">$_checkIcon<p>${_e(copy.complete)}</p></div>'
        '</section>',
      )
      ..write('<section class="s-failed"><h1>${_e(copy.failedTitle)}</h1>')
      ..write('<div class="banner warn">$_alertIcon<div>');
    for (final entry in copy.reasons.entries) {
      html.write(
        '<p class="reason" data-r="${entry.key}">${_e(entry.value)}</p>',
      );
    }
    html
      ..write('</div></div><p class="next">${_e(copy.tryAgain)}</p></section>')
      ..write('</main><script>$_script</script></body></html>');
    return (html: html.toString(), csp: _csp(css));
  }

  /// The fixed reason a callback `error` code stands for, or null without one.
  /// Unknown codes get the generic reason: the provider's own text is never
  /// reflected.
  static String? reasonFor(String? error) {
    if (error == null || error.isEmpty) return null;
    return switch (error) {
      'access_denied' || 'provider_cancelled' => 'cancelled',
      'expired' => 'expired',
      'request_not_pending' => 'used',
      'account_conflict' => 'conflict',
      'registration_disabled' => 'registration',
      'provider_exchange_failed' => 'provider',
      _ => 'generic',
    };
  }

  /// Every reason id the page can show, for tests.
  static List<String> get reasonIds => List.unmodifiable(_en.reasons.keys);

  static String _csp(String css) =>
      "default-src 'none'; "
      "script-src '${_hash(_script)}'; "
      "style-src '${_hash(css)}'; "
      'img-src data:; '
      "connect-src 'self'; "
      "base-uri 'none'; form-action 'none'; frame-ancestors 'none'";

  static String _hash(String text) =>
      'sha256-${base64.encode(sha256.convert(utf8.encode(text)).bytes)}';

  static String _e(String text) => const HtmlEscape().convert(text);

  /// Posts what the browser received back to the app (which checks the state),
  /// then shows the outcome. `history.replaceState` drops the code from the
  /// address bar first.
  static const _script =
      "(async()=>{const d=document.body.dataset,q=new URLSearchParams(location.search),"
      "h=new URLSearchParams(location.hash.slice(1)),"
      "data={state:h.get('state'),provider:q.get('provider'),mode:q.get('mode'),code:q.get('code'),error:q.get('error')};"
      "history.replaceState(null,'','/auth/done');"
      "const no=r=>{d.state='failed';d.reason=r;};"
      'try{const r=await fetch(\'/auth/callback\',{method:\'POST\',headers:{\'Content-Type\':\'application/json\'},body:JSON.stringify(data)});'
      "if(r.status===403)no('mismatch');else if(!r.ok)no('generic');"
      "else if(!data.error){d.state='done';try{window.close()}catch(_){}}"
      "}catch(_){no('unreachable')}})();";

  static const _checkIcon =
      '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" '
      'stroke="currentColor" stroke-width="2" stroke-linecap="round" '
      'stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/>'
      '<path d="m9 12 2 2 4-4"/></svg>';
  static const _alertIcon =
      '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" '
      'stroke="currentColor" stroke-width="2" stroke-linecap="round" '
      'stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/>'
      '<path d="M12 8v4"/><path d="M12 16h.01"/></svg>';

  /// Web's `raft-icon.svg` (`dark:invert`): the same vector data the app paints.
  static String _brandMark() {
    final svg = RaftBrandMarkKind.icon.svg;
    final paths = svg.paths.map((p) => '<path d="${p.$2}"/>').join();
    return '<svg class="brand" viewBox="0 0 ${svg.width.round()} ${svg.height.round()}" '
        'fill="currentColor" aria-hidden="true">$paths</svg>';
  }

  /// The mark on the brand yellow, as a data URI (a tab icon without a request).
  static String _favicon() {
    final svg = RaftBrandMarkKind.icon.svg;
    final paths = svg.paths.map((p) => "<path d='${p.$2}'/>").join();
    final icon =
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 320 320'>"
        "<rect width='320' height='320' rx='72' fill='#ffd441'/>"
        "<g transform='translate(36.7 46) scale(.9)' fill='#191815'>$paths</g></svg>";
    return 'data:image/svg+xml,${Uri.encodeComponent(icon)}';
  }

  static String _hex(Color c) {
    final v = c.toARGB32();
    String h(int shift) =>
        ((v >> shift) & 0xff).toRadixString(16).padLeft(2, '0');
    return '#${h(16)}${h(8)}${h(0)}';
  }

  static String _vars(bool dark) {
    final c = RaftTokens.theme(dark: dark).colors;
    String t(String name) => _hex(c[name]!);
    return '--canvas:${t('layer-canvas')};--ink:${t('foreground-strong')};'
        '--text:${t('foreground')};--muted:${t('foreground-muted')};'
        '--line:${t('line-muted')};--accent:${t('accent-strong')};'
        '--ok:${t('success')};';
  }

  static String _css() {
    final reasonRules = _en.reasons.keys
        .map((k) => 'body[data-reason=$k] .reason[data-r=$k]{display:block}')
        .join();
    return ':root{color-scheme:light dark;${_vars(false)}'
        '--warn-bg:oklch(.955 .035 50);--warn-fg:oklch(.476 .114 61.907);'
        '--ok-bg:oklch(.94 .035 153.079)}'
        '@media(prefers-color-scheme:dark){:root{${_vars(true)}'
        '--warn-bg:oklch(.5 .08 50/.18);--warn-fg:oklch(.82 .12 61.907);'
        '--ok-bg:oklch(.5 .12 153/.18)}}'
        '*{box-sizing:border-box}'
        'html,body{margin:0;min-height:100%}'
        'body{min-height:100vh;display:flex;align-items:flex-start;justify-content:center;'
        'padding:max(40px,22vh) 20px 40px;background:var(--canvas);color:var(--text);'
        'font:14px/1.5 ui-sans-serif,system-ui,-apple-system,"Segoe UI","Helvetica Neue",'
        '"PingFang SC","Hiragino Sans GB","Microsoft YaHei","Noto Sans CJK SC",sans-serif;'
        '-webkit-font-smoothing:antialiased}'
        'main{width:100%;max-width:448px;text-align:center}'
        '.brand{display:block;width:36px;height:auto;margin:0 auto 16px;color:var(--ink)}'
        'h1{margin:0;font-size:20px;line-height:28px;font-weight:700;color:var(--ink)}'
        'section{display:none}'
        'body[data-state=checking] .s-checking,body[data-state=done] .s-done,'
        'body[data-state=failed] .s-failed{display:block}'
        '.wait{display:flex;align-items:center;justify-content:center;gap:8px;'
        'margin:8px 0 0;color:var(--muted)}'
        '.spin{width:16px;height:16px;border-radius:50%;border:2px solid var(--line);'
        'border-top-color:var(--accent);animation:spin .8s linear infinite}'
        '@keyframes spin{to{transform:rotate(360deg)}}'
        '@media(prefers-reduced-motion:reduce){.spin{animation:none}}'
        '.banner{display:grid;grid-template-columns:auto minmax(0,1fr);align-items:center;'
        'gap:0 8px;margin:20px 0 0;padding:12px;border-radius:4px;text-align:left;'
        'font-size:13px;line-height:20px;letter-spacing:-.005em}'
        '.banner svg{flex:none}.banner p{margin:0}'
        '.banner.ok{background:var(--ok-bg);color:var(--text)}.banner.ok svg{color:var(--ok)}'
        '.banner.warn{background:var(--warn-bg);color:var(--warn-fg)}'
        '.next{margin:12px 0 0;color:var(--muted)}'
        '.reason{display:none}$reasonRules';
  }
}

class _Copy {
  const _Copy({
    required this.returning,
    required this.finishing,
    required this.complete,
    required this.failedTitle,
    required this.tryAgain,
    required this.reasons,
  });
  final String returning, finishing, complete, failedTitle, tryAgain;

  /// Reason id -> sentence; the key order is the page's reason order.
  final Map<String, String> reasons;
}

// English is the source. Chinese: Web zh-cn wording where Web has the string
// (pages.socialCallback.finishingSignIn / finishFailed,
// pages.deviceLogin.approvedDescription); the rest is written directly (no
// approval needed, Kevin 2026-10-13).
const _en = _Copy(
  returning: 'Returning to Raft',
  finishing: 'Finishing sign-in…',
  complete: 'Sign-in is complete. You can close this browser page.',
  failedTitle: 'Failed to finish sign-in',
  tryAgain: 'Return to Raft and try again.',
  reasons: {
    'cancelled': 'Sign-in was cancelled, or access was denied.',
    'expired': 'This sign-in request has expired.',
    'used': 'This sign-in request was already used or is no longer valid.',
    'mismatch': "This sign-in link doesn't match the request Raft started.",
    'conflict': 'An account with this email already exists.',
    'registration': 'Registration is currently disabled.',
    'provider': "The sign-in provider couldn't confirm your account.",
    'unreachable': 'Raft could not be reached. It may have been closed.',
    'generic': 'Sign-in could not be completed.',
  },
);

const _zh = _Copy(
  returning: '正在返回 Raft',
  finishing: '正在完成登录…',
  complete: '登录已完成，你可以关闭此浏览器页面。',
  failedTitle: '完成登录失败',
  tryAgain: '请返回 Raft 重试。',
  reasons: {
    'cancelled': '登录已取消，或授权被拒绝。',
    'expired': '这个登录请求已过期。',
    'used': '这个登录请求已被使用或已失效。',
    'mismatch': '这个登录链接与 Raft 发起的请求不匹配。',
    'conflict': '该邮箱对应的账户已存在。',
    'registration': '当前已关闭注册。',
    'provider': '登录提供方无法确认你的账户。',
    'unreachable': '无法连接到 Raft，它可能已被关闭。',
    'generic': '无法完成登录。',
  },
);
