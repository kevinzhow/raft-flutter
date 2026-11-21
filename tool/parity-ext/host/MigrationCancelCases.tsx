import { AgentMigrationCancelDialog as ParityExtMigrationCancelDialog } from "../src/components/agentMigration/AgentMigrationCancelDialog";
import migrationCancelFixture from "virtual:parity-ext/migration-cancel";

function parityExtMigrationCancelElement() {
  const params = new URLSearchParams(window.location.search);
  if (!params.get("case")?.startsWith("components.dialogs.desktop.migration-cancel.")) return null;
  const hosted = params.get("targetKind") === "hosted";
  const notice = {
    ...migrationCancelFixture.notice,
    ...(hosted ? { targetKind: "hosted" } : {}),
  };
  return (
    <ParityExtMigrationCancelDialog
      agentId="a1"
      notice={notice as never}
      machines={migrationCancelFixture.machines as never}
      onClose={() => undefined}
      onRefresh={async () => undefined}
    />
  );
}
