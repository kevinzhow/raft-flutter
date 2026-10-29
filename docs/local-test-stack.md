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
- 本机具体路径配置在忽略的 `.local/stack.json`（多个版本并存时用 `--config`，见下文“多版本配置”）；源码 commit 必须与该配置一致。另一台机器需重新克隆参照 commit 并设置 sourceDir。首次先在源仓库执行固定工具链的 `pnpm install --frozen-lockfile`。
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

v1.21.2 快照的 verifier 导入已经移除的 `__testRisingWaveInboxFailSoft` 并调用 `.setDeps`，当时用 `verify-inbox-parity.patch` 改成 `__testRisingWaveInbox.set`。v1.21.12 的 `verify-risingwave-inbox-parity.ts` 已经使用 `__testRisingWaveInbox`，该补丁已删除，launcher 不再应用它；严格计数和全量 PG/RW 比较保持上游原样。其余兼容补丁在 launcher 中仅在固定旧hash时自动应用，遇到陌生hash拒绝修改。

源码HEAD仍是 source-reference.json 的固定commit，但工作目录含已列出的fixture补丁。新机器可复现，不把dirty工作目录伪称完整原样快照。

种子脚本把历史消息设成几分钟前/几天前，却用当前时间写频道加入记录。RW Activity遵守加入后活动的规则，原PG校验计入该历史，初始totalCount34 vs28。`seed-history.patch`仅调整本地fixtures的加入时间早于其历史，并为primary #all创建一条普通参照消息；不改服务端查询/权限逻辑。所有兼容文件均有固定前后hash，且完整严格parity仍执行。

## 本地 RisingWave 内存上限

`tool/raft-stack start` 还会应用固定哈希的 `risingwave-memory.patch`，仅修改上述本地 Source 副本的 `scripts/dev/raftdev.ts` 启动参数。容器上限为 2GiB，`--memory-swap=2g` 禁止额外 swap；`single_node --total-memory-bytes 1610612736` 使用 1.5GiB 内部预算。此补丁不修改 Web、查询、种子数据或截图基线。

