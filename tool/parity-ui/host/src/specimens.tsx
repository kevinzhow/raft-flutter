// raft-ui 0.7.1 specimens. Every specimen is real @botiverse/raft-ui markup;
// where the component's doc page (https://raft-design.botiverse.build/components/<name>.md)
// has preview code it is used as written (named in the comment), the rest are
// the documented variants/states laid out in plain flex rows with no labels,
// so a Flutter preview reproduces the layout from this file alone.
import type { ComponentType } from "react";
import { Activity, AppWindow, AtSign, Bell, Bookmark, Columns3, Inbox, Info, Languages, List, Moon, OctagonAlert, Plus, Search, Send } from "lucide-react";
import {
  Avatar, AvatarBadge, AvatarFallback, AvatarImage,
  Badge, Button,
  Checkbox, CheckboxIndicator,
  IconTile, Input,
  ListRow, ListRowBody, ListRowBottom, ListRowChevron, ListRowDescription, ListRowGroup, ListRowIcon,
  ListRowMeta, ListRowTitle, ListRowTop, ListRowValue,
  SegmentedControl, SegmentedControlCount, SegmentedControlItem, SegmentedControlLabel,
  Status, Switch,
  Tabs, TabsList, TabsPanel, TabsTab,
} from "@botiverse/raft-ui";
import { pixelAvatarUrl } from "./pixelAvatar";

const noop = () => {};

