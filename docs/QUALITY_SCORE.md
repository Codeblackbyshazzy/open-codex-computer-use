# 质量评分

## 评分标准

- `A`：覆盖完整、行为稳定、文档清楚、运行风险低。
- `B`：整体可接受，但还有明确短板。
- `C`：能用，但需要针对性补强。
- `D`：脆弱、缺少规范，或很多行为尚未定义。

## 当前水位

| 区域 | 评分 | 原因 | 下一步 |
| --- | --- | --- | --- |
| 产品面 | B | 已经有 Swift 本地 `computer-use` MCP server、默认 app 模式权限引导，以及 9 个 tools 的可运行实现。 | 继续收敛权限 UI 细节、app allowlist 和更清晰的用户错误提示。 |
| 架构文档 | B | 顶层结构、fixture bridge、app 模式和验证路径已经落文档。 | 后续补 release artifact、code signing / notarization 和 host 集成方式。 |
| 测试 | B | `swift test` + smoke suite 已覆盖 9 个 tools 的回归，并补了真实 `doctor` / `snapshot` spot check。 | 增加更多普通 app 的手工或录制回归，减少只依赖 fixture。 |
| 可观测性 | C | 已有 `doctor`、`snapshot` 和 smoke 输出，但还没有结构化日志。 | 补统一日志级别、失败上下文和 release artifact 里的诊断信息。 |
| 安全 | B | 已明确本地-only、权限边界和 fixture test bridge 的作用域。 | 增加 app allowlist / session approval，避免对任意 app 默认开放。 |
