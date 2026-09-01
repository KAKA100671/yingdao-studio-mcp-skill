# 完成闸门：诊断、调试与修复闭环

- DocId: `wiki/guides/diagnostics/completion-gate`
- Source: `guides/diagnostics/completion-gate.md`
- Tags: `diagnostics`, `static-validation`, `completion`, `debugging`, `repair`
- UpdatedAt(UTC): 08/14/2026 10:54:28

---

# 完成闸门：诊断、调试与修复闭环

本页是 CodeFlow、VisualFlow 与混合 Flow 构建和修复时的统一验证合同。Authoring Wiki 只负责各 Flow 类型的编写规范，本页负责从诊断、运行、取证到修复完成的循环。

## 完成条件

在 Build 场景中，满足以下条件前不得宣告完成：

1. `diagnostics.snapshot.static_errors` 中与本次修改相关的静态错误为 0。
2. 需要运行行为证明的场景已使用准确 `flow_id` 和最小代表性输入完成运行。
3. `app.run_result(run_id=app.run 返回值)`、日志、变量快照或外部可见结果足以证明用户验收标准成立。
4. 临时调试输入和调试日志已经清理，清理后的最终实现再次通过必要验证。

## 诊断与修复循环

1. 修改后先执行 `diagnostics.snapshot`，`static_errors` 未清零时不进入运行验证。
2. 使用准确 `flow_id` 调用 `app.run`。若返回超时，继续用 `app.wait_run_finish(run_id=app.run 返回值)` 等待同一个运行，不要启动重复运行。
3. 运行结束后读取 `app.run_result(run_id=app.run 返回值)` 与新的 `diagnostics.snapshot`；需要完整时间线时读取 `app.logs`，需要 block 级输入输出时读取 `flow.get_variable_snapshots`。
4. 将问题定位到最接近失败的参数、源码、block、Selector、数据边界或环境前置条件。涉及未确认的 SDK、字段或返回结构时先读取对应 Wiki。
5. 现有证据不足以区分根因时，可以在关键边界增加最少量临时调试日志，再用相同的最小代表性场景运行一次。
6. 根据新证据修改能够解释失败的最小边界，然后重新执行静态诊断和运行验证。
7. 重复步骤 3 至 6，直到验收通过，或出现需要用户操作、外部状态变化或额外授权的真实阻塞。实现、输入和外部状态均未变化时，重复运行不构成修复循环。

## 调试日志

调试日志用于缩小问题范围，不用于替代流程结果：

- 优先记录高信息量边界：输入归一化结果、关键外部调用前后、分支选择、循环汇总、疑似错误值产生处和异常上下文。
- VisualFlow 使用 `programing.log`，并按其最新实例 form 插入和填写；CodeFlow 使用工程已有且 Wiki 已确认的日志 API。不要为调试虚构 SDK。
- 日志包含业务阶段和必要关键值；大对象、长列表和响应正文只记录类型、长度、关键字段及限长预览。
- 不记录 Cookie、Token、密码、验证码、Authorization、个人敏感数据或与问题无关的完整业务数据。
- 不使用 JSON marker、特殊前缀或日志文本承担机器结果传输。
- 问题修复后删除纯临时日志；对后续运行仍有诊断价值的阶段、计数和异常日志可以保留。

相关文档：

- `wiki/xbot_sdk/logging`

## 证据选择

诊断只依赖用户可见、可复现且能够在修改后再次验证的事实：Studio 中的 Flow、CodeFlow 源码和实例 form，`diagnostics.snapshot`，本次运行状态与结果，应用日志以及 VisualFlow 变量快照。不要要求用户提供内部调试产物、研发专用文件或未发布能力作为前置条件。

| 需要确认的事实 | 首选证据 |
| --- | --- |
| 当前应用的静态错误与最近运行异常 | `diagnostics.snapshot` |
| 本次运行是否启动、完成或成功 | `app.run` / `app.wait_run_finish(run_id=app.run 返回值)` |
| Flow 业务结果 | `app.run_result(run_id=app.run 返回值)` |
| 完整运行时间线和调试日志 | `app.logs` |
| 具体 block 的输入与输出 | `flow.get_variable_snapshots` |
| SDK、字段、返回结构或领域语义 | 对应 Wiki 文档 |

## 高频数据边界

### VisualFlow 变量不存在

- VisualFlow 静态校验只把 Flow 参数、`programing.variable` 和 block 显式 output 识别为变量生产者。Python 表达式或代码片段中的局部赋值不会创建可视化变量。
- 出现“变量不存在”时，先定位首次消费位置，再在实际执行路径上通过参数、`programing.variable` 或上游 output 产生同名变量；重新执行 `diagnostics.snapshot`，静态错误清零后再运行。

### JSON、文本与字节

- `json.loads(x)` 只接收 JSON `str`、`bytes` 或 `bytearray`；已有 `dict` / `list` 不再解析。
- `json.dumps(obj, ensure_ascii=False)` 将 Python 对象变成 JSON 文本；文本转字节使用 `.encode("utf-8")`，字节转文本使用 `.decode("utf-8")`。Base64 编码先得到 bytes，再 `.decode("ascii")`；解码顺序相反。
- 类型不明时在最接近来源的位置记录类型、长度、关键字段和限长预览，不打印完整对象，也不猜测字段路径。对于 `any` 输出，优先读取实例合同和变量快照；仍无法确认时用隔离的最小探测流程取得真实结构，结论稳定后再消费。

## 真实阻塞

以下情况可以暂停循环并请求用户介入：

- 登录、扫码、验证码、MFA 或其它必须由用户完成的交互。
- 支付、提交、删除、发送消息等不可逆或高风险副作用缺少授权。
- 缺少会改变业务实现或验收结果的用户选择、凭据或输入。
- 外部服务持续不可用，且当前工程内没有可验证的修复路径。
- 修复会改变用户目标、数据范围、风险或副作用边界。

除此之外，运行失败、日志不足或第一次修复未生效都不是停止条件，应继续取证和迭代。

## 常见误区

1. 静态错误尚未清零就开始运行或宣布完成。
2. 未显式传 `flow_id`，导致运行了错误流程。
3. 实现和输入没有变化，只是反复重跑同一失败场景。
4. 在每个步骤打印大量数据，使真正的失败信号被日志噪声淹没。
5. 只看到一条成功日志，没有核对业务结果和用户验收标准。
6. 修复后保留临时输入或临时日志，却没有对清理后的最终版本重新验证。
