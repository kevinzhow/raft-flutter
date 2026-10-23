// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.21.23-source.1 zh-cn.ts wording: direct attachment upload (composer unfinished-uploads banner, direct PUT failure).
// The ICU plurals of recoverableUploadsTitle, diffStats and documentSummaryFirst/Preview are split into its one/other English forms (raftText does not interpret ICU).
// The banner description says "app"/"window" where Web says "browser"/"tab" (this is not a browser); the zh follows the same sentence.
const Map<String, String> zhCatalogW23Files = <String, String>{
  // message.composer.recoverableUploadsTitle (one)
  "One unfinished upload": "1 个未完成上传",
  // message.composer.recoverableUploadsTitle (other)
  "{count} unfinished uploads": "{count} 个未完成上传",
  // message.composer.recoverableUploadsDescription (browser -> app, tab -> window)
  "This app no longer has the original file, so it cannot safely continue the upload. Cancel it here, or let the original window finish uploading.":
      "当前应用已没有原始文件，无法安全地继续上传。你可以在这里取消，或回到原来的窗口等待上传完成。",
  // message.composer.cancelRecoveredUploadLabel
  "Cancel unfinished upload {file}": "取消未完成上传 {file}",
  // message.composer.uploadError.putFailed
  "Direct object upload failed with HTTP {status}.": "直传对象失败，HTTP {status}。",
  // message.messageItem.diffStats: "{count} file(s)" already in zh_share_forward.dart
  // message.messageItem.diffStats (hunkCount)
  "{count} hunk": "{count} 个差异块",
  "{count} hunks": "{count} 个差异块",
  // message.messageItem.documentSummaryFirst (rowCount; "First {count} rows" already in zh_native_only.dart)
  "First {count} row": "前 {count} 行",
  // message.messageItem.documentSummaryPreview (rowCount)
  "Preview {count} row": "预览 {count} 行",
  "Preview {count} rows": "预览 {count} 行",
  // documentSummaryFirst / documentSummaryPreview (columnCount)
  "{count} column": "{count} 列",
  "{count} columns": "{count} 列",
  // message.attachment.rePrefix
  "re: {name}": "回复：{name}",
  // message.attachmentComment.jumpTitle
  "Jump to the message with {detail}": "跳转到含有 {detail} 的消息",
  // message.attachmentComment.commentTitle
  "Comment on {detail}": "针对 {detail} 的评论",
  // message.messageItem.addTimestamp
  "Add timestamp {timestamp}": "添加时间戳 {timestamp}",
  // message.messageItem.attachTimestamp
  "Attach timestamp {timestamp}": "附加时间戳 {timestamp}",
};