固定 v2.8.0 镜像仅缩小总预算会在 compactor 启动时触发断言。因此本地小容量配置同时使用 16MiB compactor metadata cache、32MiB SST、一个 streaming worker 和一个 compaction worker。这是本地 fixture 的容量配置，吞吐量不能代表生产部署。参数来源与断言见 [v2.8.0 single_node](https://raw.githubusercontent.com/risingwavelabs/risingwave/v2.8.0/src/cmd_all/src/single_node.rs) 和 [compactor 初始化](https://raw.githubusercontent.com/risingwavelabs/risingwave/v2.8.0/src/storage/compactor/src/server.rs)。

2026-10-09 已实际重建该 RisingWave 容器。原 PostgreSQL 容器、数据卷及 16 张 CDC 源表计数保持一致；48 条 bootstrap 语句成功完成。重建前的 PostgreSQL dump、旧停止容器和第一次 compactor 启动失败记录保留在本机，未提交身份或连接资料。

初次重建后 Docker 显示约 650MiB / 2GiB，cgroup OOM 计数为零。这是观测结果，不能替代持续负载验收。Source 的普通和 bootstrap 严格 Inbox 比较都保留了 `PG 21 / RW 19` 未读差异；不得把健康检查或 bootstrap 成功写成该严格比较通过。

逐行定位发现两端 56 条结果身份、最新消息和读取游标一致，仅一个频道的未读数为 `PG 2 / RW 0`。差异是已存在的自己创建任务通知和删除任务通知：固定 Source 的 RW SQL 排除自己的 causal system 消息以及 `task.deleted_summary`，该 verifier 使用的 canonical PG Inbox 路径缺少这两项排除。等待追平和 bootstrap 模式均不改变差异。客户端继续显示接口返回的数据，不另算一套数字；本批未修改 Source 查询，也未将原始严格比较 FAIL 改为 PASS。实际接口的 All、Unread、Mentions 和 sidebar unread summary 均 HTTP 200。后续真实客户端流程和差异定位记录于本机 `.local/cody-risingwave-memory-20261009/`。

## 多版本配置与 v1.21.23 环境（2026-10-23）

`tool/raft-stack [--config PATH] start|stop|status|ports|flags` 现在可以在同一个 worktree 里管理多套独立源码/环境；不带 `--config` 时仍读取 `.local/stack.json`，原 `cody-flutter` 配置不需要任何修改（行为、补丁、日志文件名都不变）。每套配置是 `.local/` 下一个忽略的 JSON（权限 600），日志为 `.local/<配置文件名>-<动作>.log`。除原有必填项 `environment/sourceDir/sourceCommit/webUrl/apiUrl` 外，可选：

- `sourceVersion`：如 `v1.21.23`。对每个补丁名优先使用 `tool/reference-patches/<名>-<版本>.json/.patch`，没有则回退到无后缀的旧版补丁。
- `patches`：补丁名列表，默认 `seed-history`、`risingwave-memory`。
- `toolchain`：`binDir` 指向含 node 与 pnpm 的目录（默认仍是 `npx` 取得的 Node 24.21.0 / pnpm 10.29.3）；`env` 里的变量（如 `COREPACK_HOME`、`COREPACK_ENABLE_DOWNLOAD_PROMPT`）由放在 PATH 最前面的 pnpm 包装脚本导出。原因：raftdev 的 tmux 窗口不继承启动进程的环境，只有 PATH 过去；不这样做时 v1.21.23 的 pnpm 12 会在 server/web 窗口里等待 corepack 下载确认，服务永远起不来（健康检查一直连接被拒）。
- `risingwaveImage`：覆盖固定的 RisingWave 镜像。
- `featureFlags`：启动后（或单独运行 `flags`）为 fixture 主服务器启用的开关列表，见下文。

### v1.21.23 环境（环境名 `cindy-w23`）

- 源码：tag `v1.21.23-source.1`（commit `db5e399f017d584e49597e3a28757645d6807893`），从本地 bare mirror 克隆到 `/mnt/data/tmp/cindy/raft-source-23`。源码 pin 的工具链是 Node >=24（`.node-version` 24.21.0）与 pnpm 12.11.2；使用用户级 Node 24.22.0 + corepack 的 pnpm 12.11.2（`~/.local/opt/node24/bin`、`~/.local/opt/corepack`），没有改全局版本；`pnpm install --frozen-lockfile` 成功。
- Web: http://localhost:15193/ ；API: http://localhost:13021 （`GET /health` HTTP 200）。
- PostgreSQL localhost:15452；Redis localhost:16399；RustFS localhost:19020（控制台 19120）；RisingWave pgwire localhost:17686，dashboard http://localhost:17886；trace worker localhost:18807。端口由环境名推导，与 `cody-flutter` 的端口不冲突，两套可同时运行。
- 启动 `tool/raft-stack --config .local/stack-w23.json start`（首次约 6 分钟，含 RisingWave CDC 与 49 条 bootstrap）；停止 `... stop`；`status`、`ports` 同理。公共 tunnel、自动停机、额外 trace observe 均关闭，镜像用同一个固定 digest。
- 登录资料：官方开发工具生成的 fixture 身份（owner/admin/member 三个账户、两个不同服务器、频道、线程、任务）保存在 `.local/stack-w23-fixture.json`（权限 600，已忽略），不复制到文档。Web 开发模式自动以开发账户登录。
- 配置示例（路径按本机调整，不含任何密码）：

```json
{
  "environment": "cindy-w23",
  "sourceDir": "/mnt/data/tmp/cindy/raft-source-23",
  "sourceCommit": "db5e399f017d584e49597e3a28757645d6807893",
  "sourceVersion": "v1.21.23",
  "patches": ["seed-history", "risingwave-memory"],
  "toolchain": {
    "binDir": "~/.local/opt/node24/bin",
    "env": {"COREPACK_HOME": "~/.local/opt/corepack", "COREPACK_ENABLE_DOWNLOAD_PROMPT": "0"}
  },
  "featureFlags": ["raftbench_overview_v0"],
  "webUrl": "http://localhost:15193/",
  "apiUrl": "http://localhost:13021"
}
```

### v1.21.23 的兼容补丁复查

- `scripts/dev/raftdev.ts` 的 hash 与 v1.21.2/1.21.12 不同，因此新增 `risingwave-memory-v1.21.23.json/.patch`（hunk 内容相同，前后 SHA256 为 v1.21.23 的 `b7c61a60…` → `63d2bd3c…`）。仍然是 2GiB 容器、无额外 swap、1.5GiB 内部预算。
- `seed.ts` 与 v1.21.2 逐字相同（SHA256 `d52b201e…`），`seed-history` 补丁原样适用。实际验证：不打该补丁启动时，严格的 Inbox 初始对比仍失败（`totalCount` PG 34 / RW 28，启动被官方脚本中止并自动清理）；打补丁后严格校验通过，因此仍然需要，没有新建副本。
- v1.21.23 的 verifier 已使用 `__testRisingWaveInbox`，无需 `verify-inbox-parity` 补丁；严格计数与完整 PG/RW 比较保持上游原样。
- 源码工作目录只有上述两个文件被补丁修改。

### v1.21.23 验证结果（2026-10-23）

- `/health` HTTP 200；Web 在 headless Chromium 中加载并自动登录，服务器选择页列出 4 个 fixture 服务器，进入 Dev Workspace 的频道与 Activity 页（35 active、107 unread）。
- 三个 fixture 账户（owner/admin/member）通过 `POST /api/auth/login` 登录均为 200；各自请求 `/api/channels`、`/api/channels/inbox?filter=all|unread|mentions`、`/api/channels/unread`、`/api/messages/channel/<id>` 均 HTTP 200；`/api/channels/activity/snapshot`（带 requestId）HTTP 200，响应头 `X-Raft-Contract: raft.activity-sync;revision=2`，不再有 Inbox 500/消息 503。
- 页面加载期间所有 `/api/*` 请求为 200，唯一例外是 `/api/product-feedback/tickets` 返回 503（反馈工单后端，开发栈未配置，与消息链路无关）。另外开发栈的 `GET /api/version` 始终 503 `build_identity_unavailable`（缺少 `RAFT_RELEASE_SHA` 等构建标识环境变量），依赖该接口的客户端逻辑在本地不可验证。
- RisingWave 约 700MiB / 2GiB（cgroup OOM 为否），PostgreSQL 约 125MiB，RustFS 约 115MiB，Redis 约 4MiB；Node 服务进程合计约 2.3GiB RSS。这是空闲观测值，不是负载验收。

### 功能开关与 RaftBench

- 开关存放在 PostgreSQL 的 `feature_flags` / `feature_flag_rules`。开发栈只种入 `onboarding_*`、`attachment_comments_v0` 三条；因为开发栈用 `drizzle push` 建表，迁移里插入的开关行也不存在。`raftbench_overview_v0` 没有任何行，因此默认关闭（页面显示 “RaftBench is not enabled for this server”）。
- `featureFlags` 配置项（或 `tool/raft-stack --config … flags`）向环境的 PostgreSQL 容器幂等写入：默认关闭、按 server 随机化的开关行，加一条只允许 fixture 主服务器的 `server` 阶段 allow 规则。开关键只允许小写字母、数字、下划线。
- 启用后 `/s/dev/raftbench` 可用：Tasks and cost 部分（`/api/tasks/server/period-metrics` 与 `snapshot-metrics`，数据库指标，不需要 AI）HTTP 200，显示 fixture 的 5 个任务；这是纯本地可验证的部分。
- Conversation insights（AI 分析）默认在本地跑不起来：`GET /api/raftbench` 返回 403 `raftbench_server_not_allowed`。原因是服务端要求 `DEPLOYMENT_ENV=staging` 且服务器 id 在硬编码试点名单或 `RAFTBENCH_CANARY_SERVER_ID`；而 raftdev 把 `DEPLOYMENT_ENV` 固定写成 `slockdev`。分析代理是托管的 antiproton 运行时（基础地址按部署环境写死、需要 `ANTIPROTON_PROVISIONING_TOKEN`、`SLOCK_PROVIDER_CREDENTIAL_KEY` 和 `antiproton_hosted_runtime` 开关）。完整的本地解法见下一节：本机运行 antiproton，并给本地 Raft 打一个仅本地使用的兼容补丁。

## 托管 Agent 本地环境：antiproton + RaftBench + Cloud agent（2026-10-23）

目标：RaftBench AI 洞察和 Cloud agent（托管运行时）在本机端到端可用，不连接任何线上 antiproton。做法是在本机用 `wrangler dev --local` 运行 [botiverse/antiproton](https://github.com/botiverse/antiproton)（Apache-2.0，Cloudflare Worker + Durable Objects，D1/R2/Queues 由 miniflare 本地模拟），本地 Raft 服务端把它当作托管提供方。只有模型调用（DeepSeek）会出本机。

### 组成与数据流

- `tool/antiproton-local`：生成 Worker 本地配置、写私有密钥文件、应用 D1 迁移、启动/停止 Worker、向 antiproton 申请 provider token 并写入 Raft 的私有环境文件。
- `tool/raft-stack` 新增：配置项 `serverEnvFile`、`antiprotonUrl`、`fixturePlan`，动作 `sync`，补丁 `antiproton-local`（`tool/reference-patches/antiproton-local-v1.21.23.json/.patch`，多文件清单，每个文件有前后 SHA256，遇到陌生哈希拒绝修改）。
- 流程：Raft 向 antiproton `POST /provision/agents` 创建 agent（带 provider token 与 agent 凭据）；antiproton 在 Raft 注册 push webhook（`http://localhost:<端口>/hooks/<id>`）；有新消息或 RaftBench 任务时 Raft 向该 hook 推送通知；antiproton 唤醒 agent、调用 DeepSeek，并用 agent 凭据通过 Raft 内部 agent API 读消息（RaftBench 再用 `raftbench/submit` 提交报告）。

### 本地兼容补丁做了什么（仅本地）

补丁只修改源码副本里的 5 个服务端文件，且仅在 `DEPLOYMENT_ENV=slockdev` 并设置了 `ANTIPROTON_BASE_URL_OVERRIDE`（裸的 `http://localhost:<端口>` 或 `http://127.0.0.1:<端口>`）时生效；变量不设置时行为与上游一致。`DEPLOYMENT_ENV` 仍是 `slockdev`（附件流式下载等开发栈行为不变），不改 raftdev。

- RaftBench 报名（`isPilotServer`）、RaftBench worker 和 provider 配置把该环境视为 staging；基础地址换成覆盖值。
- provider 请求（原先走 SSRF 安全 fetch，只允许 HTTPS 公网）、agent inbox push 的端点校验和 POST（原先只允许 HTTPS 公网）对该 loopback 源放行，其他地址仍按原规则拒绝。
- 新增 `RAFTBENCH_LOCAL_SERVER_ID`：RaftBench 可用的服务器。刻意不用 `RAFTBENCH_CANARY_SERVER_ID`：canary 服务器在服务端被冻结为只能有 canary 目标的 RaftBench 服务 agent，不能再创建 Cloud agent；用本地 id 则同一服务器既能跑 RaftBench 又能创建 Cloud agent，二者共用 `ANTIPROTON_PROVISIONING_TOKEN`。

### 配置（路径按本机调整，文件均为 600 权限，放在被忽略的 `.local/`）

`.local/antiproton-w23.json`：

```json
{
  "sourceDir": "/path/to/antiproton",
  "runDir": "/path/to/antiproton-run",
  "port": 18921,
  "nodeBinDir": "~/.local/opt/node24/bin",
  "raftOrigin": "http://localhost:13021",
  "raftEnvFile": "/path/to/raft-flutter/.local/stack-w23-server.env"
}
```

`modelKeyFile`/`modelKeyRef` 可选，默认从 `~/.dsh/.credentials.yaml` 的 `refs:` 里取 `DEEPSEEK_API_KEY`。`raftOrigin` 必须与本地服务端 `SERVER_URL` 一致（provider token 绑定该 origin）。

在 `.local/stack-w23.json` 增加：

```json
{
  "patches": ["seed-history", "risingwave-memory", "antiproton-local"],
  "featureFlags": ["raftbench_overview_v0", "antiproton_hosted_runtime"],
  "serverEnvFile": "/path/to/raft-flutter/.local/stack-w23-server.env",
  "antiprotonUrl": "http://localhost:18921"
}
```

`serverEnvFile` 由 `tool/raft-stack` 创建（权限 600）并以符号链接放到 `<sourceDir>/packages/server/.env`：服务端启动时用 dotenv 读取，而 raftdev 只向 tmux 窗口转发固定的变量白名单，所以这是不改 raftdev 的办法。文件里有 `ANTIPROTON_BASE_URL_OVERRIDE`、`RAFTBENCH_LOCAL_SERVER_ID`（取自 fixture 文件）、随机生成的 `SLOCK_PROVIDER_CREDENTIAL_KEY` 与 `RAFT_APP_WEBHOOK_ENCRYPTION_KEY`，以及下面 `mint-token` 写入的 `ANTIPROTON_PROVISIONING_TOKEN`。已有的键保持不变。密钥和 token 不进入命令行、日志或被跟踪的文件。

### 启动步骤

1. 取得 antiproton 源码并安装依赖（Node 24；npm 11 默认不跑 install 脚本，workerd 二进制来自平台包，无需脚本）：`git clone https://github.com/botiverse/antiproton`，然后 `cd antiproton && PATH=~/.local/opt/node24/bin:$PATH npm ci`。
2. `tool/antiproton-local --config .local/antiproton-w23.json setup`：写 `runDir/wrangler.local.json`、入口包装 `entry.ts`、私有的 `runDir/.dev.vars`（`DEEPSEEK_API_KEY`、随机 `AUTOMATION_TOKEN`、`SECRET_KEK`），并应用 27 个 D1 迁移（本地状态在 `runDir/state`）。
3. `... start`：后台运行 wrangler（记录 pid 到 `runDir/antiproton.pid`，日志 `runDir/antiproton.log`，权限 600），监听 `127.0.0.1:<port>`；`... status`、`... stop`（只停止自己启动的进程组）。
4. `... mint-token`：用 `AUTOMATION_TOKEN` 调 `POST /admin/provider-tokens`（`scope: platform`，`raftOrigin`），把返回的 token 直接写入 Raft 的私有环境文件，不打印；已有有效 token 时不重复申请。
5. `tool/raft-stack --config .local/stack-w23.json sync`：应用补丁、生成/更新环境文件与链接、写入功能开关，并重启服务端（`node --watch`，改动被监视的源文件即可重启，服务端只在启动时读取环境文件）。新环境首次 `start` 之后也会自动做一次这个重启，因为 fixture 服务器 id 到那时才存在。

重新启动 Raft 栈后只需 `tool/raft-stack ... start`（补丁、环境文件和开关自动再应用），antiproton 另外 `tool/antiproton-local ... start`。

### 套餐席位

创建托管 agent 要占套餐席位。fixture 主服务器是 `pro` 套餐（1 个席位，已用 4.4），创建 RaftBench 服务 agent 或 Cloud agent 会得到 500 `Seat limit reached (4.4/1 on Pro plan)`。需要新建托管 agent 时，在配置里加 `"fixturePlan": "founder"` 并运行 `tool/raft-stack ... flags`（或 `sync`）；做完后用 `psql` 把 `servers.plan` 改回 `pro`，因为 fixture 默认是 `pro`，Web/Flutter 对照以它为准。已创建的托管 agent 在套餐改回后继续工作；按代码路径，关闭再重新开启 RaftBench 会复用已有服务 agent、不再占用席位（这一步未实测）。

### 验证结果（2026-10-23，v1.21.23 + antiproton e4bde2d）

- `GET /api/agent-runtime-providers/antiproton` HTTP 200 `available: true`，`/models` HTTP 200（`deepseek-flash`）。
- RaftBench：`PUT /api/raftbench`（一个频道 `#general`，`historyFrom` 6 小时前）HTTP 200；antiproton 日志 `POST /provision/agents 201`，`provisioning.state` 变为 `active`；worker 分配任务后 Raft 向 hook 推送 `POST /hooks/<id> 202`，agent 读取 41 条消息，run 状态 `ready`，报告 `complete`、0 个 pattern（夹具消息平淡，这是模型的判断，不是故障）。把窗口扩大到全部历史（189 条）后再跑一次：`ready`，3 个 finding（含 `unsupported_completion`、`repeated_attempt`，带 evidence/counterevidence 消息 id），`GET /api/raftbench` HTTP 200。
- Cloud agent：`POST /api/agents`（`external: true, provider: "antiproton"`）HTTP 200，provision `active`、push 已注册；给它发一条私信，agent 回复（4 次模型调用）；`DELETE /api/agents/<id>` HTTP 200，antiproton 收到 `DELETE /provision/agents/by-raft-agent/<id> 200`，provision 变为 `deleted`。
- 合计模型调用 6 次（RaftBench 2 次 + Cloud agent 一次对话的 4 个回合），都是 `deepseek-flash`。
- RaftBench worker 每 15 分钟会为已启用的服务器重新分配一次任务，等于周期性模型调用。验证完成后已把本机 RaftBench 关闭（`PUT /api/raftbench` `enabled: false`，服务 agent 保留）；需要时重新 `PUT enabled: true` 即可。

### 已知限制与排错

- antiproton 的 `cf/src/index.ts` 除默认处理器和类外还导出普通常量 `HOOK_OBJECT_TIMEOUT_MS`，本地 workerd 拒绝把它当作入口导出（`not of type 'function or ExportedHandler'`）。因此 `setup` 生成只重新导出 `default`、`AgentDO`、`SandboxTools` 的入口包装 `entry.ts`，不改 antiproton 源码。
- `wrangler dev` 的日志把 `.dev.vars` 的值显示为 `(hidden)`；日志、状态目录都在权限 700 的 `runDir` 下，仍不要提交或粘贴。
- 本地 antiproton 不是线上服务：没有 Run9 沙箱容器、没有 Cloudflare Access/GitHub 登录（UI 允许匿名，只绑定 127.0.0.1）、没有 ScopeDB 追踪转发。依赖这些的 agent 能力在本地不可验证。
- `tool/raft-stack` 的 `sync` 与 `start` 要求 `serverEnvFile` 指向的 `.env` 链接位置没有别的普通文件；有则拒绝覆盖。
