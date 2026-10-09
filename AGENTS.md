# Raft Flutter 工程约定

- 本仓库为独立 Flutter 客户端；Web参照版本记录于 docs/source-reference.json。实现前阅读 docs/architecture.md 和当前用户指令。
- raft_ui 只拥有设计tokens与交互组件，不依赖API/数据库/原生系统服务。每个新组件同时提供 SDK Widget Preview 和适用的主题、状态、键盘、语义验收。
- 客户端协议、同步reducer、持久化、平台服务与业务页面分离。Flutter chat UI 的 model/controller 是展示适配，不是Raft消息或同步权威。
- 公共 source mirror 的 experimental/未挂载合同不能当现网接口。以已挂载服务端路径与 Web 当前启用行为验证。
- 测试使用命名隔离本地环境，Web与Flutter共用fixture。保护其他服务/dirty files；不提交登录资料、token、私有URL或本地seed输出。
- 按功能矩阵报告实际覆盖；Widget Preview 不能替代Linux/Android平台无障碍、输入法、生命周期或通知测试。

- 原生流程遇到等待超时、点击未生效或未命中时，先用实际可见控件和真实指针输入复现，区分产品丢事件/延迟反馈与测试尚未完成布局，再决定修改产品或测试；保留初次失败。等待条件不能掩盖已经显示的控件丢点击。
