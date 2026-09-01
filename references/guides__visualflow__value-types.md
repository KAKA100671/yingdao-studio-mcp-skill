# VisualFlow 字段值语义

- DocId: `wiki/guides/visualflow/value-types`
- Source: `guides/visualflow/value-types.md`
- Tags: `glossary`, `values`, `visualflow`, `flow.fill_blocks`
- UpdatedAt(UTC): 08/14/2026 10:54:28

---

# VisualFlow 字段值语义

本页说明 `flow.fill_blocks` 当前接受的字段值。工具 schema 与最新实例 form 决定字段是否存在以及允许的 choice；本页只说明如何保留字面量、变量、表达式、Selector 和集合之间的运行语义。

## 当前写入格式

| 业务语义 | 当前写法 | 示例 |
| --- | --- | --- |
| 普通字面量 | 直接传 JSON 字符串、数字、布尔值或 `null` | `"hello"`、`12`、`true` |
| 显式文本 | `{"text":"..."}` | `{"text":""}` |
| 变量引用 | `{"variable":"<name>"}` | `{"variable":"order_id"}` |
| Python 表达式 | `{"expression":"<code>"}` | `{"expression":"int(price) * count"}` |
| Selector 引用 | `{"selector":"<name>"}` | `{"selector":"btn_submit"}` |
| Python 数组 | `{"array":[...]}` | `{"array":[1,{"variable":"order_id"}]}` |
| Python 对象 | `{"object":{...}}` | `{"object":{"id":{"variable":"order_id"},"ok":true}}` |
| JSON 文本 | `{"json":{...}}` 或 `{"json":[...]}` | `{"json":{"font":{"bold":true}}}` |

- plain 字符串始终是文本字面量；即使内容看起来像变量名、数字、布尔值、JSON 或表达式，也不会改变语义。
- `{text}` 用于明确文本语义，尤其适合空字符串。普通非空文本通常直接传字符串即可。
- `{array}` 与 `{object}` 会编译成真实 Python `list` 与 `dict`，其中每个成员仍可使用本表的语义值。
- `{json}` 会把对象或数组编译成 JSON 文本，只用于实例 form 或字段提示明确要求 JSON 字符串的字段。需要真实 Python 集合时使用 `{array}` 或 `{object}`。

## 引用规则

- `{variable}` 只填写当前 Flow 中实际存在的变量 `name`，包括流程参数、流程内变量和指令输出名。显示 label、输出 id、tips 和 helpdoc 不是变量名。
- `{selector}` 只填写当前工程中已确认的 Selector 名称。Selector 不从页面文本、XPath 或 CSS 字符串推断。
- `{expression}` 只包含当前运行环境可执行的轻量表达式。属性访问和类型转换可以写成表达式；需要导入模块或执行多步逻辑时使用 CodeFlow 或代码 block。
- 输出字段的命名按最新实例 form 填写；输入值语义与输出变量命名是两套不同契约。

## 重复结构字段

重复结构字段不在普通 `fills[].inputs` 中嵌套旧 `group_array`。使用 `flow.fill_blocks.group_fills`：

- `fixed` 放每一行共享的语义值。
- `columns` 的每个字段放等长的非空数组。
- 同一 block 的同一 input 不能同时出现在普通 `fills` 与 `group_fills`。

`group_fills` 中的每个单元仍使用本页的当前语义值。

## 历史编码边界

`10:`、`11:`、`12:`、`13:`、`15:`、`16:` 等数字前缀是引擎持久化、旧数据或回读时可能出现的内部编码。它们用于解释已有值，不是当前 `flow.fill_blocks` 的写入格式。

- 不把 `10:hello` 当作当前文本写入；传 `"hello"` 或 `{"text":"hello"}`。
- 不把 `11:order_id` 当作当前变量引用；传 `{"variable":"order_id"}`。
- 不把 `13:total + 1` 当作当前表达式；传 `{"expression":"total + 1"}`。
- 不复制 form 回读中的内部编码来构造新值；根据业务语义重新选择当前格式。

## 常见错误

- 把变量名、表达式、Selector 或 JSON 当作外观相同的普通字符串。
- 把显示文案、字段说明或另一个 block 的输出 id 当作变量名。
- 用 `{json}` 代替需要真实 `list` 或 `dict` 的 `{array}` / `{object}`。
- 在普通字段中嵌套旧 `group_array`，而不是使用顶层 `group_fills`。
- 把历史数字前缀写回 `flow.fill_blocks`。
