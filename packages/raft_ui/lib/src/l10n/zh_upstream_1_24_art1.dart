// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-ART1 (the Artifact viewer, its frame,
// menu, versions, files, find, download, message cards, Activity rows and Save as Artifact:
// artifacts.{activity,attachment,card,chip,confirm,download,embed,facts,files,filesTab,find,frame,
// menu,page,pageError,permalink,versions,viewer,widen}.*). Keys another catalog file already
// declares with the same Chinese are not repeated here.
const Map<String, String> zhCatalogUpstream124Art1 = <String, String>{
  // artifacts.facts.bytes
  "{value} B": "{value} B",
  // artifacts.facts.kilobytes
  "{value} KB": "{value} KB",
  // artifacts.facts.megabytes
  "{value} MB": "{value} MB",
  // artifacts.facts.lines
  "{count, plural, one {# line} other {# lines}}": "{count} 行",
  // artifacts.facts.rows
  "{count, plural, one {# row} other {# rows}}": "{count, plural, other {# 行}}",
  // artifacts.facts.rowsColumns
  "{rows, plural, one {# row} other {# rows}} × {columns, plural, one {# column} other {# columns}}":
      "{rows} 行 {columns} 列",
  // artifacts.facts.columnPair
  "{list}, {name}": "{list}、{name}",
  // artifacts.facts.pixels
  "{width} × {height}": "{width} × {height}",
  // artifacts.facts.pages
  "{count, plural, one {# page} other {# pages}}": "{count} 页",
  // artifacts.card.version
  "v{version}": "v{version}",
  // artifacts.card.versionBehind
  "v{version} · latest v{latest}": "v{version} · 最新 v{latest}",
  // artifacts.filesTab.rowName
  "Artifact {title}, v{version}": "Artifact {title}，v{version}",
  // artifacts.filesTab.loading
  "Loading Artifacts…": "正在加载 Artifact…",
  // artifacts.filesTab.loadError
  "Couldn't load this conversation's Artifacts.": "无法加载此对话的 Artifact。",
  // artifacts.filesTab.showMore
  "Show more Artifacts": "显示更多 Artifact",
  // artifacts.filesTab.loadMoreError
  "Couldn't load more Artifacts.": "无法加载更多 Artifact。",
  // artifacts.card.updatedBy
  "{name} updated {time}": "{name} 更新于 {time}",
  // artifacts.card.openInNewPage
  "Open in new page": "在新页面打开",
  // artifacts.card.excerptImage
  "Image": "图片",
  // artifacts.card.excerptImageNamed
  "Image: {alt}": "图片：{alt}",
  // artifacts.card.excerptImages
  "{count, plural, one {# image} other {# images}}":
      "{count, plural, other {# 张图片}}",
  // artifacts.card.comments
  "{count, plural, one {# comment} other {# comments}}":
      "{count, plural, other {# 条评论}}",
  // artifacts.card.newComments
  "{count, plural, one {# new comment since you last looked} other {# new comments since you last looked}}":
      "{count, plural, other {上次查看后有 # 条新评论}}",
  // artifacts.card.newVersion
  "Updated": "有更新",
  // artifacts.card.newVersionLabel
  "New version since you last looked": "上次查看后有新版本",
  // artifacts.card.mentioned
  "Mentions you": "提到你",
  // artifacts.card.mentionedLabel
  "A comment mentions you": "有评论提到你",
  // artifacts.card.loading
  "Loading Artifact": "正在加载 Artifact",
  // artifacts.card.deletedBy
  "Deleted by {name} {time}": "{name} 删除于 {time}",
  // artifacts.card.deletedByName
  "Deleted by {name}": "{name} 删除",
  // artifacts.card.deletedAt
  "Deleted {time}": "删除于 {time}",
  // artifacts.activity.mentionedYou
  "{name} mentioned you": "{name} 提到了你",
  // artifacts.activity.commented
  "{name} commented": "{name} 发表了评论",
  // artifacts.activity.editedComment
  "{name} edited a comment": "{name} 编辑了评论",
  // artifacts.activity.publishedVersion
  "{name} published v{version}": "{name} 发布了 v{version}",
  // artifacts.activity.published
  "{name} published a new version": "{name} 发布了新版本",
  // artifacts.activity.updated
  "{name} updated it": "{name} 有更新",
  // artifacts.activity.reviewed
  "{name} reviewed it ({count, plural, one {# comment} other {# comments}})":
      "{name} 提交了评审（{count, plural, other {# 条评论}}）",
  // artifacts.activity.mentionedYouInReview
  "{name} mentioned you in a review ({count, plural, one {# comment} other {# comments}})":
      "{name} 在评审中提到了你（{count, plural, other {# 条评论}}）",
  // artifacts.activity.someone
  "Someone": "有人",
  // artifacts.activity.untitled
  "Untitled Artifact": "未命名的 Artifact",
  // artifacts.activity.alsoNew
  "· {news}": "· {news}",
  // artifacts.activity.images
  "{count, plural, =1 {Image} other {# images}}":
      "{count, plural, =1 {图片} other {# 张图片}}",
  // artifacts.viewer.regionLabel
  "Artifact": "Artifact",
  // artifacts.viewer.expand
  "Expand": "展开",
  // artifacts.viewer.restore
  "Restore": "恢复",
  // artifacts.viewer.resizeSplit
  "Resize the Artifact and the cards below": "调整 Artifact 和下方卡片的大小",
  // artifacts.viewer.origin
  "{kind, select, dm {From a message with {name}} other {From a message in {name}}}":
      "{kind, select, dm {来自和 {name} 的私信里的一条消息} other {来自 {name} 里的一条消息}}",
  // artifacts.viewer.gettingPage
  "Getting the page": "正在获取页面",
  // artifacts.viewer.startingPage
  "Starting the page": "正在启动页面",
  // artifacts.viewer.unavailableTitle
  "Can't open this Artifact": "打不开这个 Artifact",
  // artifacts.viewer.unavailableBody
  "It doesn't exist, or you don't have access to it.": "它不存在，或者你没有权限查看。",
  // artifacts.permalink.failedTitle
  "Couldn't open this link": "打不开这个链接",
  // artifacts.permalink.unavailableBody
  "If someone shared it with you, ask them for access.": "如果是别人分享给你的，请向对方申请权限。",
  // artifacts.permalink.switchAccount
  "Switch account": "切换账号",
  // artifacts.permalink.signInPrompt
  "Sign in to open this Artifact": "登录后打开这个 Artifact",
  // artifacts.page.hostDesktopMode
  "Desktop mode": "桌面模式",
  // artifacts.page.openIn
  "Open in {place}": "在 {place} 中打开",
  // artifacts.menu.linkCopied
  "Link copied.": "链接已复制。",
  // artifacts.menu.embedCopied
  "Embed code copied.": "嵌入代码已复制。",
  // artifacts.viewer.noPreview
  "This file can't be previewed here yet.": "这里还不能预览这个文件。",
  // artifacts.frame.openInNewTab
  "Open in new tab": "在新标签页中打开",
  // artifacts.frame.needsTabTitle
  "Open this Artifact in a new tab": "请在新标签页中打开这个 Artifact",
  // artifacts.frame.needsTabBody
  "Your browser won't show it inside this page.": "你的浏览器无法在此页面内显示它。",
  // artifacts.frame.deniedTitle
  "You can't open this anymore": "你已无法再打开它",
  // artifacts.frame.deniedBody
  "You no longer have access to it.": "你已没有访问权限。",
  // artifacts.frame.expiredTitle
  "This view has expired": "此视图已过期",
  // artifacts.frame.failedTitle
  "This Artifact didn't load": "这个 Artifact 没有加载出来",
  // artifacts.frame.versionGoneTitle
  "This version isn't available": "这个版本不可用",
  // artifacts.frame.contentUnavailableTitle
  "The preview isn't available right now": "预览暂时不可用",
  // artifacts.frame.rateLimitedTitle
  "Too many Artifacts opened at once": "同时打开的 Artifact 太多",
  // artifacts.frame.tryLater
  "Try again later.": "请稍后再试。",
  // artifacts.frame.copyFailed
  "Couldn't copy": "复制失败",
  // artifacts.confirm.source
  "From “{title}”": "来自「{title}」",
  // artifacts.confirm.partial
  "Only part of it is shown.": "这里只显示了其中一部分。",
  // artifacts.confirm.allow
  "Allow": "允许",
  // artifacts.confirm.allowThis
  "Allow this?": "允许这样做吗？",
  // artifacts.confirm.sendPrompt.title
  "Send this message?": "发送这条消息？",
  // artifacts.confirm.openLink.title
  "Open this link?": "打开这个链接？",
  // artifacts.confirm.downloadFile.title
  "Download this file?": "下载这个文件？",
  // artifacts.confirm.callTool.title
  "Run this tool?": "运行这个工具？",
  // artifacts.confirm.callTool.accept
  "Run": "运行",
  // artifacts.confirm.setModelContext.title
  "Share this with the agent?": "把这些分享给智能体？",
  // artifacts.confirm.readData.title
  "Let it read this?": "允许它读取这些内容？",
  // artifacts.confirm.subscribeData.title
  "Let it follow this?": "允许它持续获取这些内容？",
  // artifacts.confirm.copyText.title
  "Copy this text?": "复制这段文本？",
  // artifacts.confirm.publish.title
  "Publish a new version of this page?": "发布这个页面的新版本？",
  // artifacts.confirm.publish.accept
  "Publish": "发布",
  // artifacts.confirm.publish.base
  "From version {base}.": "基于版本 {base}。",
  // artifacts.confirm.publish.baseLabel
  "From version {base}: {label}.": "基于版本 {base}：{label}。",
  // artifacts.confirm.publish.removed
  "{path}: removed": "{path}：已移除",
  // artifacts.confirm.publish.characters
  "{path}: {count, plural, one {# character} other {# characters}}":
      "{path}：{count, plural, other {# 个字符}}",
  // artifacts.confirm.publish.bytes
  "{path}: {count, plural, one {# byte} other {# bytes}}":
      "{path}：{count, plural, other {# 字节}}",
  // artifacts.confirm.assetUpload.title
  "Add this file to the page's library?": "把这个文件加入页面的文件库？",
  // artifacts.confirm.assetUpload.detail
  "{name} ({type}, {size, plural, one {# byte} other {# bytes}})":
      "{name}（{type}，{size, plural, other {# 字节}}）",
  // artifacts.confirm.assetUpload.audience
  "Everyone who can see the page can load it.": "能看到这个页面的人都能加载它。",
  // artifacts.confirm.assetDelete.title
  "Remove this file from the page's library?": "从页面的文件库中移除这个文件？",
  // artifacts.confirm.db.title
  "Change this page's shared data?": "修改这个页面的共享数据？",
  // artifacts.confirm.db.kind
  "{op, select, set {set} update {update} delete {delete} other {{op}}} {paths}{more, plural, =0 {} other { and # more}}": "{op, select, set {设置} update {更新} delete {删除} other {{op}}} {paths}{more, plural, =0 {} other {，另有 # 项}}",
  // artifacts.confirm.db.kindSeparator
  "; ": "；",
  // artifacts.confirm.db.summary
  "{kinds}{others, plural, =0 {} one {; and # other write} other {; and # other writes}}.":
      "{kinds}{others, plural, =0 {} other {；另有 # 项其他写入}}。",
  // artifacts.find.open
  "Find in page": "页面内查找",
  // artifacts.find.previous
  "Previous match": "上一个匹配",
  // artifacts.find.next
  "Next match": "下一个匹配",
  // artifacts.find.close
  "Close find": "关闭查找",
  // artifacts.find.clear
  "Clear search": "清除搜索",
  // artifacts.find.count
  "{active}/{total}": "{active}/{total}",
  // artifacts.find.countCapped
  "{active}/{total}+": "{active}/{total}+",
  // artifacts.pageError.title
  "This page hit an error": "页面出错了",
  // artifacts.pageError.fix
  "Let the agent fix it": "让 Agent 修",
  // artifacts.pageError.commentBody
  "The page reported an error in v{version} (viewer {width}px wide):\n{message}":
      "页面在 v{version} 报错（查看器宽 {width}px）：\n{message}",
  // artifacts.pageError.commentMore
  "(+{count} more)": "（另有 {count} 条）",
  // artifacts.menu.embed
  "Copy embed code": "复制嵌入代码",
  // artifacts.menu.sendToConversation
  "Send to conversation": "发到对话",
  // artifacts.menu.visibility
  "Who can see": "谁能看",
  // artifacts.menu.versionHistory
  "Version history": "版本历史",
  // artifacts.versions.latest
  "Latest": "最新",
  // artifacts.versions.published
  "{name} · {time}": "{name} · {time}",
  // artifacts.versions.viewing
  "Viewing v{version}": "正在查看 v{version}",
  // artifacts.versions.backToLatest
  "Back to latest": "回到最新",
  // artifacts.versions.failed
  "Couldn't load v{version}. Still showing the version before it.":
      "无法加载 v{version}，仍显示之前的版本。",
  // artifacts.versions.latestFailed
  "Couldn't load the latest version. Still showing the version before it.":
      "无法加载最新版本，仍显示之前的版本。",
  // artifacts.versions.newerAvailable
  "v{version} is available": "v{version} 已发布",
  // artifacts.versions.newerPublishedNote
  "{name} published v{version}: {note}": "{name} 发布了 v{version}：{note}",
  // artifacts.versions.newerAvailableNote
  "v{version} is available: {note}": "v{version} 已发布：{note}",
  // artifacts.versions.changedFiles
  "Changed: {files}": "改动：{files}",
  // artifacts.versions.changedFilesMore
  "Changed: {files}, +{count} more": "改动：{files}，另有 {count} 个",
  // artifacts.versions.viewLatest
  "View latest": "查看最新",
  // artifacts.versions.switchLabel
  "v{version}, switch version": "v{version}，切换版本",
  // artifacts.menu.downloadAll
  "Download all": "下载全部",
  // artifacts.files.close
  "Close files": "关闭文件",
  // artifacts.files.summary
  "{count, plural, one {# file} other {# files}} · {size}":
      "{count} 个文件 · {size}",
  // artifacts.files.entry
  "Entry": "入口",
  // artifacts.files.download
  "Download {name}": "下载 {name}",
  // artifacts.download.zipTooLarge
  "These files are too large to download as one zip. Download them one by one from Files.":
      "这些文件太大，无法打包成一个 zip 下载。请在「文件」里逐个下载。",
  // artifacts.download.zipBusy
  "Too many downloads are being prepared right now. Wait a few seconds, then try again.":
      "现在正在准备的下载太多。请等几秒后再试。",
  // artifacts.download.zipFailed
  "Couldn't download the files. Try again.": "没能下载这些文件。请再试一次。",
  // artifacts.download.fileFailed
  "Couldn't download the file. Try again.": "没能下载这个文件。请再试一次。",
  // artifacts.menu.rename
  "Rename": "重命名",
  // artifacts.menu.delete
  "Delete Artifact": "删除 Artifact",
  // artifacts.menu.displayReport
  "Doesn't display well here": "在这里显示不正常",
  // artifacts.embed.publicBody
  "Anyone with the link can view it, and it won't show up in search engines. The embed code is copied once link sharing is on.":
      "知道链接的任何人都能查看，搜索引擎不会收录。开启链接分享后会复制嵌入代码。",
  // artifacts.widen.publicTitle
  "Turn on link sharing?": "开启链接分享？",
  // artifacts.widen.publicConfirm
  "Turn on link sharing": "开启链接分享",
  // artifacts.attachment.more
  "More actions for {filename}": "{filename} 的更多操作",
  // artifacts.attachment.save
  "Save as Artifact": "存为 Artifact",
  // artifacts.attachment.savedAs
  "Saved as Artifact": "已存为 Artifact",
  // artifacts.attachment.savedAsUnavailableNamed
  "{filename} saved as Artifact": "{filename} 已存为 Artifact",
  // artifacts.attachment.savedToast
  "Saved as Artifact “{title}”": "已存为 Artifact「{title}」",
  // artifacts.attachment.existingToast
  "Already saved as Artifact “{title}”": "已经存为 Artifact「{title}」",
  // artifacts.attachment.alreadySavedHidden
  "This attachment is already saved as an Artifact you can't see.":
      "这个附件已经存为一个你看不到的 Artifact。",
  // artifacts.attachment.uploading
  "Wait for the upload to finish, then save it.": "等上传完成后再存。",
  // artifacts.attachment.tooLarge
  "This file is too large to save as an Artifact.": "这个文件太大，不能存为 Artifact。",
  // artifacts.attachment.notFound
  "This attachment isn't available any more.": "这个附件已经不在了。",
  // artifacts.attachment.saveFailed
  "Couldn't save it as an Artifact.": "没能存为 Artifact。",
  // artifacts.attachment.saving
  "Saving as Artifact…": "正在存为 Artifact…",
  // artifacts.attachment.savingNamed
  "Saving {filename} as Artifact…": "正在把 {filename} 存为 Artifact…",
  // artifacts.attachment.failedNamed
  "{filename}: {reason}": "{filename}：{reason}",
  // Borrowed from the ART2/ART3 buckets because the cards and the viewer show
  // them now (artifacts.actor.*, artifacts.scope.*); ART2/ART3 reuse these keys.
  // artifacts.actor.deletedAgent
  "Deleted agent": "已删除的 Agent",
  // artifacts.actor.deletedUser
  "Deleted user": "已删除的用户",
  // artifacts.scope.publicFromAnotherServer
  "From another server": "来自其他服务器",
  // artifacts.scope.public
  "Anyone with the link": "知道链接的任何人",
  // artifacts.scope.server (named: no)
  "Everyone in this server": "这个服务器里的所有人",
  // artifacts.scope.server (named: yes)
  "Everyone in {server}": "{server} 的所有人",
  // artifacts.dashboard.newComments (the card's sticker; ART3 shares it)
  "{count, plural, one {# new comment} other {# new comments}}": "{count} 条新评论",
};
