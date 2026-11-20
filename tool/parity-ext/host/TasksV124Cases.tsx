import {
  setServerFeatureFlagForTests as setParityExtTasksV124Flag,
  TASK_V2_CONVERSATIONS_FLAG_KEY as PARITY_EXT_TASKS_V124_FLAG,
} from "../src/store/serverFeatureFlags";
import parityExtTasksV124Fixture from "virtual:parity-ext/tasks-v124";

const PARITY_EXT_TASKS_V124_PREFIX = "components.pages.tasks-v124.";

(function primeParityExtTasksV124Route() {
  if (typeof window === "undefined") return;
  const params = new URLSearchParams(window.location.search);
  const id = params.get("case") ?? "";
  if (!id.startsWith(PARITY_EXT_TASKS_V124_PREFIX)) return;
  params.set("tab", params.get("tab") === "all" ? "all" : "mine");
  params.set("view", "list");
  window.history.replaceState(null, "", `/s/${fxServer.slug}/tasks?${params}`);
})();

function ParityExtTasksV124View({ id }: { id: string }) {
  useMemo(() => {
    primeNavigationVisualStores();
    setParityExtTasksV124Flag(fxServer.id, PARITY_EXT_TASKS_V124_FLAG, true);
    const { channel, agent } = parityExtTasksV124Fixture;
    useChannelStore.setState({ channels: [channel] as never, dmChannels: [], loading: false });
    useAgentStore.setState({ agents: [{ ...visualAgents[0], ...agent }] as never });
  }, []);
  return (
    <div data-visual-case={id} className="flex h-dvh flex-col overflow-hidden">
      <Routes>
        <Route path="/s/:serverSlug/*" element={<MainLayout />} />
      </Routes>
    </div>
  );
}

function parityExtTasksV124Element() {
  const id = new URLSearchParams(window.location.search).get("case") ?? "";
  return id.startsWith(PARITY_EXT_TASKS_V124_PREFIX) ? <ParityExtTasksV124View id={id} /> : null;
}
