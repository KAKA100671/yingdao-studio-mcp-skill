# VisualFlow 编写契约与实践

- DocId: `wiki/guides/visualflow`
- Source: `guides/visualflow.md`
- Tags: `authoring`, `visualflow`, `flow`, `blocks`
- UpdatedAt(UTC): 08/14/2026 10:54:28

---

# VisualFlow 编写契约与实践

本页是 VisualFlow 创建、修改和修复的权威编写规范。

## 适用边界

- 本页只适用于 `flow_kind=visual`。
- VisualFlow 的结构、字段、参数、名称与生命周期只能通过当前 Studio 能力修改；不得直接编辑工程文件，也不得用 CodeFlow 源码工具改写 VisualFlow。
- 已知准确 `flow_id` 时直接围绕目标 block、form 和参数工作；只有身份或类型不明确时才扩大到 `app.list_flows`。
- 编辑已有 VisualFlow 时保留其 Flow 类型和任务无关结构，不能用大范围重建代替局部定位。

## 知识前置

| 场景 | 读取 |
| --- | --- |
| 字面量、变量、表达式、Selector、数组与对象 | `wiki/guides/visualflow/value-types` |
| Flow 参数、全局变量、Out 参数与 `process.run` | `wiki/guides/flow-parameters` |
| 诊断、调试日志、运行失败与修复循环 | `wiki/guides/diagnostics/completion-gate` |
| Web Selector 来源、跨域 iframe/frame 能力与使用边界 | `wiki/guides/web/selector` |
| 未知 block 行为、领域配方或诊断 | 先 `wiki.search`，再读取返回的 `doc_id` |

## 领域能力选择

### Web

Web VisualFlow 中，跨域 iframe/frame 和 open ShadowRoot 内的元素直接引用 Explorer 已保存、已验证的工程 selector。运行时会自动进入多层 frame，并可在 frame 内穿越一层或多层 open ShadowRoot；不要手动切换 frame、取得 `shadowRoot`、处理同源策略，或将工程 selector 改写为 raw CSS/XPath/页面 JavaScript。closed ShadowRoot 与 ShadowRoot 内嵌 iframe/frame 不在标准捕获支持范围内，不能用猜测 locator 绕过。按 Explorer 交接的 `kind` 消费 selector：单元素使用普通 Web 元素指令，collection 使用 `web.element.foreach_element` / `web.element.get_all_elements`，TableSelector 使用 `web.element.data_scraping`。需要把单个或相似元素限定在父级/容器内时，分别使用 `web.element.get_element` / `web.element.get_all_elements` 的 `is_related_parent=true` 与 `parent`；不要把这种查找作用域误写成获取 DOM 父元素。完整能力边界和 API 特例见 `wiki/guides/web/selector`。

### Excel 与数据表格

`excel.*` 操作 Excel 文件；`programing.databook.*` 操作影刀数据表格。处理 Excel 默认用 `excel.*`；仅用户明确要求影刀数据表格/DataBook 时用后者，不能因其可导出 `.xlsx` 替代前者。

### Excel 驱动选择

Excel 文件任务在选择具体指令前，先确定驱动。
- 普通文件读写优先 `openpyxl`。
- 需要公式计算结果、真实筛选/可见行、区域截图、宏、透视表/切片器、PDF、密码或自动行高时，使用 COM 驱动；所选指令明确不支持 `openpyxl` 时也是如此。
- 具体驱动参数和 `auto_check` 的行为见 `excel.launch`；

Excel 专项能力先确认可视化指令列表中是否有对应指令。普通工作表筛选（含按颜色筛选、读取可见行、清除筛选）、分列、单元格图片操作、冻结窗格和切片器等能力目前没有对应标准 Excel 指令；可通过 `programing.snippet` 调用当前驱动的原生 API。

## 结构与字段

