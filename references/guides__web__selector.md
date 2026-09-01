# Web Selector 体系

- DocId: `wiki/guides/web/selector`
- Source: `guides/web/selector.md`
- Tags: `glossary`, `web`, `selector`, `codeflow`, `explorer`, `iframe`, `跨域`, `cross-domain`, `cross-origin`, `collection`, `table-selector`, `parent-scope`, `shadow-dom`, `shadowroot`
- UpdatedAt(UTC): 08/14/2026 10:54:28

---

# Web Selector 体系

本页定义 Web 自动化中元素定位的两种方式、工程 selector 的地位，以及 Explorer 与 VisualFlow/CodeFlow 之间的交接契约。
## 定位方式

| 方式 | 载体 | 适用 | 状态 |
| --- | --- | --- | --- |
| 工程 selector | 元素库中的命名 selector；VisualFlow 直接引用，CodeFlow 通过 `package.selector("名称")` 读取 | 稳定业务控件 | 默认方式 |
| 动态 CSS/XPath | `find_by_css` / `find_by_xpath` 等 | 无法合理落库的动态相对结构 | 受限使用 |

## 工程 selector

```python
from . import package

selector = package.selector("搜索框")
element = browser.find(selector, timeout=20)
```

- `package.selector("名称")` 从当前 App 元素库读取 `Selector` 对象；它属于工程包机制，不属于 `xbot.web` SDK。
- `find*` / `wait_appear` / `wait_disappear` 也接受选择器名称字符串（`str`），运行时会按名称从元素库解析；两种写法等价，工程内保持一致即可。
- 工程 selector 可以保留 iframe 分段、产品类型和运行时修复所需的结构信息，是 Explorer 与 VisualFlow/CodeFlow 之间的权威交接载体。
- 表格抓取使用 `TableSelector` 类型的工程 selector（配合 `browser.extract_table`）；对非表格选择器调用表格 API 会抛 `EngineError`。
- `element.get_selector()` 可以从运行时元素反推 `Selector` 对象，仅用于诊断场景；`Selector` 是运行时对象，不能作为 CodeFlow 业务结果返回。

### 跨域 iframe/frame 定位

影刀的工程 Web selector 已自动支持跨域 iframe/frame 定位，包括多层 iframe/frame 嵌套。selector 会保存完整的 frame 分段；定位、校验和操作元素时，运行时会自动进入对应 frame。

对跨域 iframe/frame 内的元素，按普通工程 selector 使用即可：

- VisualFlow 直接引用元素库中的 selector；
- CodeFlow 使用 `package.selector("名称")` 获取 selector，再传给 `find`、`find_all`、`wait_appear` 等接受 selector 的 API；
- 不要手动切换 frame、处理浏览器同源策略，或将工程 selector 拆成 raw CSS/XPath/页面 JavaScript。

这里的“跨域支持”专指工程 selector 路径穿越 iframe/frame，不表示任意 raw CSS、raw XPath 或页面 JavaScript 可以绕过浏览器同源策略。具体 API 若有单独限制，以对应 API 文档为准；例如 `xbot.web.auto_handle_popup` 当前不支持跨 iframe 元素。

### Shadow DOM / ShadowRoot 定位

影刀的工程 Web selector 支持定位 open ShadowRoot 内的元素，包括单层和多层嵌套 ShadowRoot。selector 会在内部保存 ShadowHost、ShadowRoot 边界和目标节点结构；VisualFlow 与 CodeFlow 均直接消费已保存并验证的工程 selector，不需要手动取得 `shadowRoot`、编写穿透脚本，或将 selector 改写为 raw CSS/XPath。

工程 selector 支持“iframe/frame 内嵌 ShadowRoot”：运行时先按 frame 分段进入对应 frame，再在该 frame 内穿越一层或多层 open ShadowRoot。该能力可与多层 iframe/frame 组合。当前标准捕获链不支持“ShadowRoot 内嵌 iframe/frame”中的目标；遇到这种结构时，不得猜测 locator 或声称已经完成 selector 交接。

closed ShadowRoot 不在支持范围内。当前 selector 引擎通过公开的 `element.shadowRoot` 进入 shadow tree，因此只适用于可公开访问的 open ShadowRoot。

工程 selector 的 ShadowRoot 能力不会自动传播给 raw locator 或页面脚本：

- `find_by_css` / `find_all_by_css` 只在当前 document 或元素范围内执行原生 CSS 查询，不自动跨 ShadowRoot 或 iframe/frame；
- `find_by_xpath` / `find_all_by_xpath` 使用原生 XPath 查询，不自动识别工程 selector 内部的 ShadowRoot 边界，也不自动进入 frame；
- 页面级 JavaScript 不自动进入 ShadowRoot 或跨域 frame；若目标已由工程 selector 定位，元素级 JavaScript 只能取得该元素对象，这不表示 JavaScript 继承了 selector 的穿越能力；
- `xbotShadowRoot` 是工程 selector 内部使用的合成边界，不是页面真实标签或通用 CSS/XPath 语法，不要在业务 Flow 中手工拼接。

## Selector 类型与命中基数

Explorer 的最终证据通过 `kind` 区分 selector 的业务语义。不能只看底层对象类型：element selector 与 collection selector 在持久化层都可能是普通 `Selector`，但消费方式不同。

| `kind` / 类型 | 命中与用途 | VisualFlow | CodeFlow |
| --- | --- | --- | --- |
| `element` | 预期唯一命中，用于单个元素的点击、输入或读取 | 普通 Web 元素指令 | `find` |
| `collection` | 预期命中 0..N 个同构元素，用于列表、卡片或行的逐项处理 | `web.element.foreach_element` / `web.element.get_all_elements` | `find_all` |
| `table` / `TableSelector` | 一次读取行×列数据矩阵 | `web.element.data_scraping` | `browser.extract_table` |

