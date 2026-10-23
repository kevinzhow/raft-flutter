// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.21.23-source.1 zh-cn.ts wording: direct attachment upload (composer unfinished-uploads banner, direct PUT failure).
// The ICU plural of recoverableUploadsTitle is split into its one/other English forms (raftText does not interpret ICU).
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
};
