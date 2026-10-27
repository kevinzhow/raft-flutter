# SignPath Foundation：先接通 TEST 签名

资格获批不等于正式证书已签发。默认手动工作流只构建未签名样本；
只有显式选择提交、环境开关开启且 TEST 配置完整时，才会申请测试签名。

## 账号负责人操作顺序

1. 按获批邮件先创建／登录对应 SignPath 账号，再接受 OSS organization 邀请，最后按邮件要求确认 CI。不要把 token 发到聊天或写进源码。
2. 在获批 project 中先选择并核对邮件所说的已提供 self-signed **Test** 证书，确认 Purpose=Test，记录公开 SHA1 thumbprint。只有没有适用的已提供测试证书时，才新建 self-signed Test 证书。创建 test-signing policy，Purpose 同样选 Test，关联所选测试证书。正式 release 证书先不接入。[证书与 Purpose 说明](https://docs.signpath.io/managing-certificates)
3. 创建 windows-runner-test artifact configuration，导入 [XML](../tool/signpath/windows-runner-test.xml)。只匹配 ZIP 根的一份 raft_flutter.exe，核对 ProductName=Raft、CompanyName=app.raft、OriginalFilename；不匹配 Microsoft runtime、Flutter engine、WinSparkle 等供应商 DLL。[XML 结构](https://docs.signpath.io/artifact-configuration/syntax)、[PE metadata](https://docs.signpath.io/artifact-configuration/reference)
4. 组织中配置 GitHub.com Trusted Build System 并关联 project；按官方接线要求安装 SignPath GitHub App，仅授予 kevinzhow/raft-flutter。project repository URL 对应该仓库；policy 启用 Verify origin，Allowed branch names 只填 cindy/integration。核对请求的仓库、commit、workflow 和全部 GitHub-hosted jobs。[GitHub 接线](https://docs.signpath.io/trusted-build-systems/github)、[来源核验](https://docs.signpath.io/origin-verification/)
5. 创建仅能提交该 project／Test policy 的专用 submitter token。GitHub 建立 signpath-test environment，限制 integration 分支，由负责人配置下表。可加 required reviewer；工作流不自行创建审批规则。

| 类型 | 名称 | 内容 |
| --- | --- | --- |
| Variable | SIGNPATH_TEST_ENABLED | 配置核对完成后填 true |
| Variable | SIGNPATH_TEST_ORGANIZATION_ID | 组织 UUID；全零占位值会拒绝 |
| Variable | SIGNPATH_TEST_PROJECT_SLUG | 获批 project 的实际 slug |
| Variable | SIGNPATH_TEST_POLICY_SLUG | test-signing |
| Variable | SIGNPATH_TEST_ARTIFACT_SLUG | windows-runner-test |
| Variable | SIGNPATH_TEST_CERTIFICATE_SHA1 | self-signed Test 证书的 40 位公开指纹，无空格 |
| Secret | SIGNPATH_TEST_API_TOKEN | 专用 submitter token；只在 GitHub 保存 |

配置准备和本地单测无需实际 secret。真正提交时官方 action 需要 API token；
本方案没有“无需 token”的替代通道，也没有读取现有 secret 值。

## 第一次运行如何核对

代码审核并合入后，在 **SignPath Windows TEST certificate probe** 选择 integration。
先保持 submit_test_signing=false：仅用固定 SDK 构建 x64 runner，上传未签名 GitHub artifact。
样本不启动 App、不登录账号、不构建或发布 Inno installer／portable ZIP，也不调用发布工具。

确认 XML 与 sample 后，新建手动运行并勾选 submit_test_signing=true。
不要 rerun 旧 run，工作流只接受 attempt1。upload-artifact 自带外层 ZIP，
根是 runner 本身；不要再把 portable ZIP 放进去。官方 action 绑定同次 upload 的
artifact-id，不使用本机文件地址、其他 run 或 Release 附件。
独立链全部使用 GitHub-hosted Windows runner，没有复用现有含自托管平台的发布矩阵。

固定官方 SignPath v3 commit 为 f6d04783b4569d051e0c80105fe66e82819d0092：
[官方固定 action](https://github.com/SignPath/github-action-submit-signing-request/tree/f6d04783b4569d051e0c80105fe66e82819d0092)。
只授予 contents:read、actions:read，不暴露 checkout 凭据，不打印签名下载 URL。

下载后比较 PE 原始内容，只允许 checksum／certificate-directory 改动和追加一份证书；
再在 Windows 核对 CMS 签名、Authenticode SHA256 和指定 self-signed Test 证书。
不把证书装进系统 trust store，因此系统信任状态可能仍为 untrusted；
这与“正式发行可受信”不同。证据留在独立 signpath-test-* artifacts。
真实 Windows 构建、SignPath 受理及返回签名验证都要在首次 CI 后实际判定。

## 以后接入正式发行

当前单 runner 样本只验证 Trusted Build 接线，尚未解决实际插件 DLL 被拦截的问题。
生产接入前要枚举本次自行构建的 runner／原生 plugin PE 与 installer，逐项决定签名范围；
供应商已有签名保持原样，不能用整包通配符替代此清单。

现有 Windows release workflow、portable ZIP、Inno installer、manifest、
appcast/feed 与 Ed25519 发布签名保持不变。正式证书在设置审核完成并获发后另行接入。
届时先签入包的自有 PE，再重新打包 portable／installer，再签 installer，
最后生成最终 SHA／manifest、feed 和 Ed25519 签名；不能继续发布签名前的旧 hash 或旧归档。
第三方 PE 应逐项保留／验证原签名，不把整包 DLL 交给 Raft 证书重签。

## 本地检查

    python3 -m unittest discover -s tool/tests -p test_signpath_test.py -v

只测来源限制、占位配置拒绝、exact runner staging、供应商排除、PE 篡改拒绝与配置边界。
不提交签名、不访问账号、不构建 Flutter、不操作证书存储。
PowerShell 的 CMS／系统 API 路径仍等待真实 Windows TEST run；此文不是已执行签名收据。
