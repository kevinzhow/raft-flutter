# Prepared action-card fixture admission

Read-only and isolated setup checks on 2026-10-08 JST used the actual fixture account and the pinned mounted server source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`. Credentials stayed in memory and were not included in this report.

A fresh owned workspace admits the complete external-agent credential and prepared-card sequence under the actual fixture entitlement. Its mounted API cleanup passes. The native helper now uses this isolated workspace and the real setup handoff; the parent agent’s Linux run at 00:08:23 UTC on 2026-10-08 passed native human review and confirmation. Android confirmation remains pending.

## Fresh owned workspace verification

A fresh isolated workspace created through the mounted server route reports Free with zero agents, one human, `maxAgents=-1`, and `maxUniversalSeats=-1` under the fixture's actual current entitlement. The exact carrier/external-agent/scope/member/credential-mint/agent-prepare sequence passes. A human message-context read confirms the durable card is `prepared`; no human action is executed by this API probe.

The source `createAgent` transaction calls `markServerSetupCompleteOnFirstAgent` for ordinary direct creation, including external agents. The fresh projection consequently reports `phase=complete`, `surface=complete`, and `blocksChat=false`. The existing fixture human already has survey answers, so `surveyPending=false`; the newly owned workspace still correctly owes its real handoff, `handoffPending=true`. No setup completion was fabricated and no Computer fact was substituted.

The native helper now creates its own workspace and confirms the real "Let's Go" handoff through the product UI before opening the prepared card. It restores the original controller server/channel before deleting only its recorded owned workspace. Cleanup supplies that workspace's exact header independently of the restored UI selection, retaining the source server-path/header contract. The mounted API probe verifies successful workspace cleanup and absence from a fresh membership listing, including removal of the owned carrier, external agent, and minted credential. The serialized Linux run passed human confirmation; Android remains pending.

## Linux native human confirmation

The serialized Linux run started at 00:08:23 UTC on 2026-10-08 passed the complete prepared-card scenario. The real card opened its review form with the prepared values. The human UI changed the channel name and description, then confirmed creation. The mounted message-context receipt reported `actionMetadata.state=executed` and `result.kind=channel`; a fresh channel read matched the edited name and description. The card rendered completion with its human actor. All three native screenshots were visually inspected. This records a scenario checkpoint and does not claim the later aggregate whole-app run passed.

Stable copies and assertions are in [the Linux action-card evidence](/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/reports/raft-reference/action-card/linux-20261008-000823Z/evidence.json). The report is stored in the agent workspace at `/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/reports/raft-reference/action-card/linux-20261008-000823Z`; the original captures are under this checkout's `.local/native-e2e`. Android execution remains pending.

## Existing bootstrap workspace diagnostic

The first workspace selected by native controller bootstrap grants the fixture owner authority and reports `blocksChat=false`. Billing reports Pro, four humans and four active agents, `maxAgents=-1`, and no configured Stripe runtime. The actual source server process has device authentication enabled under the default-on `SLOCK_DEVICE_LOGIN_ENABLED` contract.

The helper's isolated public carrier creation succeeds. Its external-agent create is rejected with HTTP 400 and the public error: “Seat limit reached (4.4/1 on Pro plan). Upgrade for more.” No credential was minted, no action was prepared, and no human action was executed. Cleanup deleted only the recorded probe carrier IDs; a fresh channel listing confirms zero remaining probe carriers.

This is the mounted admission contract, rather than an unsupported external-agent route. `agentService.createAgent` checks `assertAgentCapacityAvailable` under the agent-create lock. Shared `getBillingCapacity` reports separate human and agent maxima as unlimited for Pro while imposing `maxUniversalSeats` from the provisioned pack count. Shared `getBillingUsage` computes human count plus 0.1 per agent, and `getBillingCapacityLimitState` checks the next universal-seat total. `maxAgents=-1` alone does not establish creation eligibility.

The existing workspace cannot admit another agent. That result does not describe a newly owned fixture workspace. No billing configuration, subscription, entitlement, existing agent, or source gate was changed by these checks.
