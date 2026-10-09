# Cold task parent metadata

This bounded K10b follow-up extends the independent task owner described in
[source-task-url-owner.md](source-task-url-owner.md). Source remains pinned to
`26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`, Web 1.17.5 and raft-ui 0.5.27.
Source paths below are relative to `packages/web/src`.

## Source authority and implementation boundary

| Source path and lines | Contract |
| --- | --- |
| `store/channelStore.ts:266–302` | A missing real channel uses `GET /channels/:id`; a changed server epoch rejects the result. Actual API metadata supplies the channel projection. |
| `components/message/ThreadPanel.tsx:887–929` | The discussion source is the actual parent channel. Missing membership stays unresolved instead of flashing the wrong control. The thread source copies real parent metadata. |
| `components/layout/MainLayout.tsx:1019–1057` | Task facts resolve from the real parent-channel bucket, including private and DM parents absent from the server task board. |
| `store/taskStore.ts:440–467` | Concurrent mounted consumers share a currently loading channel task bucket. |

The Source task wrapper does not itself call `ensureChannel`. Its discussion
reads the shared directory. This follow-up is an explicitly authorized Flutter
extension of that real-metadata contract for a cold task whose parent is absent
from the directory; no exact Source asynchronous task-hydration chronology or
browser-renderer equivalence is claimed.

## Accepted metadata before discussion

An unknown modern task owner loads actual parent metadata before it requests
task facts or mounts the borrowed discussion. The response must identify the
requested channel and current server and provide a real name and supported
channel type. Resource permission is checked against that accepted record. No
synthetic channel, joined membership, task facts or deletion-cleanup state is
created while metadata is pending, denied or malformed.

The accepted record stays private to the task owner and its borrowed discussion.
The root directory, selected channel, message window and navigation request
revision remain unchanged. The child shares the authorized client, cache and
entity directory and cannot dispose the main session. Existing known-parent
opening remains synchronous.

Close, Back, retarget, principal, server and role changes reject late metadata.
Channel removal retires the private record and discussion. A channel authority
or membership event retires it immediately and performs a fresh metadata read;
denial cannot retain the old title, properties or composer. A new principal's
mounted URI has its own new request, whose response cannot come from the old
owner's completion. Each independent main/side/task consumer keeps its own
acceptance checks.

The pending-only task bucket helper accepts the validated parent record so the
root task owner and borrowed discussion share the same authority-scoped read
even when the root directory lacks that record. It rejects mismatched metadata,
retains no successful or failed read and makes a real request for a later
consumer.

## Mounted evidence

The local HTTP fixture and actual `WorkspaceView` cover Brutal light, Elegant
light and Elegant dark. Six success cases run at 390px and 1280px. The remaining
denial and retirement cases run at 390px; they do not claim a native platform
result.

| Check | Result | Receipt or test |
| --- | --- | --- |
| Cold metadata success, strict single bucket GET, retained main draft/window, real borrowed discussion | 6 passed | `workspace_task_parent_hydration_test.dart` |
| Actual HTTP 403/404, wrong-server and malformed metadata | 12 passed | Same test |
| Back/new real card followed by late metadata success or error | 6 passed | Same test |
| Principal/server/role/removal and accepted-parent authority refresh denial | 15 passed | Same test |
| Pending-only bucket scope, real private metadata sharing and mismatch rejection | 4 passed | `source_task_bucket_test.dart` |
| New parent, grid-channel opener and bucket cases together | 46 passed | `.local/task-parent-grid-v8.log` |
| Existing task URL/surface/authority/controls, classic entrypoints, projection and grid tests | 92 passed | `.local/task-parent-regressions-v2.log` |
| Selected app analysis | Clean | `.local/task-parent-analysis-v3.log` |
| Design-system ratchet and scanner checks | 6 passed; no growth | `.local/task-parent-ds-v1.log` |

The principal tests gate the old and new actual HTTP requests separately. A
late old response cannot admit facts to the new owner; the new owner's explicit
403 is observed independently. Retired late replies issue no hidden task read
acknowledgement. The Back/retarget sequence also holds a real main request and
verifies its later acceptance without publishing old remote task facts.

Historical private attempts remain immutable:

| Receipt | Retained result |
| --- | --- |
| `.local/task-parent-mounted-v1.log` | 18 passed / 6 failed from duplicate pending bucket reads. Its denial-labelled cases only received invalid 200 metadata, so they do not prove HTTP 403/404. |
| `.local/task-parent-mounted-v2.log` | Aborted fake-async fixture construction/login; only its private test processes were stopped. |
| `.local/task-parent-mounted-v3.log` | 24 failed because the new fixture lacked mock preferences. |
| `.local/task-parent-mounted-v4.log` | 24 passed with real HTTP status handling. |
| `.local/task-parent-mounted-v5.log`, `v6.log`, `v7.log` | 36 passed / 3 failed: the principal fixture reused one completion for both the old request and a legitimate new-principal request. The diagnostic paths identified the second real request; independently gated requests replace that fixture assumption. |
| `.local/task-parent-analysis-v2.log` | One unnecessary test import, removed before the clean analysis. |

## Remaining boundaries

K10b remains partial. A task opening that removes a profile while a main request
is pending is not proven here. Legacy docking/resizing, simultaneous modern and
legacy composition, exact task pixels, grid footer/standalone Tasks thread-tab
ownership and real Linux/Android task process comparison remain outside this
batch. This change does not infer joining from an absent or denied channel.
