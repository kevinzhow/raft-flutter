// Agent migration progress, cancel and error copy (MigrationProgressPanel,
// AgentMigrationCancelDialog, MigrationErrorContent, errors.ts). English key ->
// Web zh-cn wording, verbatim (packages/web/src/i18n/messages/zh-cn.ts, tag
// v1.21.12-source.1). ICU plural / select arms are written out as one key each
// (raftText does not interpret ICU) and `{n, number}` is `{n}`.
const Map<String, String> zhCatalogAgentMigrationPanel = {
  "Migration to {target}":
      "迁移到 {target}",
  "Migration to {target} canceled":
      "到 {target} 的迁移已取消",
  "Migration to {target} needs attention":
      "到 {target} 的迁移需要处理",
  "Canceling migration to {target}":
      "正在取消到 {target} 的迁移",
  "Migration progress to {target}":
      "迁移到 {target} 的进度",
  "Stopping the agent on {source} so its workspace can be packed.":
      "正在停止 {source} 上的 Agent，以便打包工作区。",
  "Packing the workspace on {source}. Large workspaces can take up to 30 minutes.":
      "正在 {source} 上打包工作区。工作区较大时最长可能需要 30 分钟。",
  "Transferring workspace to {target}.":
      "正在将工作区传输到 {target}。",
  "The workspace moved to {target}, but the agent did not start automatically.":
      "工作区已迁移到 {target}，但 Agent 没有自动启动。",
  "The agent is still on {source} and works as usual.":
      "Agent 仍在 {source} 上，可以照常使用。",
  "The agent moved to {target} but could not start there. Make sure Raft Computer is running on {target}, then start the agent.":
      "Agent 已迁移到 {target}，但没能在那里启动。请确认 {target} 上的 Raft Computer 正在运行，然后启动 Agent。",
  "Starting the agent on {target}.":
      "正在 {target} 上启动 Agent。",
  "Migration state {state} for {target}.":
      "{target} 的迁移状态为 {state}。",
  "Preparing the workspace on {source} stopped making progress before the deadline. {source} may have gone offline, or packing stalled. Make sure {source} is online, then try again.":
      "{source} 上的工作区在截止时间前停止了进展。可能是 {source} 已离线，或打包卡住了。请确认 {source} 在线后重试。",
  "Preparing the workspace on {source} stopped making progress before the deadline ({deadline}). {source} may have gone offline, or packing stalled. Make sure {source} is online, then try again.": "{source} 上的工作区在截止时间（{deadline}）前停止了进展。可能是 {source} 已离线，或打包卡住了。请确认 {source} 在线后重试。",
  "The target computer {target} did not finish installing the workspace before the deadline. Make sure the target is running and has enough free disk space, then try again.":
      "目标计算机 {target} 未能在截止时间前完成工作区安装。请确认目标计算机正在运行且有足够可用磁盘空间，然后重试。",
  "{computer} has not reported whether {runtime} is available. Start or restart Raft Computer and wait for runtime detection, or choose another computer.":
      "{computer} 尚未报告是否支持 {runtime}。请启动或重启 Raft Computer 并等待运行时检测，或另选一台计算机。",
  "{computer} does not support {runtime}. Install or enable that runtime on this computer, or choose another computer.":
      "{computer} 不支持 {runtime}。请在这台计算机上安装或启用该运行时，或另选一台计算机。",
  "{computer} needs a Raft Computer update before it can move agents. Update Raft Computer on {computer} to the latest version, restart it, wait for it to reconnect, then try again.":
      "{computer} 需要先更新 Raft Computer 才能迁移 Agent。请将 {computer} 上的 Raft Computer 更新到最新版本，重启并等待重新连接后再试。",
  "{source} and {target} need a Raft Computer update before they can move agents. Update Raft Computer on both to the latest version, restart them, wait for them to reconnect, then try again.":
      "{source} 和 {target} 都需要先更新 Raft Computer 才能迁移 Agent。请将两台都更新到最新版本，重启并等待重新连接后再试。",
  "The connection between the two computers dropped at {time}, during the transfer.":
      "两台计算机之间的连接在 {time} 断开了，当时正在传输。",
  "Bring {computer} online, then try again.":
      "请先让 {computer} 上线，然后重试。",
  "Bring {source} and {target} online, then try again.":
      "请先让 {source} 和 {target} 上线，然后重试。",
  "A workspace already exists at {path} on the target computer, so the agent was not installed. Rename or move that folder — for example, appending .bak to its name is enough — then start the migration again. Check before you move it that this is not a copy you still need — Raft never deletes it, and moving it leaves it on that computer.":
      "目标计算机上 {path} 已有工作区，所以 Agent 没有安装。请把这个目录改名或移走（比如在名字后面加个 .bak 就行），然后重新发起迁移。移走前先确认这份不是你还需要的副本——Raft 不会删除它，移走后它仍在那台计算机上。",
  "A completed copy of this workspace from an earlier migration is at {path} on the target computer, so Raft stopped instead of replacing it. Rename or move that folder — for example, appending .old to its name is enough — then start the migration again. Check before you move it which copy is current — Raft never deletes it, and moving it leaves it on that computer.":
      "目标计算机上 {path} 是上一次迁移留下的完整副本，Raft 没有覆盖它就停了下来。请把这个目录改名或移走（比如在名字后面加个 .old 就行），然后重新发起迁移。移走前先确认哪个副本是当前版本——Raft 不会删除它，移走后它仍在那台计算机上。",
  "The target computer needs {required} free to stage and install this migration, but only {available} is available. Free disk space and try again.":
      "目标计算机需要 {required} 空闲空间来暂存并安装本次迁移，但当前只有 {available} 可用。请释放磁盘空间后重试。",
  "Packing the workspace on {source} (1 minute so far). Large workspaces can take up to 30 minutes.":
      "正在 {source} 上打包工作区，已用 1 分钟。工作区较大时最长可能需要 30 分钟。",
  "Packing the workspace on {source} ({minutes} minutes so far). Large workspaces can take up to 30 minutes.":
      "正在 {source} 上打包工作区，已用 {minutes} 分钟。工作区较大时最长可能需要 30 分钟。",
  "Packing the workspace on {source}: {files} files, {size} so far.":
      "正在 {source} 上打包工作区：已处理 {files} 个文件，{size}。",
  "The workspace has {count} files and folders; migration supports up to {limit}. Most are in {paths}. Ask the agent to delete folders it no longer needs, or to list them in .raftmigrateignore, then try again.":
      "工作区有 {count} 个文件和文件夹，迁移最多支持 {limit} 个。大部分位于：{paths}。请让 Agent 删除不再需要的目录，或把它们写进 .raftmigrateignore，然后重试。",
  "The workspace has {count} files and folders; migration supports up to {limit}. Ask the agent to delete folders it no longer needs, or to list them in .raftmigrateignore, then try again.":
      "工作区有 {count} 个文件和文件夹，迁移最多支持 {limit} 个。请让 Agent 删除不再需要的目录，或把它们写进 .raftmigrateignore，然后重试。",
  "The workspace is too large to move: compressed, it is over the {limit} limit. Largest items: {items}. Ask the agent to delete large files it no longer needs, or to list them in .raftmigrateignore, then try again.":
      "工作区太大，无法迁移：压缩后超过了 {limit} 的上限。最大的几项：{items}。请让 Agent 删除不再需要的大文件，或把它们写进 .raftmigrateignore，然后重试。",
  "The workspace is too large to move: compressed, it is over the {limit} limit. Ask the agent to delete large files it no longer needs, or to list them in .raftmigrateignore, then try again.":
      "工作区太大，无法迁移：压缩后超过了 {limit} 的上限。请让 Agent 删除不再需要的大文件，或把它们写进 .raftmigrateignore，然后重试。",
  "The workspace is too large to move. Largest items: {items}. Ask the agent to delete large files it no longer needs, or to list them in .raftmigrateignore, then try again.":
      "工作区太大，无法迁移。最大的几项：{items}。请让 Agent 删除不再需要的大文件，或把它们写进 .raftmigrateignore，然后重试。",
  "The workspace has too many files and folders to move ({count}). Most are in {paths}. Ask the agent to delete folders it no longer needs, or to list them in .raftmigrateignore, then try again.":
      "工作区里的文件和文件夹太多，无法迁移（{count} 个）。大部分位于：{paths}。请让 Agent 删除不再需要的目录，或把它们写进 .raftmigrateignore，然后重试。",
  "The workspace has too many files and folders to move ({count}). Ask the agent to delete folders it no longer needs, or to list them in .raftmigrateignore, then try again.":
      "工作区里的文件和文件夹太多，无法迁移（{count} 个）。请让 Agent 删除不再需要的目录，或把它们写进 .raftmigrateignore，然后重试。",
  "The workspace has too many files and folders to move. Most are in {paths}. Ask the agent to delete folders it no longer needs, or to list them in .raftmigrateignore, then try again.":
      "工作区里的文件和文件夹太多，无法迁移。大部分位于：{paths}。请让 Agent 删除不再需要的目录，或把它们写进 .raftmigrateignore，然后重试。",
  "{path} ({count})":
      "{path}（{count} 个）",
};
