# 消息转发

来源：raft-source 26f77ef，server/src/routes/messages.ts 的已挂载 `/messages/forward/targets/search`、`/messages/forward`。转发已常驻启用，不依赖旧 enabled 试验开关。这里不把系统分享链接当作消息转发。

客户端支持最多 20 条原始普通聊天消息，最多 10 个目标。目标由服务端搜索返回；未加入的频道及尚不存在的 DM 需要用户分别点击加入或创建，随后重新读取实际可转发目标。最终提交包含完整原消息 ID、目标列表、备注与 UUID requestId。

第一次提交后固定整个请求，网络错误与部分失败都重试同一请求。每个目标单独显示实际 success/failed/unknown；缺少、不匹配、重复或没有 message.id 的回执不算成功。已确认的成功不会因后续缺席回执变成失败，也不会在重试时更换请求 ID。账户、工作区、角色与频道权限变化会清除选择并移除所属弹窗，保留的按钮回调也不能提交到新权限范围。

验证：forward_messages_test.dart 的 5 个测试通过，覆盖部分成功、精确重试、未知回执、已确认成功以及同 generation 角色撤权。原生 helper forward_flow.dart 使用本轮新建频道，实际转发至两个目标后读取服务端消息，断言每个目标只有一个 forwarded-bundle，原文保持中日文内容，再清理自己创建的频道。该原生流程尚在整套验证中，不能仅据 helper 存在宣称通过。

服务器投影决定转发内容与来源是否可见；客户端不以原始附件签名地址或私有来源 ID 构造可点击链接。转发块展示与 SDK Preview 的结果由独立消息展示证据记录。
