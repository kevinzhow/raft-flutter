// Appended by tool/parity-ext-web.mjs to the generated VisualTestingCases.tsx.
import type { ReactElement as ParityExtWave4bElement } from "react";
import {
  Button as ParityExtWave4bButton,
  Card as ParityExtWave4bCard,
  DropdownMenu as ParityExtWave4bDropdownMenu,
  DropdownMenuContent as ParityExtWave4bDropdownMenuContent,
  DropdownMenuItem as ParityExtWave4bDropdownMenuItem,
  DropdownMenuTrigger as ParityExtWave4bDropdownMenuTrigger,
  PickerTriggerButton as ParityExtWave4bPickerTriggerButton,
  Select as ParityExtWave4bSelect,
  SelectIcon as ParityExtWave4bSelectIcon,
  SelectTrigger as ParityExtWave4bSelectTrigger,
  SelectValue as ParityExtWave4bSelectValue,
  Skeleton as ParityExtWave4bSkeleton,
} from "@botiverse/raft-ui";
import {
  ChevronDown as ParityExtWave4bChevronDown,
  Code2 as ParityExtWave4bCode2,
  Download as ParityExtWave4bDownload,
  EllipsisVertical as ParityExtWave4bEllipsisVertical,
} from "lucide-react";
import ParityExtWave4bFormField from "../src/components/ui/FormField";
import parityExtWave4bFixture from "virtual:parity-ext/legacy-wave4b";

function parityExtLegacyWave4bRender(
  surface: string,
  form: string,
  caseId: string,
): ParityExtWave4bElement {
  const frameWidth = form === "desktop" ? 440 : 360;
  switch (surface) {
    case "quoted-message-skeleton":
      return (
        <div
          data-visual-case={caseId}
          className="bg-layer-canvas p-4"
          style={{ width: frameWidth }}
        >
          <ParityExtWave4bCard className="w-full">
            <div className="flex h-[34px] items-center border-b border-line-hairline px-3" />
            <div className="flex gap-3 px-3 py-2.5">
              <ParityExtWave4bSkeleton className="size-7 shrink-0" />
              <div className="min-w-0 flex-1 stack-y-2">
                <ParityExtWave4bSkeleton variant="line" className="w-32" />
                <ParityExtWave4bSkeleton variant="line" className="w-full" />
                <ParityExtWave4bSkeleton variant="line" className="w-3/4" />
              </div>
            </div>
          </ParityExtWave4bCard>
        </div>
      );
    case "form-dialog-select": {
      const f = parityExtWave4bFixture.selectField;
      const current = f.options.find((o) => o.value === f.value)?.label ?? f.value;
      return (
        <div
          data-visual-case={caseId}
          className="bg-layer-canvas p-4"
          style={{ width: frameWidth }}
        >
          <ParityExtWave4bFormField label={f.label} hint={f.hint}>
            <ParityExtWave4bSelect value={f.value}>
              <ParityExtWave4bSelectTrigger className="w-full">
                <ParityExtWave4bSelectValue>{current}</ParityExtWave4bSelectValue>
                <ParityExtWave4bSelectIcon />
              </ParityExtWave4bSelectTrigger>
            </ParityExtWave4bSelect>
          </ParityExtWave4bFormField>
        </div>
      );
    }
    case "mermaid-download-menu": {
      const m = parityExtWave4bFixture.mermaidMenu;
      return (
        <div
          className="flex items-start justify-end bg-layer-canvas p-4"
          style={{ width: 420, height: 260 }}
        >
          <ParityExtWave4bDropdownMenu>
            <ParityExtWave4bDropdownMenuTrigger
              render={
                <ParityExtWave4bButton
                  type="button"
                  variant="outline"
                  size="icon-md"
                  aria-label={m.triggerLabel}
                  data-testid="wave4b-mermaid-trigger"
                >
                  <ParityExtWave4bDownload className="size-4" />
                </ParityExtWave4bButton>
              }
            />
            <ParityExtWave4bDropdownMenuContent
              side="bottom"
              align="end"
              sideOffset={4}
              data-testid="wave4b-mermaid-menu"
            >
              {m.items.map((item) => (
                <ParityExtWave4bDropdownMenuItem key={item.id}>
                  {item.icon === "code2" ? (
                    <ParityExtWave4bCode2 size={16} />
                  ) : (
                    <ParityExtWave4bDownload size={16} />
                  )}
                  {item.label}
                </ParityExtWave4bDropdownMenuItem>
              ))}
            </ParityExtWave4bDropdownMenuContent>
          </ParityExtWave4bDropdownMenu>
        </div>
      );
    }
    case "member-actions-menu": {
      const m = parityExtWave4bFixture.memberMenu;
      return (
        <div
          className="flex items-start justify-end bg-layer-canvas p-4"
          style={{ width: 420, height: 300 }}
        >
          <ParityExtWave4bDropdownMenu>
            <ParityExtWave4bDropdownMenuTrigger
              render={
                <ParityExtWave4bButton
                  type="button"
                  variant="ghost"
                  size="icon-md"
                  aria-label={m.triggerLabel}
                  data-testid="wave4b-member-actions-trigger"
                >
                  <ParityExtWave4bEllipsisVertical className="size-4" />
                </ParityExtWave4bButton>
              }
            />
            <ParityExtWave4bDropdownMenuContent
              side="bottom"
              align="end"
              data-testid="wave4b-member-menu"
            >
              {m.items.map((label) => (
                <ParityExtWave4bDropdownMenuItem key={label}>
                  {label}
                </ParityExtWave4bDropdownMenuItem>
              ))}
            </ParityExtWave4bDropdownMenuContent>
          </ParityExtWave4bDropdownMenu>
        </div>
      );
    }
    case "filter-menu-trigger": {
      const ft = parityExtWave4bFixture.filterTrigger;
      return (
        <div
          data-visual-case={caseId}
          className="flex items-start bg-layer-canvas p-4"
          style={{ width: 320 }}
        >
          <ParityExtWave4bSelect value="all">
            <ParityExtWave4bSelectTrigger
              aria-label={ft.title}
              data-testid="wave4b-filter-trigger"
              render={<ParityExtWave4bPickerTriggerButton type="button" />}
            >
              <span>{ft.label}</span>
              <ParityExtWave4bSelectIcon data-picker-trigger-indicator="">
                <ParityExtWave4bChevronDown aria-hidden />
              </ParityExtWave4bSelectIcon>
            </ParityExtWave4bSelectTrigger>
          </ParityExtWave4bSelect>
        </div>
      );
    }
    default:
      throw new Error(`Unknown legacy-wave4b surface: ${surface}`);
  }
}

function parityExtLegacyWave4bElement(): ParityExtWave4bElement | null {
  const id = requestedCaseId();
  const m =
    /^components\.legacy-wave4b\.([\w-]+)\.(desktop|phone)\.(brutal|elegant-dark)$/.exec(
      id,
    );
  return m ? parityExtLegacyWave4bRender(m[1], m[2], id) : null;
}