- collection selector 表示同一 selector 的全部匹配项，不是运行时重新计算视觉相似度。不要用单元素指令或 `find` 只处理第一个命中。
- collection selector 仍是普通工程 selector，不等于 `TableSelector`。逐项点击、输入或读取使用 collection selector；一次性读取结构化多列矩阵才使用 `TableSelector`。
- `TableSelector` 只在 Explorer 最终证据或工程元素库明确提供时使用。不要把 element/collection selector 传给 `table_element` 或 `extract_table`。

## 父级/容器作用域

列表、卡片和行中的子字段应在所属父级/容器范围内查找，避免从全页面误取其他项的同名字段。这里的父级作用域是“以父元素作为查找根”，不是获取目标的直接 DOM 父节点。

- VisualFlow 的 `web.element.get_element` 和 `web.element.get_all_elements` 可设置 `is_related_parent=true`，并在 `parent` 中引用已保存的 simple 工程 selector。开启后 `parent` 必填；运行时先定位父级/容器，再从其内部查找目标。
- 通过 Studio MCP 填写 VisualFlow 的 `parent` 时，遵循当前实例 form，提交 `{"selector":"商品卡片容器"}` 这样的语义值；不要填写 raw CSS/XPath、序列化 `WebElement` 或 `12:` 前缀的持久化编码。
- CodeFlow 的 `browser.find` / `browser.find_all` 没有 `parent=` 参数。先取得父 `WebElement`，再调用 `parent.find(...)` / `parent.find_all(...)`：

```python
container = browser.find(package.selector("列表容器"), timeout=20)
items = container.find_all(package.selector("列表项"), timeout=10)
```

- 若要从一个已定位元素取得其运行时父元素对象，VisualFlow 使用 `web.element.get_associated_elements` 的 `associated_kind=parent`，CodeFlow 使用 `element.parent()`；这与限定查找范围是两种不同能力。
- `web.element.foreach_element` 直接按自己的 collection selector 查找并循环，不消费 `get_all_elements` 已输出的列表，也没有 `is_related_parent` / `parent` 参数。

## 运行时修复边界

工程 selector 可携带运行时定位与修复所需的信息，但修复只是定位失败后的兜底，不是替代 Explorer 验证的保证。是否启用修复取决于 selector 的类型和元数据；collection selector 不使用普通单元素 selector 的语义修复。不要因为运行时可能修复而跳过真实页面校验，也不要在业务 Flow 中自行编排“调用 AI 修复 selector”的步骤。selector 失效时，按运行诊断补充 targeted 探索并重新验证。

## Explorer 与 VisualFlow/CodeFlow 的交接链路

稳定业务控件的默认链路：

1. Explorer 在真实页面验证目标。
2. `web_build_selectors_by_refids`、`web_build_selector_by_xpath`、`web_build_selector_by_position` 或 `web_build_list_selectors_by_refids` 将目标保存进当前 App 元素库。
3. Explorer 最终证据只交接已通过持久化与真实页面验证门禁的 `selector_name`、`kind` 和用途；底层类型、验证布尔值、命中数和来源工具不重复进入快照。
4. VisualFlow 按当前实例 form 引用元素库 selector；通过 Studio MCP 填写时提交 `{"selector":"<selector_name>"}` 语义值。`12:<selector_name>` 是持久化表示，不是 `flow.fill_blocks` 的输入格式。
5. CodeFlow 调用 `package.selector(selector_name)`，再按 `kind` 交给 `find`、`find_all` 或 `extract_table`。

不得把 Explorer refid、截图坐标或临时 AccTree 内容写入 VisualFlow/CodeFlow；这些是探索期证据，不是运行期定位依据。

## 动态 CSS/XPath 的使用条件

CSS 或 XPath 只在同时满足以下条件时使用：

- 目标结构动态生成，无法合理保存为工程 selector；
- locator 来自 Explorer 的 `dynamic_locator_supplements`，已经在真实页面验证；每项包含非空 `scope`、不能落库的 `reason`，并且恰好包含一个非空 `css` 或 `xpath`；
- 不是从 AccTree、文本描述或截图猜测得出。

使用时的作用域纪律：

- 相对 locator 必须从当前父元素开始（`card.find_by_css(".price")`），避免把本应局部匹配的规则放大成全页面匹配。
- 兄弟节点关系（`next_sibling()` 等）依赖页面 DOM 结构。若值本身能稳定捕获为工程 selector，应优先直接定位值；只有已确认标题和值保持相邻时才使用兄弟导航。
- 列表项可选字段用 `find_all_by_css(...)` 返回集合并检查空列表，不用宽泛异常控制正常分支。

## 元素库维护

`selector.list` / `selector.details` 只在需要核对或维护工程元素库时按需调用，不是每次编写 CodeFlow 的前置步骤。删除或重命名 selector 前先确认没有 CodeFlow 仍在引用。

## 常见错误

- 把稳定 selector 改写为容易失效的 CSS/XPath。
- 从 AccTree、截图或页面文本猜测 locator。
- 动态 locator 不限定父元素作用域，全页面匹配后取第一个。
- 把 `Selector` / `WebElement` 对象跨运行持久化或作为业务结果返回。
- 用截图坐标点击替代 selector 定位。

## 相关文档

- `wiki/xbot_sdk/web`
- `wiki/xbot_sdk/web/browser`
- `wiki/xbot_sdk/web/element`
- `wiki/guides/web/codeflow`
