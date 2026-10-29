// Error-presentation parity sweep, fleet area (agents, computers, runtime
// config, integrations, providers). English key -> Web zh-cn wording, verbatim
// (packages/web/src/i18n/messages/zh-cn.ts). Entries whose Web message is an
// ICU plural / select expand to the single branch the Flutter call site uses;
// the Chinese text is the Web string for that branch.
const Map<String, String> zhCatalogErrorsFleet = {
  // avatar.tooLarge
  "Avatar image must be {maxLabel} or smaller": "头像图片不能超过 {maxLabel}",
  // machine.detail.bulkActionFailed (`total` plural: one / other)
  "{failed} of {total} agent action failed. Try again or open an agent for details.":
      "{failed}/{total} 个 Agent 操作失败。请重试，或打开对应 Agent 查看详情。",
  "{failed} of {total} agent actions failed. Try again or open an agent for details.":
      "{failed}/{total} 个 Agent 操作失败。请重试，或打开对应 Agent 查看详情。",
  // migration.error.bundleTooLarge, `items` absent (select `none` arm)
  "The workspace is too large to move. Ask the agent to delete large files it no longer needs, or to list them in .raftmigrateignore, then try again.":
      "工作区太大，无法迁移。请让 Agent 删除不再需要的大文件，或把它们写进 .raftmigrateignore，然后重试。",
};