function Row({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return <div className={`flex flex-wrap items-center gap-3 ${className}`}>{children}</div>;
}
function Stack({ children }: { children: React.ReactNode }) {
  return <div className="flex flex-col gap-4">{children}</div>;
}

// --- Button ---------------------------------------------------------------

function ButtonVariants() {
  return (
    <Stack>
      {/* ButtonPreviewContent */}
      <Row><Button size="md">Button</Button></Row>
      <Row>
        <Button variant="primary">Send</Button>
        <Button variant="default">Assign</Button>
        <Button variant="ghost">Cancel</Button>
      </Row>
      <Row>
        <Button variant="warning">Stop Wug</Button>
        <Button variant="danger">Delete Agent</Button>
      </Row>
      {/* on-frame sits on the yellow frame (ButtonOnFrameComposition's container) */}
      <div className="flex items-center gap-1 rounded-control bg-layer-frame p-1.5">
        <Button variant="on-frame">Acme</Button>
        <Button variant="on-frame" size="icon-md" aria-label="Search"><Search /></Button>
      </div>
    </Stack>
  );
}

function ButtonSizes() {
  return (
    <Stack>
      <Row>
        <Button size="md">Medium</Button>
        <Button size="lg">Large</Button>
      </Row>
      <Button size="xl" variant="primary" className="w-full">Create Account</Button>
      <Row>
        <Button size="md"><Plus data-icon="inline-start" />New Task</Button>
        <Button size="md" variant="primary">Next<Send data-icon="inline-end" /></Button>
      </Row>
      <Row>
        <Button variant="ghost" size="icon-lg" aria-label="Search"><Search /></Button>
        <Button variant="ghost" size="icon-md" aria-label="Search"><Search /></Button>
        <Button variant="default" size="icon-md" aria-label="Add"><Plus /></Button>
        <Button variant="primary" size="icon-md" aria-label="Send"><Send /></Button>
        <Button variant="default" size="icon-lg" aria-label="Add"><Plus /></Button>
      </Row>
    </Stack>
  );
}

function ButtonStates() {
  return (
    <Stack>
      <Row>
        <Button variant="primary" disabled>Send</Button>
        <Button variant="default" disabled>Assign</Button>
        <Button variant="ghost" disabled>Cancel</Button>
      </Row>
      <Row>
        <Button variant="warning" disabled>Stop Wug</Button>
        <Button variant="danger" disabled>Delete Agent</Button>
        <Button variant="ghost" size="icon-md" aria-label="Search" disabled><Search /></Button>
      </Row>
      <Row>
        <Button variant="primary" loading loadingLabel="Creating">Creating…</Button>
        <Button variant="default" loading loadingLabel="Saving">Saving…</Button>
      </Row>
    </Stack>
  );
}

// --- Badge / Status -------------------------------------------------------

const BADGE_VARIANTS = ["default", "primary", "accent", "warning", "danger", "information", "success", "muted"] as const;

function BadgeVariants() {
  return (
    <Stack>
      {/* The unread count and the @ marker: the two jobs Badge exists for. */}
      <Row>
        <Badge variant="accent" role="img" aria-label="1 unread">1</Badge>
        <Badge variant="accent" role="img" aria-label="12 unread">12</Badge>
        <Badge variant="primary" role="img" aria-label="Mentions you"><AtSign /></Badge>
      </Row>
      {(["solid", "soft", "outline"] as const).map((appearance) => (
        <Row key={appearance}>
          {BADGE_VARIANTS.map((variant) => (
            <Badge key={variant} appearance={appearance} variant={variant}>{variant}</Badge>
          ))}
        </Row>
      ))}
    </Stack>
  );
}

const PRESENCES = ["online", "busy", "error", "offline", "external"] as const;

function StatusLights() {
  return (
    <Stack>
      {/* StatusContent */}
      <Row><Status /></Row>
      <Row>
        {PRESENCES.map((presence) => <Status key={presence} presence={presence} aria-label={presence} role="img" />)}
      </Row>
      <Row>
        {(["xs", "sm", "md", "lg"] as const).map((size) => <Status key={size} size={size} presence="online" aria-label="Online" role="img" />)}
      </Row>
      <Row>
        {BADGE_VARIANTS.map((variant) => <Status key={variant} variant={variant} aria-hidden />)}
      </Row>
      {/* Agent state chips: a soft Badge holding a Status with its presence and word. */}
      <Row>
        {([["online", "Online"], ["busy", "Working"], ["error", "Error"], ["offline", "Offline"], ["external", "External agent"]] as const).map(([presence, word]) => (
          <Badge key={presence} appearance="soft" variant="default"><Status presence={presence} aria-hidden />{word}</Badge>
        ))}
      </Row>
    </Stack>
  );
}

// --- Avatar ---------------------------------------------------------------

function AvatarFaces() {
  return (
    <Stack>
      <Row>
        {(["robot", "crown", "mushroom"] as const).map((key) => (
          <Avatar key={key} size="lg" type="agent">
            <AvatarImage src={pixelAvatarUrl(key)} alt={key} />
            <AvatarFallback />
          </Avatar>
        ))}
        {/* AvatarPreviewContent: an agent whose pixel avatar has not loaded */}
        <Avatar size="lg" type="agent">
          <AvatarBadge render={<Status aria-hidden variant="success" />} />
        </Avatar>
      </Row>
      <Row>
        <Avatar size="lg" type="human"><AvatarFallback>MC</AvatarFallback></Avatar>
        <Avatar size="lg" type="human"><AvatarFallback>A</AvatarFallback></Avatar>
        {/* AvatarPanelHeaderContent without the photo: the placeholder icon */}
        <Avatar size="lg" type="human"><AvatarFallback /></Avatar>
        <Avatar size="lg" type="agent"><AvatarFallback>W</AvatarFallback></Avatar>
      </Row>
    </Stack>
  );
}

const AVATAR_SIZES = ["xs", "sm", "md", "lg", "xl"] as const;

function AvatarSizes() {
  return (
    <Stack>
      <div className="flex items-end gap-4">
        {AVATAR_SIZES.map((size) => (
          <Avatar key={size} size={size} type="agent">
            <AvatarImage src={pixelAvatarUrl("crown")} alt="Wug" />
            <AvatarFallback />
          </Avatar>
        ))}
      </div>
      <div className="flex items-end gap-4">
        {AVATAR_SIZES.map((size) => (
          <Avatar key={size} size={size} type="human"><AvatarFallback>MC</AvatarFallback></Avatar>
        ))}
      </div>
    </Stack>
  );
}

function AvatarPresence() {
  // AvatarBadgePresenceContent
  return (
    <div className="flex items-end gap-6">
      <Avatar size="md" type="agent">
        <AvatarFallback>W</AvatarFallback>
        <AvatarBadge role="img" aria-label="Online" />
      </Avatar>
      <Avatar size="md" type="agent">
        <AvatarFallback>B</AvatarFallback>
        <AvatarBadge presence="busy" role="img" aria-label="Working" />
      </Avatar>
      <Avatar size="md" type="agent">
        <AvatarFallback>M</AvatarFallback>
        <AvatarBadge presence="error" role="img" aria-label="Error" />
      </Avatar>
      <Avatar size="md" type="human">
        <AvatarFallback>MC</AvatarFallback>
        <AvatarBadge presence="offline" role="img" aria-label="Offline" />
      </Avatar>
      <Avatar size="md" type="agent">
        <AvatarFallback>R</AvatarFallback>
        <AvatarBadge presence="external" role="img" aria-label="External agent" />
      </Avatar>
    </div>
  );
}

// --- Form controls --------------------------------------------------------

function InputStates() {
  return (
    <Stack>
      {/* InputPreviewContent, full width of the frame */}
      <Input className="w-full" placeholder="you@example.com" />
      <Input className="w-full" defaultValue="mia@botiverse.build" />
      <Input className="w-full" defaultValue="not-an-email" data-invalid />
      <Input className="w-full" placeholder="you@example.com" disabled />
      <Input className="w-full" defaultValue="mia@botiverse.build" disabled />
    </Stack>
  );
}

function SwitchStates() {
  return (
    <Stack>
      <Row>
        <Switch aria-label="Off" />
        <Switch defaultChecked aria-label="On" />
        <Switch disabled aria-label="Off, disabled" />
        <Switch disabled defaultChecked aria-label="On, disabled" />
      </Row>
    </Stack>
  );
}

function CheckboxStates() {
  return (
    <Stack>
      {/* CheckboxPreviewContent, then unchecked / indeterminate / disabled */}
      <Row>
        <Checkbox checked aria-label="Checked" />
        <Checkbox aria-label="Unchecked" />
        <Checkbox indeterminate aria-label="Mixed" />
        <Checkbox disabled aria-label="Disabled" />
        <Checkbox disabled checked aria-label="Disabled checked" />
        <Checkbox shape="circle" checked aria-label="Circle checked" />
        <Checkbox shape="circle" aria-label="Circle" />
      </Row>
      {/* CheckboxSettingsGroupContent */}
      <div className="grid min-w-60 gap-2 text-sm">
        <label className="flex items-center gap-3">
          <Checkbox defaultChecked aria-label="Include recent messages" />
          <span>Recent messages</span>
        </label>
        <label className="flex items-center gap-3">
          <Checkbox defaultChecked aria-label="Include activity log" />
          <span>Activity log</span>
        </label>
        <label className="flex items-center gap-3">
          <Checkbox aria-label="Include trajectory log" />
          <span>Trajectory log</span>
        </label>
      </div>
      {/* CheckboxIndicatorContent */}
      <div className="flex items-center gap-4">
        <CheckboxIndicator checked={false} />
        <CheckboxIndicator checked />
        <CheckboxIndicator checked mark="minus" />
        <CheckboxIndicator checked shape="circle" />
        <CheckboxIndicator checked disabled />
      </div>
    </Stack>
  );
}

// --- Navigation and rows --------------------------------------------------

function TabsVariants() {
  return (
    <Stack>
      {(["default", "underline"] as const).map((variant) => (
        <Tabs key={variant} defaultValue="general" className="gap-3">
          <TabsList variant={variant}>
            <TabsTab value="general">General</TabsTab>
            <TabsTab value="members">Members</TabsTab>
            <TabsTab value="activity">Activity</TabsTab>
          </TabsList>
          <TabsPanel value="general" className="p-3 text-xs text-foreground-muted">Name, topic, and description of #design-review.</TabsPanel>
          <TabsPanel value="members" className="p-3 text-xs text-foreground-muted">12 members, 3 agents.</TabsPanel>
          <TabsPanel value="activity" className="p-3 text-xs text-foreground-muted">Activity in #design-review.</TabsPanel>
        </Tabs>
      ))}
    </Stack>
  );
}

function SegmentedControlStates() {
  return (
    <Stack>
      {/* SegmentedControlViewModeComposition */}
      <SegmentedControl aria-label="Task view" value="board" onValueChange={noop}>
        <SegmentedControlItem value="board"><Columns3 /><SegmentedControlLabel>Board</SegmentedControlLabel></SegmentedControlItem>
        <SegmentedControlItem value="list"><List /><SegmentedControlLabel>List</SegmentedControlLabel></SegmentedControlItem>
      </SegmentedControl>
      {/* SegmentedControlFiltersComposition */}
      <SegmentedControl aria-label="Filter messages" value="all" onValueChange={noop}>
        <SegmentedControlItem value="all"><Inbox /><SegmentedControlLabel>All</SegmentedControlLabel><SegmentedControlCount>12</SegmentedControlCount></SegmentedControlItem>
        <SegmentedControlItem value="unread"><SegmentedControlLabel>Unread</SegmentedControlLabel><SegmentedControlCount>3</SegmentedControlCount></SegmentedControlItem>
        <SegmentedControlItem value="mentions"><AtSign /><SegmentedControlLabel>Mentions</SegmentedControlLabel></SegmentedControlItem>
      </SegmentedControl>
      {/* SegmentedControlDisabledComposition */}
      <SegmentedControl disabled aria-label="Translation mode" value="translated" onValueChange={noop}>
        <SegmentedControlItem value="translated"><Languages /><SegmentedControlLabel>Translated</SegmentedControlLabel></SegmentedControlItem>
        <SegmentedControlItem value="original"><SegmentedControlLabel>Original</SegmentedControlLabel></SegmentedControlItem>
      </SegmentedControl>
    </Stack>
  );
}

function ListRowVariants() {
  return (
    <Stack>
      {/* ListRowConversationsComposition, "wug" open */}
      <div className="w-full">
        <ListRow value="wug" tone="unread" selected aria-current>
          <Avatar size="md" type="agent">
            <AvatarFallback>W</AvatarFallback>
            <AvatarBadge role="img" aria-label="Online" />
          </Avatar>
          <ListRowBody>
            <ListRowTop><ListRowTitle>Wug</ListRowTitle><ListRowMeta>10:40</ListRowMeta></ListRowTop>
            <ListRowBottom>
              <ListRowDescription>Draft is in #launch-week.</ListRowDescription>
              <Badge variant="accent" role="img" aria-label="1 unread">1</Badge>
            </ListRowBottom>
          </ListRowBody>
        </ListRow>
        <ListRow value="martin" tone="unread">
          <Avatar size="md" type="agent"><AvatarFallback>M</AvatarFallback></Avatar>
          <ListRowBody>
            <ListRowTop><ListRowTitle>Martin</ListRowTitle><ListRowMeta>10:31</ListRowMeta></ListRowTop>
            <ListRowBottom>
              <ListRowDescription>Bugen claimed #25 Polish onboarding flow</ListRowDescription>
              <Badge variant="primary" role="img" aria-label="Mentions you"><AtSign /></Badge>
            </ListRowBottom>
          </ListRowBody>
        </ListRow>
        <ListRow value="mia">
          <Avatar size="md" type="human"><AvatarFallback>MC</AvatarFallback></Avatar>
          <ListRowBody>
            <ListRowTop><ListRowTitle>Mia Chen</ListRowTitle><ListRowMeta>Tue</ListRowMeta></ListRowTop>
            <ListRowBottom><ListRowDescription>Can we try the yellow tab bar?</ListRowDescription></ListRowBottom>
          </ListRowBody>
        </ListRow>
      </div>
      {/* ListRowSettingsComposition with Appearance = System, merge = off */}
      <ListRowGroup className="w-full">
        <ListRow variant="plain">
          <ListRowIcon><Moon /></ListRowIcon>
          <ListRowBody><ListRowTitle>Appearance</ListRowTitle></ListRowBody>
          <ListRowValue>System</ListRowValue>
          <ListRowChevron />
        </ListRow>
        <ListRow variant="plain" interactive={false}>
          <ListRowIcon><Bell /></ListRowIcon>
          <ListRowBody>
            <ListRowTitle id="list-row-agents-merge">Agents can merge to main</ListRowTitle>
            <ListRowDescription wrap>Off: a person approves every merge.</ListRowDescription>
          </ListRowBody>
          <Switch checked={false} onCheckedChange={noop} aria-labelledby="list-row-agents-merge" />
        </ListRow>
      </ListRowGroup>
      {/* ListRowEntriesComposition, "activity" open */}
      <div className="w-full">
        <ListRow variant="entry">
          <ListRowIcon><Search /></ListRowIcon>
          <ListRowBody><ListRowTitle>Search</ListRowTitle></ListRowBody>
        </ListRow>
        <ListRow variant="entry" selected aria-current>
          <ListRowIcon><Activity /></ListRowIcon>
          <ListRowBody><ListRowTitle>Activity</ListRowTitle></ListRowBody>
          <Badge variant="accent" role="img" aria-label="4 unread">4</Badge>
        </ListRow>
        <ListRow variant="entry">
          <ListRowIcon><Bookmark /></ListRowIcon>
          <ListRowBody><ListRowTitle>Saved</ListRowTitle></ListRowBody>
          <ListRowMeta>7</ListRowMeta>
        </ListRow>
      </div>
    </Stack>
  );
}

function IconTileVariants() {
  return (
    <Stack>
      {/* IconTileSizesComposition */}
      <div className="flex items-center gap-4">
        {(["xs", "sm", "md", "lg"] as const).map((size) => <IconTile key={size} size={size}><AppWindow /></IconTile>)}
      </div>
      {/* IconTileVariantsComposition */}
      <div className="flex items-center gap-4">
        <IconTile role="img" aria-label="App"><AppWindow /></IconTile>
        <IconTile variant="warning" role="img" aria-label="Error"><OctagonAlert /></IconTile>
        <IconTile variant="information" role="img" aria-label="Message"><Info /></IconTile>
      </div>
    </Stack>
  );
}

export const SPECIMENS: Record<string, ComponentType> = {
  "button.variants": ButtonVariants,
  "button.sizes": ButtonSizes,
  "button.states": ButtonStates,
  "badge.variants": BadgeVariants,
  "status.lights": StatusLights,
  "avatar.faces": AvatarFaces,
  "avatar.sizes": AvatarSizes,
  "avatar.presence": AvatarPresence,
  "input.states": InputStates,
  "switch.states": SwitchStates,
  "checkbox.states": CheckboxStates,
  "tabs.variants": TabsVariants,
  "segmented-control.states": SegmentedControlStates,
  "list-row.variants": ListRowVariants,
  "icon-tile.variants": IconTileVariants,
};
