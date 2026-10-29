// Entry of the raft-ui specimen host. URL: /?specimen=<id>&mode=light|dark
import "@botiverse/raft-ui/fonts.css";
import "./styles.css";

import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { ThemeProvider } from "@botiverse/raft-ui";
import config from "../../specimens.json";
import { SPECIMENS } from "./specimens";

const params = new URLSearchParams(window.location.search);
const id = params.get("specimen") ?? "";
const mode = params.get("mode") ?? "";
const entry = config.specimens.find((s) => s.id === id);
if (!entry || !(config.modes as string[]).includes(mode)) throw new Error(`unknown specimen/mode: ${id} ${mode}`);
const Specimen = SPECIMENS[id];
if (!Specimen) throw new Error(`specimens.json lists ${id} but host/src/specimens.tsx has no renderer`);

// The frame is the capture target: fixed content width, 16px padding, on the
// canvas layer of the mode. Nothing in it depends on the viewport.
createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <ThemeProvider mode={mode as "light" | "dark"}>
      <div
        data-specimen={id}
        className="box-content bg-layer-canvas p-4 text-foreground"
        style={{ width: entry.width, isolation: "isolate" }}
      >
        <Specimen />
      </div>
    </ThemeProvider>
  </StrictMode>,
);
