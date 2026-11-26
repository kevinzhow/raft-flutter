/// Web `message.inlineThreadReplies.replyCount` (en.ts:3583, zh-cn.ts:3491).
///
/// The English is an ICU plural, not a pair of singular/plural strings, so a
/// language with more than two forms can state them: Russian needs one, few
/// and many (1 ответ, 2 ответа, 5 ответов). Chinese has one form, which is why
/// its translation carries `{count}` and no plural arms.
const Map<String, String> zhCatalogThreadReplyCount = {
  '{count, plural, one {# reply} other {# replies}}': '{count} 条回复',
};
