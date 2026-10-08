# Prepared action-card fixture admission

Read-only and isolated setup checks on 2026-10-08 JST used the actual fixture account and the pinned mounted server source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`. Credentials stayed in memory and were not included in this report.

A fresh owned workspace admits the complete external-agent credential and prepared-card sequence under the actual fixture entitlement. Its mounted API cleanup passes. The native helper now uses this isolated workspace and the real setup handoff; the earlier b20-source version-bound Linux whole-app run `2026-10-08T01:49:11.360590Z` passed native human review and confirmation as well as the full aggregate. Android current6ab full passed confirmation and the aggregate; 6ab baseline Linux full also passed.

## Fresh owned workspace verification

A fresh isolated workspace created through the mounted server route reports Free with zero agents, one human, `maxAgents=-1`, and `maxUniversalSeats=-1` under the fixture's actual current entitlement. The exact carrier/external-agent/scope/member/credential-mint/agent-prepare sequence passes. A human message-context read confirms the durable card is `prepared`; no human action is executed by this API probe.

The source `createAgent` transaction calls `markServerSetupCompleteOnFirstAgent` for ordinary direct creation, including external agents. The fresh projection consequently reports `phase=complete`, `surface=complete`, and `blocksChat=false`. The existing fixture human already has survey answers, so `surveyPending=false`; the newly owned workspace still correctly owes its real handoff, `handoffPending=true`. No setup completion was fabricated and no Computer fact was substituted.

The native helper now creates its own workspace and confirms the real "Let's Go" handoff through the product UI before opening the prepared card. It restores the original controller server/channel before deleting only its recorded owned workspace. Cleanup supplies that workspace's exact header independently of the restored UI selection, retaining the source server-path/header contract. The mounted API probe verifies successful workspace cleanup and absence from a fresh membership listing, including removal of the owned carrier, external agent, and minted credential. The completed Linux whole-app run passed human confirmation; Android current6ab full completed03:02:43 UTC; 6ab baseline Linux full also passed.

## Linux native human confirmation

The earlier b20-source serialized Linux run started at 01:49:11 UTC on 2026-10-08 passed the complete prepared-card scenario and whole-app suite. The real card opened its review form with the prepared values. The human UI changed the channel name and description, then confirmed creation. The mounted message-context receipt reported `actionMetadata.state=executed` and `result.kind=channel`; a fresh channel read matched the edited name and description. The card rendered completion with its human actor. All three native screenshots were visually inspected. The completed earlier b20 manifest records source hash `b20ae836e668cfff840cbe01beabfad2526444621866ec0b6f9c173bae4e0fd4`; the prepared, authoritative-preview and completed captures are checkpoints in that passing whole-app run.

Stable copies and assertions are in [the Linux action-card evidence](/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/reports/raft-reference/action-card/linux-20261008-000823Z/evidence.json). The report is stored in the agent workspace at `/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/reports/raft-reference/action-card/linux-20261008-000823Z`; those stable copies retain the earlier 00:08:23 scenario proof. The final-run captures and manifest are under this checkout's `.local/native-e2e`. Android current6ab full completed03:02:43 UTC; 6ab baseline Linux full also passed.

## Existing bootstrap workspace diagnostic

The first workspace selected by native controller bootstrap grants the fixture owner authority and reports `blocksChat=false`. Billing reports Pro, four humans and four active agents, `maxAgents=-1`, and no configured Stripe runtime. The actual source server process has device authentication enabled under the default-on `SLOCK_DEVICE_LOGIN_ENABLED` contract.

The helper's isolated public carrier creation succeeds. Its external-agent create is rejected with HTTP 400 and the public error: “Seat limit reached (4.4/1 on Pro plan). Upgrade for more.” No credential was minted, no action was prepared, and no human action was executed. Cleanup deleted only the recorded probe carrier IDs; a fresh channel listing confirms zero remaining probe carriers.

This is the mounted admission contract, rather than an unsupported external-agent route. `agentService.createAgent` checks `assertAgentCapacityAvailable` under the agent-create lock. Shared `getBillingCapacity` reports separate human and agent maxima as unlimited for Pro while imposing `maxUniversalSeats` from the provisioned pack count. Shared `getBillingUsage` computes human count plus 0.1 per agent, and `getBillingCapacityLimitState` checks the next universal-seat total. `maxAgents=-1` alone does not establish creation eligibility.

The existing workspace cannot admit another agent. That result does not describe a newly owned fixture workspace. No billing configuration, subscription, entitlement, existing agent, or source gate was changed by these checks.

Current acceptance revision: `6ab79f33a7f39f98523dadd38dfc1430fd2d7f8e75d10736d0c80050bd1c5701`. Engineering353 Dart/29 host/analyze passes. Android full `2026-10-08T03:02:43.361866Z` completed with54 checked PNG checkpoints; Linux same-source `2026-10-08T03:11:25.507223Z` completed with53 checked PNG checkpoints. Earlier b20/042 evidence remains historical or auxiliary.

功能基线6ab现已通过两平台完整主应用验收：Android `2026-10-08T03:02:43.361866Z` /54检查点、Linux `2026-10-08T03:11:25.507223Z` /53检查点，归档于 `.local/functional-baseline-6ab`。用户已授权新的页面/组件像素级对齐；该视觉修正工作正在进行，新版源码需重新工程/原生验收，最终安装包暂未发行。这些功能基线记录不证明像素等价。
