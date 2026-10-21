// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
const Map<String, String> zhCatalogNativeOnly = <String, String>{
  "Open Raft": "打开 Raft",
  "Hide window": "隐藏窗口",
  "Quit Raft": "退出 Raft",
  "Keep Raft running when the window closes": "关闭窗口后保持 Raft 运行",
  "Closing the window keeps messages and notifications connected. Open Raft or quit completely from its system tray icon.":
      "关闭窗口后仍保持消息和通知连接。可通过系统托盘图标打开或完全退出 Raft。",
  "The system tray preference is unavailable. Close will exit Raft if its tray icon cannot be created.":
      "无法读取或保存系统托盘设置。若无法创建托盘图标，关闭窗口将退出 Raft。",
  // Native-only copy with no Web counterpart (Web glossary terms).
  // Android notification settings: no periodic background check any more.
  // PROPOSED wording, to be confirmed by the owner.
  "While Raft is connected, new DMs, direct mentions and replies in followed threads show a system notification.":
      "Raft 连接时，会对新私信、直接提及和已关注消息串的回复弹出系统通知。",
  "To receive notifications in the background, turn off battery optimization for Raft.":
      "要在后台接收通知，请为 Raft 关闭电池优化。",
  "Open battery settings": "打开电池设置",
  "Close profile": "关闭资料",
  "Profile could not be loaded.": "无法加载资料。",
  "Create direct message": "创建私信",
  "Mention action failed. Try again.": "提及操作失败，请重试。",
  "Channel name is required.": "请填写频道名称。",
  "Activity filters": "动态筛选",
  "Conversion complete. Invite another workspace from Joint channels.":
      "转换完成。可在联合频道中邀请其他工作空间。",
  "Conversion canceled. The original channel is available.": "转换已取消，原频道仍可使用。",
  "Download original": "下载原文件",
  "Preview unavailable. Download the original file.": "无法预览，请下载原文件。",
  "Channel is no longer available": "该频道已不可用",
  "Reconnecting": "正在重新连接",
  "Jump to beginning": "跳转到开头",
  "Thread options": "消息列选项",
  "Following thread": "已关注消息列",
  "Thread notifications off": "消息列通知已关闭",
  "Loading thread settings…": "正在加载消息列设置…",
  "Joint channel conversion": "联合频道转换",
  "Show direct message": "显示私信",
  "Hide direct message": "隐藏私信",
  "Enter one unique KEY=value per line.": "每行输入一个唯一的 KEY=value。",
  "Pending requests": "待处理请求",
  "Sign-in methods could not be verified. Refresh before changing them.":
      "无法验证登录方式。请刷新后再更改。",
  "Password sign-in is configured.": "已配置密码登录。",
  "Password sign-in is not configured.": "未配置密码登录。",
  "Upload progress for {name}": "{name} 的上传进度",
  "Invite method": "邀请方式",
  "Describe what this agent does": "描述此 Agent 的用途",
  "No reminders": "暂无提醒",
  "Hidden files": "隐藏文件",
  "Preview truncated. Download the full file.": "预览已截断，请下载完整文件。",
  "First {count} rows": "前 {count} 行",
  "Pause": "暂停",
  "Play": "播放",
  "Volume": "音量",
  // Native app-update check (the Web client updates itself).
  "New version available: {version} ({build})": "有新版本：{version}（{build}）",
  // Settings > About > Updates card (Kevin approved 2026-10-13).
  "You're on the latest version": "已是最新版本",
  "Last checked: {time}": "上次检查：{time}",
  "Checking for updates…": "正在检查更新…",
  "Check for updates": "检查更新",
  "Couldn't check for updates": "无法检查更新",
  "Not checked for updates yet": "尚未检查更新",
  "Update checks aren't available for this build": "此版本不支持检查更新",
  "iOS builds aren't distributed through GitHub releases.":
      "iOS 版本不通过 GitHub 发布分发。",
  "Only the AppImage build can check for updates.": "只有 AppImage 版本可以检查更新。",
  "This is a development build without a CI build number.": "这是没有 CI 构建号的开发版本。",
  "This platform isn't updated from GitHub releases.": "此平台不通过 GitHub 发布更新。",
  "Download update": "下载更新",
  "Update now": "立即更新",
  "View release": "查看发布",
  // Error and status copy with no Web counterpart (zh approved by the owner).
  "Join a channel before creating a task.": "创建任务前请先加入一个频道。",
  "Refresh Activity before marking this conversation done.": "请先刷新动态，再将此会话标为完成。",
  "Could not remove the raft:// registration.": "无法移除 raft:// 注册。",
  "xdg-utils is not installed, so raft:// links cannot be set up.": "未安装 xdg-utils，无法设置 raft:// 链接。",
  "The default handler for raft:// links could not be read.": "无法读取 raft:// 链接的默认处理程序。",
  "The desktop did not accept Raft as the raft:// handler.": "桌面环境未接受 Raft 作为 raft:// 处理程序。",
  "The desktop kept another handler for raft:// links.": "桌面环境保留了另一个 raft:// 链接处理程序。",
  "Saved {name}": "已保存 {name}",
  "Download failed. Try again.": "下载失败，请重试。",
  "No application can open this file.": "没有可打开此文件的应用。",
  "Revoked workspace data could not be removed from this device.": "已撤销的工作区数据无法从此设备移除。",
  "Select encrypted headers to save a header credential.": "请选择加密请求头后再保存请求头凭据。",
  "Select encrypted headers to test a credential.": "请选择加密请求头后再测试凭据。",
  "Requested. Applies when the computer reconnects.": "已请求。计算机重新连接后生效。",
  "Request accepted. Check runtime status for completion.": "请求已接受。请查看运行时状态确认是否完成。",
  "Enter the server origin, such as https://raft.example.com.": "请输入服务器地址，例如 https://raft.example.com。",
  "Your session has expired. Sign in again.": "登录已过期，请重新登录。",
  "Server membership changed. Choose an available server again.": "服务器成员身份已变更，请重新选择可用的服务器。",
  "Enter your current password.": "请输入当前密码。",
  "Allow nearby devices access in system settings to connect to this local server.": "请在系统设置中允许访问附近设备，以连接此本地服务器。",
  "Your saved sign-in is not available yet": "已保存的登录暂不可用",
  "Cannot reach Raft right now": "暂时无法连接 Raft",
  "Raft could not confirm your session": "Raft 无法确认你的会话",
  "Your device could not open the secure storage that holds your sign-in. It is still saved. This usually clears after the device is unlocked.": "设备无法打开保存登录信息的安全存储。登录信息仍已保存，通常在设备解锁后即可恢复。",
  "You are still signed in. Raft will keep trying to reconnect.": "你仍处于登录状态，Raft 会持续尝试重新连接。",
  "You are still signed in. Raft will keep trying to confirm your session.": "你仍处于登录状态，Raft 会持续尝试确认你的会话。",
  "Notification settings could not be loaded on this device.": "无法在此设备上加载通知设置。",
  "System notification permission could not be checked.": "无法检查系统通知权限。",
  "Notification settings could not be saved on this device.": "无法在此设备上保存通知设置。",
  // Failed audio / video: the real cause and what to do (Kevin approved 2026-10-13).
  "Cannot reach the proxy {proxy}. Check Network settings, then try again.":
      "无法连接代理 {proxy}。请检查网络设置后重试。",
  "The proxy {proxy} needs a username and password. Check Network settings.":
      "代理 {proxy} 需要用户名和密码。请检查网络设置。",
  "Cannot reach the server. Check your connection and try again.":
      "无法连接服务器。请检查网络连接后重试。",
  "This link has expired or access was denied. Try again.": "此链接已过期或无权访问。请重试。",
  "This file is no longer available.": "此文件已不可用。",
  "This audio may use a codec this app cannot play.": "此音频使用的编解码器可能无法在本应用中播放。",
  "The media could not be played.": "无法播放该媒体。",
  "Network settings": "网络设置",
  // Documents the server would not preview: read the original or hand it to the system app (Kevin approved 2026-10-13).
  "Open with system app": "用系统应用打开",
  "Open full file": "打开完整文件",
  "This file is too large to open here. Download it instead.": "文件太大，无法在此打开，请下载后查看。",
  "The file could not be downloaded. Try again.": "文件下载失败，请重试。",
  // Image viewer on phones (native-only: Web has no photo-library save; its
  // "Save image" is a different action). Wording follows the iOS / Android
  // names of the system photo library.
  "Save to Photos": "保存到“照片”",
  "Save to Gallery": "保存到相册",
  "Saved to Photos.": "已保存到“照片”。",
  "Saved to Gallery.": "已保存到相册。",
  "The image could not be saved.": "无法保存图片。",
  // Settings > Resources > Storage (native-only cache of attachments, previews, profile pictures and icons; Web leaves
  // caching to the browser).
  "Storage": "存储",
  "Cache": "缓存",
  "Attachments, previews, profile pictures and icons you open are kept on this device so they open again without downloading. Your sign-in, drafts, settings and files you saved are not part of the cache.":
      "你打开过的附件、预览、头像和图标会保存在此设备上，再次打开时无需重新下载。登录信息、草稿、设置和你保存的文件不属于缓存。",
  "Clear cache": "清除缓存",
  "Downloaded attachments and previews, profile pictures and icons, and temporary preview files are removed from this device. They are downloaded again the next time you open them. Files that are open right now are kept, and so are your sign-in, drafts, settings, files you saved and files shared to Raft.":
      "将从此设备移除已下载的附件和预览、头像和图标，以及临时预览文件，下次打开时会重新下载。正在打开的文件会保留，登录信息、草稿、设置、你保存的文件和分享给 Raft 的文件也不受影响。",
  "Attachments and previews": "附件和预览",
  "Profile pictures and icons": "头像和图标",
  "Some of the cache could not be cleared. Try again.": "部分缓存未能清除，请重试。",
  "Clearing…": "正在清除…",
  "Cache cleared.": "缓存已清除。",
  "Calculating…": "正在计算…",
  "Cache size: {size}": "缓存大小：{size}",
  "Cache limit": "缓存上限",
  // Settings > Resources > Storage > Video cache (videos kept per account; cleared on sign-out).
  "Video cache": "视频缓存",
  "Videos you watch are kept on this device so they play again without downloading. They are removed when you sign out.":
      "看过的视频会保存在此设备上，再次播放无需重新下载。退出登录时会一并删除。",
  "Video cache: {size}": "视频缓存：{size}",
  "Video cache cleared.": "视频缓存已清除。",
  "Some of the video cache could not be cleared. Try again.": "部分视频缓存未能清除，请重试。",
  "The most space the cache may use on this device. When it is full, the attachments and previews you opened longest ago are removed first. Profile pictures and icons keep their own small limit.":
      "缓存最多可占用此设备的空间。占满后，会先移除最久没打开过的附件和预览。头像和图标有各自的小额上限，不受此项影响。",
  // Channel settings: a stale mounted action is refused (Web has no copy).
  "Channel editing is no longer available.": "该频道已无法编辑。",
  "Channel activity preference is no longer available.": "该频道的动态偏好已不可用。",
  // Settings > About > Updates card, Linux AppImage in-place update (native-only;
  // Web has no counterpart). Each failure sentence names its cause and the next step.
  "Updating to {version} ({build})": "正在更新到 {version}（{build}）",
  "Comparing with your current version…": "正在与当前版本比对…",
  "Downloading the changes… {percent}%": "正在下载变更… {percent}%",
  "Verifying the update…": "正在校验更新…",
  "Installing the update…": "正在安装更新…",
  "Raft {version} ({build}) is installed": "Raft {version}（{build}）已安装",
  "Restart Raft to finish updating.": "重启 Raft 以完成更新。",
  "Raft couldn't restart itself. Quit it and start it again to finish updating.":
      "Raft 无法自动重启，请退出后重新打开以完成更新。",
  "Restart to finish": "重启以完成更新",
  "Couldn't install the update": "更新安装失败",
  "Couldn't reach {host}. Check your connection and try again.":
      "无法连接 {host}，请检查网络后重试。",
  "The update server answered with an unexpected status ({status}). Try again later or download the update from the release page.":
      "更新服务器返回了异常状态（{status}），请稍后重试或从发布页下载。",
  "This release has no update file for in-place updates. Download the new AppImage from the release page.":
      "此版本不支持原地更新，请从发布页下载新的 AppImage。",
  "The update files don't match this release. Download the new AppImage from the release page.":
      "更新文件与此版本不匹配，请从发布页下载新的 AppImage。",
  "The server doesn't support partial downloads. Download the new AppImage from the release page.":
      "服务器不支持分段下载，请从发布页下载新的 AppImage。",
  "There is not enough free space in {folder} for the update.":
      "{folder} 的剩余空间不足，无法更新。",
  "Raft can't write to {folder}. Move the AppImage to a folder you own, or download the update from the release page.":
      "Raft 无法写入 {folder}。请把 AppImage 移到你有权限的文件夹，或从发布页下载更新。",
  "This release has no checksum to verify the update against. Download it from the release page.":
      "此版本缺少校验信息，请从发布页下载。",
  "The downloaded update failed its integrity check and was discarded. Your current version is unchanged. Try again or download the update from the release page.":
      "下载的更新未通过完整性校验，已丢弃，当前版本未改动。请重试或从发布页下载。",
  "The new version couldn't be moved into place. Your current version is unchanged. Download the update from the release page.":
      "新版本替换失败，当前版本未改动。请从发布页下载更新。",
  "The update was cancelled. Your current version is unchanged.":
      "已取消更新，当前版本未改动。",
  "The update stopped unexpectedly. Your current version is unchanged. Download the update from the release page.":
      "更新意外中断，当前版本未改动。请从发布页下载更新。",
};
