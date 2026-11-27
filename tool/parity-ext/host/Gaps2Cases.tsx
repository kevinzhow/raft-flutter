import { LastMigration as Gaps2LastMigration } from "../src/components/agentMigration/LastMigration";
import { WorkingNowPopover as Gaps2WorkingNowPopover } from "../src/components/layout/WorkingNowSummary";
import { ForwardToastProvider as Gaps2ForwardToastProvider } from "../src/components/message/ForwardToastProvider";
import { forwardToast as gaps2ForwardToast } from "../src/components/message/forwardToast";
import gaps2Fixture from "virtual:parity-ext/gaps2";

function parityExtGaps2Element() {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("case") ?? "";
  if (!id.startsWith("components.gaps2.")) return null;
  if (id.startsWith("components.gaps2.migration.")) {
    return (
      <div style={{ width: "min(620px, 100vw)", padding: 16 }}>
        <Gaps2LastMigration
          notice={gaps2Fixture.migration as never}
          agentName="Alpha"
          machines={gaps2Fixture.machines as never}
          onShowCancel={() => undefined}
          onRefresh={async () => undefined}
        />
      </div>
    );
  }
  if (id.startsWith("components.gaps2.working-now.")) {
    return (
      <div style={{ padding: 24 }}>
        <Gaps2WorkingNowPopover
          items={gaps2Fixture.agents.map((agent) => ({
            ...agent, agentId: agent.id, agentName: agent.name, activity: "working",
            kind: "activity", context: null, agentAvatarUrl: null,
            createdAt: 0, startedAt: 0, idleSince: null,
          }))}
          align="start"
          label="2 agents working"
          testId="working-now-summary"
        >
          2 agents working
        </Gaps2WorkingNowPopover>
      </div>
    );
  }
  return (
    <Gaps2ForwardToastProvider>
      <button
        data-testid="forward-toast-trigger"
        style={{ position: "absolute", top: "50%", left: 24 }}
        onClick={() => gaps2ForwardToast.success("Forwarded to #general.", {
          action: { label: "View in chat", onClick: () => undefined },
        })}
      >
        Forward
      </button>
    </Gaps2ForwardToastProvider>
  );
}
