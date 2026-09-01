# App 变量与 Flow 参数传递

- DocId: `wiki/guides/flow-parameters`
- Source: `guides/flow-parameters.md`
- Tags: `glossary`, `app`, `variables`, `flow`, `parameters`
- UpdatedAt(UTC): 08/14/2026 10:54:28

---

# App 变量与 Flow 参数传递

本页是 App 变量、Flow 参数、跨 Flow 调用和结果传递的权威合同。当前工具 schema 决定写入参数，`flow.list_parameters` 与 `process.run` 的最新实例 form 决定当前工程中的实际接口。

## 数据边界

| 类型 | 作用域 | 使用边界 |
| --- | --- | --- |
| App 全局变量 | 当前 App 的所有 Flow | 只用于确有 App 级共享语义的状态；CodeFlow 中使用 `glv['name']` |
| Flow In 参数 | 一个 Flow 的公开输入 | 调用方显式传入，Flow 内按参数名消费 |
| Flow Out 参数 | 一个 Flow 的公开输出 | 被调用 Flow 生产，调用方通过结果对象读取 |
| Flow 内部变量 | 当前 Flow | 不得被其它 Flow 直接访问 |
| App 共享业务单元 | 当前 App | storage、数据表格等专用机制按各自合同读写 |

- 参数和变量只通过 Studio 能力声明或修改，不直接编辑工程文件。
- 参数的 `direction`、`type`、`kind`、默认值和限制以 `flow.write_parameters` 当前 schema 为准。
- 跨 Flow 数据只走显式 In/Out 合同或专用共享机制。名称相同不代表变量自动共享。
- 流程参数主要定义 Flow 被调用时的公开接口。主流程是应用入口且不能被其它 Flow 调用，不必仅为调用子流程、保存中间结果或完成直接运行而声明 In/Out 参数。
- 被调用的子流程需要跨 Flow 接收或返回数据时，声明所需 In/Out 参数。没有输入或只有副作用的子流程可以只声明实际需要的方向，不能为凑齐形式虚构参数。
- 主流程不通过 `app.run` 接收 In 参数；不要仅为直接运行或测试声明 In 参数。只有确实需要通过 `app.run_result(run_id=app.run 返回值)` 公开结构化结果时，才为主流程声明对应 Out 参数。

## CodeFlow 结果

CodeFlow 作为被调用的子流程时，使用显式 In/Out 参数合同；主 CodeFlow 直接运行时可以没有流程参数。

- VisualFlow 通过 `process.run` 调用 CodeFlow 时，可配置的输入和输出来自子 CodeFlow 已声明的 In/Out 参数。
- `process.run` 执行 `main(args)` 后，从传入的同一个 `args` 字典收集已声明的 Out 值；普通 Python return 不会自动成为父 Flow 可消费的 `process_result` 属性。
- 直接 `app.run(flow_id=<CodeFlow>)` 不改写原始 CodeFlow 源码，也不会注入参数面板中的默认 In 值；MCP 运行入口只透明捕获结果。CodeFlow 仅在参数容器为 `None` 时用 `if args is None: args = {}` 初始化，再用 `args.get("参数名", default_value)` 提供直接运行的 fallback；不能按 truthiness 替换一个有效的空容器，因为运行时会从同一个 `args` 对象收集声明的 Out 值。由主流程通过 `process.run` 调用时，声明的 In 参数传入值会覆盖 fallback。
- 主 CodeFlow 没有声明 Out 参数时，`app.run` 仍可验证执行状态；若 `main(args)` 有普通 Python return，MCP 结果会在实际捕获时通过 `result.return` 返回，否则应按实际验收目标检查日志、副作用或外部结果，不为获取诊断数据而虚构 Out 参数。
- 需要向调用方或 `app.run_result` 公开 CodeFlow 结果时，声明 Out 参数并在 `main(args)` 中写入 `args` 的同名 key。
- 跨 Flow 业务合同仍使用 Out 参数，不依赖 `return value` 给父 Flow 传值；`result.return` 是 MCP 对 CodeFlow Python return 的运行证据，不会替代 `process.run` 的 Out 参数映射。
- Out 参数名和 `args` key 必须一致；只写入未声明的 key 不会形成公开输出。

示例：子 CodeFlow 需要公开结果时，先声明 Out 参数 `result_text`，再写入同名 key：

```python
def main(args):
    result_text = "ok"
    args["result_text"] = result_text
```

不需要特殊返回函数或日志传输字符串。可以保留正常的 Python return 供直接运行验证，但父 Flow 若要消费该值，仍必须通过声明的 Out 参数和同名 `args` key 传递。

## VisualFlow 结果

- VisualFlow 需要向调用方或 `app.run_result` 公开业务结果时，使用已声明的 Out 参数；主 VisualFlow 只在内部消费子流程结果时不必声明 Out 参数。
- 计算型 Out 参数通常省略初始化 `value`，并让生产结果的 block 输出变量与 Out 参数同名。
- `process.return` 只提前结束当前 Flow，不携带返回值字段，也不能替代 Out 参数。
- 直接运行 VisualFlow 时，`app.run` / `app.run_result(run_id=app.run 返回值)` 在 `result.outputs` 捕获根 Flow 已声明且实际产生的 Out；VisualFlow 没有 Python `return` 字段。内部 `process.run` 子 Flow 的结果不会被这些工具单独捕获，没有根 Out 也不表示运行失败。

## `process.run` 连接顺序

1. 先稳定目标 Flow 的 In/Out 参数合同。
2. 插入 `process.run` 后，先按实例 form 填写 `process` 为准确的目标 `flow_id`。
3. 从返回的 `updated_forms` 读取 `arguments.<parameter-name>` 字段，只填写其中实际出现的 In 参数。
4. 需要读取子 Flow 结果时，在最新 form 中启用 `process_result` 并为它绑定一个变量名。
5. 后续 block 只使用 `process_result.properties[].reference` 返回的准确点号表达式，例如 `{"expression":"child_result.result_text"}`。

只声明子 Flow 的 Out 参数而不绑定 `process_result`，不会在父 Flow 中自动产生可用结果变量；MCP 运行结果也不会单独暴露子 Flow 输出。对于 CodeFlow，只 `return` 同名字典但不写回 `args`，对应 `process_result` 属性仍会是空值。结果对象也不是裸值或任意字典，不传整个对象给只需要其中一个字段的输入。

## VisualFlow 字段值

`flow.fill_blocks` 使用当前语义值：

- 字面量直接传值。
- 变量使用 `{"variable":"name"}`。
- 表达式使用 `{"expression":"code"}`。
- Selector、数组、对象和 JSON 文本见 `wiki/guides/visualflow/value-types`。

`10:`、`11:`、`13:`、`16:` 等数字前缀只可能作为引擎持久化或回读编码出现，不属于当前写入格式。

## 验证

- 参数写入后回读目标 Flow 的完整参数列表。
- `process.run` 配置后回读最新 form，确认目标、arguments、结果变量和 property reference 均来自同一个当前合同。
- 只验证实际声明并参与交付路径的参数。主流程没有入口参数合同时，不为验证或转发子流程结果额外创建 In/Out 参数。
- 子 Flow 正确和父 Flow 正确不等于连接正确。混合应用还要验证参数映射、Out 名称、结果绑定和下游引用。
