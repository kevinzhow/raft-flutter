import { IntegrationsSection as ManagedMcpIntegrations } from "../src/features/apps/IntegrationsSection";

function ManagedMcpCase({ caseId }: { caseId: string }) {
  useMemo(() => primeSettingsVisualStores({ id: caseId, tab: "integrations" }), [caseId]);
  return (
    <main data-visual-case={caseId} className="min-h-screen bg-layer-canvas font-display text-foreground">
      <ManagedMcpIntegrations variant="settings" />
    </main>
  );
}

function parityExtManagedMcpElement() {
  const caseId = requestedCaseId();
  return caseId.startsWith("components.managed-mcp.") ? <ManagedMcpCase caseId={caseId} /> : null;
}
