"""Web 1.24 call shapes for tool/capability_parity.py: the false alarms of the v1.21.23 -> v1.24.0 report.

- `getRwRead(surface, url)` (api/overloadRetry.ts) took over three unread reads: they looked removed.
- Three files define `BASE`; the last one read won for every file, so the second-factor calls
  showed as `/me/account/deletion/*` and the assistant calls as `/s/:id/thread-window/*`.
- Artifacts, objects and mention-audience calls build their path with the shared contracts'
  path builders (`artifactWebPaths.viewer(id)`) behind local wrappers: they were `UNRESOLVED:route`.
"""
import importlib.util
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    'capability_parity', Path(__file__).resolve().parents[1] / 'capability_parity.py')
cp = importlib.util.module_from_spec(SPEC)
sys.modules['capability_parity'] = cp
SPEC.loader.exec_module(cp)


def make_tree(web, shared=None):
    root = tempfile.mkdtemp()
    for base, files in (('packages/web/src', web), ('packages/shared/src', shared or {})):
        for rel, text in files.items():
            path = Path(root, base, rel)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding='utf-8')
    return root


class V124Tests(unittest.TestCase):
    def keys(self, web, shared=None):
        root = make_tree(web, shared)
        self.addCleanup(lambda: shutil.rmtree(root))
        return cp.keys(cp.extract_web(root))

    def test_get_rw_read_takes_the_path_from_its_second_argument(self):
        got = self.keys({
            'api/overloadRetry.ts': (
                'export const getWithRwOverloadRetry = (async (url: string) => api.get(url)) as typeof api.get;\n'
                'export async function getRwRead<T = unknown>(\n  surface: RwSurface,\n  url: string,\n): Promise<T> {\n'
                '  const response = await getWithRwOverloadRetry(url, config);\n}\n'),
            'store/messageStore.ts': (
                'import { getRwRead } from "../api/overloadRetry";\n'
                'const { data } = await getRwRead<unknown>("unread", "/channels/unread", { params: { summary: 1 } });\n'
                'const t = await getRwRead<{ threads: X[] }>("followed", "/channels/threads/followed", {\n  params: {},\n});\n'),
        })
        self.assertEqual(got, ['GET /channels/threads/followed', 'GET /channels/unread'])

    def test_each_file_reads_its_own_base_constant(self):
        got = self.keys({
            'features/settings/account/accountDeletionApi.ts': (
                'const BASE = "/me/account/deletion";\nexport const f = () => api.get(`${BASE}/status`);\n'),
            'components/settings/secondFactorApi.ts': (
                'const BASE = "/auth/second-factor";\nexport async function s() { await api.get(`${BASE}/status`); }\n'
                'export async function e() { await api.post(`${BASE}/enable`, {}); }\n'),
            'components/auth/secondFactorRecovery.ts': (
                'const BASE = "/auth/second-factor/recovery";\nexport const r = () => api.post(`${BASE}/confirm`, {});\n'),
        })
        self.assertEqual(got, ['GET /auth/second-factor/status', 'GET /me/account/deletion/status',
                               'POST /auth/second-factor/enable', 'POST /auth/second-factor/recovery/confirm'])

    def test_a_parameter_never_picks_up_another_files_constant(self):
        got = self.keys({
            'a.ts': 'const url = `/servers/${s}/limit-resets/read`;\napi.get(url);\n',
            'b.ts': 'async function postOnce(url: string) {\n  await api.post(url, {});\n}\n',
        })
        self.assertEqual(got, ['GET /servers/:id/limit-resets/read', 'POST UNRESOLVED:url'])

    def test_arrow_helpers_resolve(self):
        got = self.keys({
            'g.ts': (
                'const grantsPath = (serverId: string) => `/servers/${serverId}/agent-context-view-grants`;\n'
                'const machinePath = (serverId: string, machineId: string) =>\n'
                '  `/servers/${encodeURIComponent(serverId)}/machines/${encodeURIComponent(machineId)}`;\n'
                'api.get(grantsPath(serverId));\n'
                'api.delete(`${grantsPath(serverId)}/${grantId}`);\n'
                'api.post(`${machinePath(s, m)}/revoke-computer-key`);\n'),
        })
        self.assertEqual(got, ['DELETE /servers/:id/agent-context-view-grants/:id', 'GET /servers/:id/agent-context-view-grants',
                               'POST /servers/:id/machines/:id/revoke-computer-key'])

    def test_path_builders_behind_local_wrappers(self):
        shared = {
            'webArtifactsContract.ts': (
                'const enc = encodeURIComponent;\n'
                'const versionQuery = (version?: number) => query({ version });\n'
                '/** Every web route for Artifacts. It can\'t be built elsewhere. */\n'
                'export const artifactWebPaths = {\n'
                '  /** GET the viewer (can\'t open: 404). */\n'
                '  viewer: (id: ArtifactId, version?: number) => `/api/artifacts/${enc(id)}${versionQuery(version)}`,\n'
                '  comments: (id: ArtifactId, options: { before?: string; path?: string } = {}) => `/api/artifacts/${enc(id)}/comments${query(options)}`,\n'
                '  subscription: (id: ArtifactId) => `/api/artifacts/${enc(id)}/subscription`,\n'
                '  open: (id: ArtifactId, options: { version?: number } = {}) => `/api/artifacts/${enc(id)}/open${query(options)}`,\n'
                '  reviewSubmit: (id: ArtifactId) => `/api/artifacts/${enc(id)}/review/submit`,\n'
                '  file: (id: ArtifactId, path: string) => `/api/artifacts/${enc(id)}/files/${enc(path)}`,\n'
                '  linkOnly: (id: ArtifactId) => `/api/artifacts/${enc(id)}/link-only`,\n'
                '} as const;\n'),
            'webObjectsContract.ts': 'export const objectWebPaths = {\n  summaries: () => "/api/objects/summaries",\n} as const;\n',
            'index.ts': 'export * from "./webArtifactsContract";\n',
        }
        web = {
            'apps/artifacts/apiArtifactSource.ts': (
                'import { artifactWebPaths } from "@botiverse/raft-shared";\n'
                'function route(path: string): string {\n  return path.replace(/^\\/api(?=\\/)/, "");\n}\n'
                'async function call<T>(config: AxiosRequestConfig): Promise<T> {\n'
                '  const { data } = await api.request<T>({ ...config, url: route(config.url ?? "") });\n  return data;\n}\n'
                'const get = <T>(url: string) => call<T>({ method: "GET", url });\n'
                'async function getBlob(url: string): Promise<Blob> {\n  const r = await api.get<Blob>(route(url), {});\n}\n'
                'const send = <T>(method: "POST" | "PUT" | "DELETE", url: string) => call<T>({ method, url });\n'
                'export const source = {\n'
                '  viewer(id) { return viewerResultOf(() => get<ArtifactViewerData>(artifactWebPaths.viewer(id, 2))); },\n'
                '  comments(id, options) { return get<Page>(artifactWebPaths.comments(id, options)); },\n'
                '  post(id, input) { return send<Created>("POST", artifactWebPaths.comments(id), input); },\n'
                '  follow(id, following) { return send<{ following: boolean }>(following ? "PUT" : "DELETE", artifactWebPaths.subscription(id)); },\n'
                '  open(t) { return call<Open>({ method: "GET", url: artifactWebPaths.open(t.id, {}), headers: NO_SERVER }); },\n'
                '  async submit(id) { const { data } = await api.request<S>({ method: "POST", url: route(artifactWebPaths.reviewSubmit(id)), data: 1 }); },\n'
                '  file(f) { return getBlob(artifactWebPaths.file(f.id, f.path)); },\n'
                '};\n'
                '// GET `artifactWebPaths.linkOnly(id)` is only a link: <a href={artifactWebPaths.linkOnly(id)}>\n'
                'export type T = Parameters<typeof artifactWebPaths.comments>[1];\n'),
            'components/Link.tsx': (
                'import { artifactWebPaths } from "@botiverse/raft-shared";\n'
                'export const L = ({ id }) => <a href={artifactWebPaths.linkOnly(id)}>open</a>;\n'),
            'objects/objectSummaryLoader.ts': (
                'import { objectWebPaths } from "@botiverse/raft-shared";\n'
                'await api.post(objectWebPaths.summaries().replace(/^\\/api(?=\\/)/, ""), { kind, refs });\n'),
        }
        got = self.keys(web, shared)
        self.assertEqual(got, [
            'DELETE /artifacts/:id/subscription',
            'GET /artifacts/:id', 'GET /artifacts/:id/comments', 'GET /artifacts/:id/files/:id', 'GET /artifacts/:id/open',
            'POST /artifacts/:id/comments', 'POST /artifacts/:id/review/submit',
            'POST /objects/summaries',
            'PUT /artifacts/:id/subscription',
        ])

    def test_calls_in_comments_are_not_calls(self):
        got = self.keys({
            'api/client.ts': (
                '// api.post (before its storage is cleared) carries the old token\n'
                '/*\n * api.get("/nope")\n */\n'
                'api.get("/yes"); // api.delete("/also-nope")\n'),
        })
        self.assertEqual(got, ['GET /yes'])

    def test_nested_ternary_drops_the_nothing_asked_branches(self):
        got = self.keys({
            'components/member/useMemberRemovalImpact.ts': (
                'export function useMemberRemovalImpact(serverId: string | undefined, memberId: string | null) {\n'
                '  const path = memberId === null ? null : serverId && memberId ? `/servers/${serverId}/members/${memberId}/removal-impact` : "";\n'
                '  api.get<MemberRemovalImpact>(path, { timeout: 1 });\n}\n'),
            'store/translationStore.ts': (
                'api.post(state.publicTranslationSlug ? `/public/servers/${encodeURIComponent(state.publicTranslationSlug)}/message-translations:batch` : "/message-translations:batch", body);\n'),
        })
        self.assertEqual(got, ['GET /servers/:id/members/:id/removal-impact', 'POST /message-translations:batch',
                               'POST /public/servers/:id/message-translations:batch'])


if __name__ == '__main__':
    unittest.main()
