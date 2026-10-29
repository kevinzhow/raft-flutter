// Chinese (zh) strings, see the catalog header in ../localization.dart.
// Settings > Resources > Network (native-only page: system / manual HTTP proxy).
const Map<String, String> zhCatalogNetworkProxy = <String, String>{
  'Network': '网络',
  'Proxy': '代理',
  'Choose how Raft reaches the network. Only HTTP proxies are supported.':
      '选择 Raft 如何连接网络。仅支持 HTTP 代理。',
  'Use System Proxy': '自动检测',
  'Manual Setup': '手动配置',
  'No Proxy': '不使用代理',
  'HTTP proxy host': 'HTTP 代理主机',
  'Port': '端口',
  'Username (optional)': '用户名（可选）',
  'Password (optional)': '密码（可选）',
  'Saved. Leave blank to keep it.': '已保存。留空则保持不变。',
  'No-proxy list': '不使用代理的地址',
  "Addresses on this device are never sent through the proxy. The password is stored in the secure storage of this device and sent only to the proxy.":
      "本机地址不会经过代理。密码保存在此设备的安全存储中，只会发送给代理服务器。",
  'Current status': '当前状态',
  'Saved.': '已保存。',
  'Enter the proxy host.': '请输入代理主机。',
  'The proxy host is not valid.': '代理主机无效。',
  'Enter a port between 1 and 65535.': '请输入 1 到 65535 之间的端口。',
  'The username cannot contain a colon.': '用户名不能包含冒号。',
  'The username and password cannot contain a semicolon.': '用户名和密码不能包含分号。',
  'The username and password cannot start or end with a space.':
      '用户名和密码开头或结尾不能有空格。',
  'Enter a password, or clear the username to use no credentials.':
      '请输入密码，或清空用户名以不使用登录信息。',
  'The proxy could not be saved.': '未能保存代理设置。',
  'No proxy: connecting directly.': '不使用代理，直接连接。',
  'The manual proxy is incomplete: connecting directly.': '手动代理信息不完整，已直连。',
  'Manual HTTP proxy {proxy}.': '手动 HTTP 代理 {proxy}。',
  'Manual HTTP proxy {proxy} (with sign-in).': '手动 HTTP 代理 {proxy}（需要登录）。',
  'The system uses a SOCKS proxy, which is not supported: connecting directly. Only HTTP proxies are supported.':
      '系统使用 SOCKS 代理，暂不支持，已直连。仅支持 HTTP 代理。',
  'The system uses an automatic proxy script that this device cannot run: connecting directly.':
      '系统使用了自动代理脚本，此设备无法运行，已直连。',
  'Proxy from the environment: {proxy}.': '环境变量中的代理：{proxy}。',
  'System proxy script: {proxy}.': '系统代理脚本：{proxy}。',
  'System proxy script: this address is reached directly.': '系统代理脚本：此地址直接连接。',
  'System HTTP proxy {proxy}.': '系统 HTTP 代理 {proxy}。',
  'The system has no proxy: connecting directly.': '系统未设置代理，直接连接。',
  'Connected to {host} (HTTP {code}).': '已连接到 {host}（HTTP {code}）。',
  'The proxy rejected the username or password.': '代理拒绝了用户名或密码。',
  'The connection timed out.': '连接超时。',
  'Could not connect through this proxy.': '无法通过此代理连接。',
};
