// Mount the pinned real Web page. Routes supplies its actual token parameter;
// API loading/error replies come from the same fixture as the native view.
import ParityExtPiPage from "../src/pages/IntegrationInvitePage";
import { Routes as ParityExtPiRoutes, Route as ParityExtPiRoute } from "react-router-dom";
import { useAuthStore as parityExtPiAuthStore } from "../src/store/authStore";
import parityExtPiFixture from "virtual:parity-ext/private-app-invite";

function parityExtPiElement() {
  const q = new URLSearchParams(window.location.search);
  const id = q.get("case") ?? "";
  if (!id.startsWith("components.private-app-invite.")) return null;
  parityExtPiAuthStore.setState({
    initialized: true, loading: false, user: parityExtPiFixture.user,
  } as never);
  return (
    <div data-visual-case={id} style={{ width: Number(q.get("w")), height: Number(q.get("h")), overflow: "hidden" }}>
      <ParityExtPiRoutes location="/integration-invites/parity-private">
        <ParityExtPiRoute path="/integration-invites/:token" element={<ParityExtPiPage />} />
      </ParityExtPiRoutes>
    </div>
  );
}