- 准确 prototype 来自 `knowledge/visual-blocks/block_catalog.md`（全量指令，一行一条 `prototype_name | description`，整篇 `read`），不能凭名称相似或历史记忆假定指令存在。需要输入输出、类型或可选值时，按指令的 name 去 grep `knowledge/visual-blocks/block_detail.md`（每条记录 `<name>{json}<name/>`，检索 pattern 必须带尖括号，不能把 catalog.md 的整行 `prototype_name | description` 当作 pattern，也不能用裸指令名）。用内置 grep 工具时 pattern 参数写一个正则，多个指令用括号加竖线合并，如 `<(dictionary\.get_keys|list\.append)>`，不要把 bash 的 `-e` 参数语法传进这个 pattern 参数；用 bash 工具时才用 `grep -e "<dictionary.get_keys>" -e "<list.append>" knowledge/visual-blocks/block_detail.md`（当前环境没有 `rg`）。
- 结构变化与字段赋值是两类事实：使用 `flow.edit_blocks` 插入或移除指令实例，使用 `flow.fill_blocks` 填写已有实例字段，使用 `flow.write_parameters` 声明参数。
- 插入响应或 `flow.blocks.list(detail=detail)` 返回的当前实例 form 是字段、choice、默认值和输出的唯一契约。前置选择刷新字段后，只能继续使用最新 form。
- 填写字段前先判断业务语义，再使用当前 `flow.fill_blocks` schema 对应的语义值。不得把回读编码、说明文案、label、tips 或 helpdoc 当作业务值。
- 变量名、输出标识和显示文案可能不同。有效引用来自当前 form 与 schema，不能从其它 block 概括通用 id/name 规则。

## 数据与控制结构

- 变量生产者必须位于消费者之前，并且在实际执行路径上可达。
- 条件、循环、异常处理和区域等成对结构必须正确配对与嵌套。诊断只指出缺失一侧时，先理解现有结构，不为补一个边界而重建整个流程。
- 执行顺序服从数据依赖、控制结构和资源生命周期。打开的资源具有对应的释放边界。
- 子流程调用按 `process.run` 的最新实例 form 连接，不从另一个 Flow 直接访问内部变量。

## 设计原则

- 以业务阶段和数据边界组织 Flow。每个阶段都有明确输入、产出与进入下一阶段的条件。
- 使用最少的标准 block 构成核心闭环。每个 block 都应对应业务目标或必要控制边界，不用占位 block 掩盖未知。
- 运行输入与结构配置保持分离：调用者需要改变的业务数据进入 In 参数，稳定编排语义留在 block 中。
- VisualFlow 保持可读的业务编排。长算法、复杂 SDK 调用或可复用逻辑收敛为 CodeFlow 的小接口，不堆入代码字段。
- 新声明的流程、变量、输出与参数优先使用中文业务名，与业务语言一致。

## 构建顺序

1. 先确认所需 prototype 与成对结构。
2. 插入能够自洽的最小结构骨架。
3. 使用插入响应中的实例 form 填值。
4. 前置选择导致 form 刷新时，使用 `updated_forms` 或重新读取最新 form 后再继续。
5. 确认变量和 Selector 已在实际运行路径上产生或保存。
6. 围绕受影响的 block、form、参数、引用与控制边界回读持久化结果。

能安全合并的确定性写入可以批量完成；存在字段刷新或结构依赖时按依赖顺序分步完成。

## 持久化与失败处理

- 写入响应只证明一次调用被接受，不自动证明依赖关系、字段刷新和最终持久化正确。
- `issues`、`validation_errors`、字段丢失、配对错误、回读不一致或未读完的分页都表示对应结论尚未成立。
- 外部值、批量样本或页面结果进入重要分支、跨阶段消费或多处复用前，在靠近来源的位置验证关键形状与范围。
- 日志和错误应包含业务阶段、对象与实际关键值，使一次失败能够区分数据、Selector、结构和外部环境问题。
- 调试用 In 参数采用可重复的代表性值；完成前恢复正式默认值，并移除不再有交付意义的纯调试参数。
