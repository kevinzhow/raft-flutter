// raft-flutter parity EXTENSION cases: the Public server page (inventory rows 1.19 / 1.20).
// Appended by tool/parity-ext-web.mjs to the generated VisualTestingCases.tsx like the other host files
// (shares its imports and private helpers); identifiers are prefixed `parityExtPs`.
//
// Every case mounts the REAL pages/PublicServerPage over primed auth / server stores; API answers come from
// tool/parity-ext/fixtures/public-server.json (`routeSets[props.routeSet]`, served by the provider spec's
// page.route, pinned with props.extFixture), the same data the Flutter fixture client reads.
// Ids: components.public-server.<platform>.<surface>.<theme>.
import ParityExtPsPage from "../src/pages/PublicServerPage";
import { useAuthStore as parityExtPsAuthStore } from "../src/store/authStore";
import { useServerStore as parityExtPsServerStore } from "../src/store/serverStore";
import parityExtPsFixture from "virtual:parity-ext/public-server";

function parityExtPsProps() {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.public-server.")) return null;
  return {
    raw,
    authenticated: params.get("authenticated") === "true",
    routeSet: params.get("routeSet") ?? "",
    initialChannelId: params.get("initialChannelId"),
    mobile: params.get("platform") === "mobile",
  };
}

function ParityExtPsView({ p }: { p: NonNullable<ReturnType<typeof parityExtPsProps>> }) {
  useMemo(() => {
    const fx = parityExtPsFixture as Record<string, any>;
    parityExtPsAuthStore.setState({
      initialized: true,
      loading: false,
      user: p.authenticated ? { ...fx.user, emailVerified: true } : null,
    } as never);
    const list = p.authenticated ? (fx.servers.two as unknown[]) : [];
    parityExtPsServerStore.setState({ servers: list as never, current: (list[0] ?? null) as never, loading: false });
  }, [p.raw]);
  const fx = parityExtPsFixture as Record<string, any>;
  return (
    <main className="min-h-screen bg-white p-0 font-display text-foreground">
      <div data-visual-case={p.raw} style={{ width: "100vw", height: "100vh", overflow: "hidden" }}>
        <ParityExtPsPage
          slug={fx.slug}
          initialChannelId={p.initialChannelId}
          authenticated={p.authenticated}
          onSignIn={() => undefined}
          onRegister={() => undefined}
          onUnavailable={() => undefined}
          onJoined={() => undefined}
        />
      </div>
    </main>
  );
}

function parityExtPublicServerElement() {
  const p = parityExtPsProps();
  return p ? <ParityExtPsView p={p} /> : null;
}
