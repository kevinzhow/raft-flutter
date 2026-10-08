# 本地 Web/Flutter 对照环境

用户授权在本机建立隔离 Raft 测试服务；只使用本地 fixture，不连接生产账户或迁移生产数据库。服务端源版本在 source-reference.json。

沿用官方 `raftdev start <独立环境名>` 与 `raftdev stop <同名环境>`。关闭默认 public preview tunnel，使用命名端口/容器隔离。开发工具会打印 fixture 登录资料；保存到忽略目录，报告不包含密码或 token。

当前环境检查：Docker 29.5.3 可用；PATH 默认 Node 22.22.3、pnpm 10.28.2，不满足参照仓库 pin Node 24.21.0、pnpm 10.29.3。应以任务目录工具链启动，不替换本机全局版本。

验收用固定 fixture 两个人类、多个 Agent、公开/私有频道、线程、任务、附件、撤权/掉线及未读状态。Web 与 Flutter 登录不同测试会话，共同读取同一套服务器数据。已安装命令、启动/停止资源、端口、健康检查与浏览器验证在实际运行后记录；检查前置条件不等于已启动成功。

## 当前已运行环境（2026-10-07）

源码工作目录：`/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source`。独立环境名 `cody-flutter`。

- Web: http://localhost:15213/
- API: http://localhost:13041；`GET /health` HTTP 200。
- PostgreSQL: localhost:15472；Redis: localhost:16419；RustFS: localhost:19040。
- 可用 `tool/raft-stack status`、`tool/raft-stack ports`；停止用 `tool/raft-stack stop`；重新启动用 `tool/raft-stack start`。
- 本机具体路径配置在忽略的 `.local/stack.json`；源码 commit 必须与该配置一致。另一台机器需重新克隆参照 commit 并设置 sourceDir。首次先在源仓库执行固定工具链的 `pnpm install --frozen-lockfile`。
- 依赖和工具链不替换全局版本。不要以外层 npx -c 启动 raftdev：其 npm_config_call/package 会污染内部 npx 调用，触发 EUSAGE。脚本先取得局部 Node/Pnpm 路径，再直接启动并清理 npm 配置环境变量；该方式已成功启动。
- 固定工具链 Node 24.21.0 / pnpm 10.29.3。首次冻结安装成功，1331 依赖；没有改 source mirror 的跟踪文件。
- public preview tunnel 已关闭；开发栈自动停机关闭，保留供下一步对照开发使用。fixture 身份/会话资料只在被忽略的本机开发状态中，不复制到项目文档。
- Flutter 客户端与独立 SDK Widget Preview 已实现；服务健康检查、组件预览和原生产品验收分别记录，不互相替代。最终结果见 feature-parity.csv 与实际运行报告。

## 完整消息与未读链路

该源版本的默认启动不自动设置 RisingWave；实际 Web 验证发现 Inbox HTTP500、消息请求HTTP503（RisingWaveNotConfiguredError）。因此当前 launcher 使用 `--risingwave=full`，由官方脚本完成 CDC、48项materialized view bootstrap与Inbox parity检查，不能以单个 /health200代替。

- RisingWave pgwire localhost:17706；dashboard http://localhost:17906。
- 镜像固定 v2.8.0 官方多架构digest `sha256:ba5915a5e85c938a3ec62d76c63c6e4cb37d4f4e3c5c30886f0d2eff61b70073`。本机 Docker Hub 下载阻塞；使用 mirror.gcr.io 同一digest，已下载manifest核对SHA256相同，并成功pull。镜像约2.27GiB compressed，不另用浮动latest。
- `SLOCKDEV_TRACE_OBSERVE=0` 关闭额外OTLP观测collector；产品trace worker仍保留。浏览器使用 canonical localhost Web URL，符合其跨域origin。
- `.local/stack-*.log` 权限0600，可能含fixture登录资料，仅本机排查，不提交或复制。浏览器状态同样是私有忽略文件。

## 固定源快照的本地启动兼容补丁

原快照 verifier 导入已经移除的 `__testRisingWaveInboxFailSoft` 并调用 `.setDeps`，而当前 channelService 仅导出 `__testRisingWaveInbox.set`，因此 strict parity 启动时报 SyntaxError。只修正该校验脚本的符号与setter，不改服务端查询/权限/消息或Web行为，不删除严格计数/全量PG与RW比较。可审核diff和前后SHA256在 `tool/reference-patches/`；launcher仅在固定旧hash时自动应用，遇到陌生hash拒绝修改。

源码HEAD仍是 source-reference.json 的固定commit，但工作目录含已列出的校验脚本和fixture补丁。新机器可复现，不把dirty工作目录伪称完整原样快照。

种子脚本把历史消息设成几分钟前/几天前，却用当前时间写频道加入记录。RW Activity遵守加入后活动的规则，原PG校验计入该历史，初始totalCount34 vs28。`seed-history.patch`仅调整本地fixtures的加入时间早于其历史，并为primary #all创建一条普通参照消息；不改服务端查询/权限逻辑。所有兼容文件均有固定前后hash，且完整严格parity仍执行。
