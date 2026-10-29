// raft-flutter parity EXTENSION cases: error presentation (not official).
// Appended to the generated VisualTestingCases.tsx like host/ShellCases.tsx
// (shares its imports and private helpers); identifiers are prefixed
// `parityExtErr`. Ids: components.errors.<surface>.<variant>.<theme>
// (tool/parity-ext/build-errors.py).
//
//   toast      -> LocalizedToastProvider rows (toast.error / success / info)
//   banner     -> ui/Banner (intent warning, className font-bold)
//   field      -> ui/FormField with error= vs hint=
//   dialog     -> task/CreateTaskDialog after a failed submit (Banner in body)
//   loaderror  -> the AgentSkills load-failure block (markup copied verbatim)
import ParityExtErrBanner from "../src/components/ui/Banner";
import ParityExtErrFormField from "../src/components/ui/FormField";
import ParityExtErrToastProvider from "../src/components/LocalizedToastProvider";
import ParityExtErrCreateTask from "../src/components/task/CreateTaskDialog";
import { useTaskStore as parityExtErrTaskStore } from "../src/store/taskStore";
import { Button as ParityExtErrButton, Input as ParityExtErrInput, toast as parityExtErrToast } from "raft-ui";
import { RefreshCw as ParityExtErrRefresh } from "lucide-react";
import { useEffect as parityExtErrUseEffect } from "react";
import type { ReactNode as ParityExtErrNode } from "react";

type ParityExtErrProps = { raw: string; surface: string; variant: string; message: string; width: number };

function parityExtErrProps(): ParityExtErrProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.errors.") || params.get("extKind") !== "errors") return null;
  return {
    raw,
    surface: params.get("surface") ?? "",
    variant: params.get("variant") ?? "",
    message: params.get("message") ?? "",
    width: Number(params.get("width") ?? 480),
  };
}

function ParityExtErrView({ p }: { p: ParityExtErrProps }) {
  useMemo(() => primeDirectVisualStores(p.raw), [p.raw]);
  const toastKind = p.surface === "toast" ? p.variant.split("-")[0] : "";
  parityExtErrUseEffect(() => {
    if (!toastKind) return;
    (parityExtErrToast as unknown as Record<string, (title: string) => void>)[toastKind](p.message);
  }, [toastKind, p.message]);
  useMemo(() => {
    if (p.surface !== "dialog") return;
    // The server's own error text, as CreateTaskDialog reads it from
    // `err.response.data.error`.
    parityExtErrTaskStore.setState({
      createTasks: async () => {
        throw { response: { data: { error: p.message } } };
      },
    } as never);
  }, [p.surface, p.message]);
  const frame = (body: ParityExtErrNode, height?: number) => (
    <div
      data-visual-case={p.raw}
      className="bg-layer-panel theme-brutal:bg-white"
      style={{ width: p.width, height, padding: 16, overflow: "hidden" }}
    >
      {body}
    </div>
  );
  let body: ParityExtErrNode = null;
  if (p.surface === "banner") {
    body = frame(
      <ParityExtErrBanner
        intent="warning"
        density={p.variant === "sm" ? "sm" : "md"}
        className="font-bold"
        actions={p.variant === "action"
          ? <ParityExtErrButton variant="outline" size="sm">Try again</ParityExtErrButton>
          : undefined}
      >
        {p.message}
      </ParityExtErrBanner>,
      p.variant === "long" || p.variant === "action" ? 140 : 100,
    );
  } else if (p.surface === "field") {
    body = frame(
      p.variant === "error" ? (
        <ParityExtErrFormField label="Email" labelStyle="plain" error={p.message} htmlFor="err-email">
          <ParityExtErrInput id="err-email" type="text" value="alex@" onChange={() => undefined} />
        </ParityExtErrFormField>
      ) : (
        <ParityExtErrFormField label="Server name" labelStyle="plain" hint={p.message} htmlFor="err-name">
          <ParityExtErrInput id="err-name" type="text" value="Design Lab" onChange={() => undefined} />
        </ParityExtErrFormField>
      ),
      140,
    );
  } else if (p.surface === "loaderror") {
    // AgentSkills error block (components/agent/AgentSkills.tsx), verbatim.
    const embedded = p.variant === "embedded";
    body = (
      <div
        data-visual-case={p.raw}
        data-testid="errors-loaderror"
        className="flex bg-layer-panel theme-brutal:bg-white"
        style={{ width: p.width, height: 200, overflow: "hidden" }}
      >
        <div className={embedded ? "px-5 py-4 flex flex-col items-center gap-3" : "flex flex-1 flex-col items-center justify-center gap-3 bg-layer-panel theme-brutal:bg-white"} style={embedded ? { width: "100%", alignSelf: "flex-start" } : undefined}>
          <span className="text-sm text-foreground-muted theme-brutal:text-black/60 font-mono">{p.message}</span>
          <ParityExtErrButton variant="outline" size="sm" className="flex items-center gap-1">
            <ParityExtErrRefresh size={12} />
            Retry
          </ParityExtErrButton>
        </div>
      </div>
    );
  } else if (p.surface === "dialog") {
    body = (
      <div data-visual-case={p.raw} style={{ width: window.innerWidth, height: window.innerHeight, overflow: "hidden", position: "relative" }}>
        <ParityExtErrCreateTask channelId="channel-design" onClose={() => undefined} />
      </div>
    );
  }
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <ParityExtErrToastProvider>
        {p.surface === "toast" ? <div data-visual-case={p.raw} style={{ width: p.width, height: 120 }} /> : body}
      </ParityExtErrToastProvider>
    </main>
  );
}

function parityExtErrorsElement() {
  const p = parityExtErrProps();
  return p ? <ParityExtErrView p={p} /> : null;
}
