# CodeFlow 编写契约与实践

- DocId: `wiki/guides/codeflow`
- Source: `guides/codeflow.md`
- Tags: `authoring`, `codeflow`, `python`, `flow`
- UpdatedAt(UTC): 08/14/2026 10:54:28

---

# CodeFlow 编写契约与实践

本页是 CodeFlow 创建、修改和修复的权威编写规范。本页负责源码契约、修改顺序和实现实践。

## 适用边界

- 本页只适用于 `flow_kind=code`。
- 已知准确 `flow_id` 与 `flow_kind=code` 时直接读取目标；只有身份或类型不明确时才扩大到 App 或 Flow 列表。
- 编辑已有 CodeFlow 时保留与任务无关的行为和合理局部风格。补丁范围由需求决定，不借机重排、格式化或重写整份源码。

## 源码与接口

### 默认源码骨架

每个新建 CodeFlow 默认具有以下源码结构。界面语言不同时顶部提示注释可以变化，但默认导入和唯一入口结构一致：

```python
# 使用提醒:
# 1. xbot包提供软件自动化、数据表格、Excel、日志、AI等功能
# 2. package包提供访问当前应用数据的功能，如获取元素、访问全局变量、获取资源文件等功能
# 3. 当此模块作为流程独立运行时执行main函数
# 4. 可视化流程中可以通过"调用流程"的指令使用此模块

import xbot
from xbot import print, sleep
from .import package
from .package import variables as glv

def main(args):
    pass
```

- `xbot` 是编码版 SDK 的顶级命名空间；默认导入的 `print` 是与 XBot 运行日志集成的实现，不应误判或替换成 Python 内置 `print`。`sleep` 是模板提供的 XBot 等待函数。
- `package` 用于访问当前 App 的元素、资源等应用数据，`glv` 用于访问全局变量；没有对应需求时不得虚构调用方式。
- `main(args)` 是唯一的 Flow 运行入口。不要增加 `main()`、`if __name__ == "__main__":` 或其它并列启动入口。
- 修改已有 CodeFlow 时以其当前完整源码为准，保留仍有用途的默认导入。可以删除确认未使用的导入，但只要源码调用 `print(...)`，就必须保留 `from xbot import print`。

### 入口与参数契约

- 完整源码只保留一个 `def main(args):` 入口，并通过当前 Python 语法校验。
- `main(args)` 的输入、缺省值、空结果、失败语义和输出结构共同构成稳定接口。入口负责一次性归一化通用输入，接近外部系统的约束在拥有真实上下文的位置验证。
- 直接运行 CodeFlow 时仅在参数容器为 `None` 时用 `if args is None: args = {}` 初始化，再用 `args.get("参数名", default_value)` 提供测试 fallback。不能按 truthiness 替换有效的空容器，因为运行时会从同一个 `args` 对象收集声明的 Out 值。`app.run` 不接收输入参数，也不会注入参数面板默认值；由其它 Flow 通过 `process.run` 传入的同名 In 参数会覆盖 fallback。
- 需要公开结果时声明 Out 参数，并在 `main(args)` 中写入 `args` 的同名 key。普通 Python `return` 不会进入 Flow 结果通道。
- 简单单阶段逻辑保留在 `main(args)`；只有多阶段、重复操作、外部交互隔离或清晰接口确有需要时才提取 helper。

```python
def main(args):
    if args is None:
        args = {}
    source_path = args.get("source_path", r"C:\data\input.json")

    with open(source_path, "r", encoding="utf-8") as stream:
        result_text = stream.read()
    args["result_text"] = result_text
```

## Python 运行时与依赖

- Python 版本是 App 级事实：默认运行时为 Python 3.7，可升级到 Python 3.10。先用 `python_pip` 确认当前 App 的真实版本和已安装依赖；未确认时按 Python 3.7 编写。
- Python 3.7 基线不使用海象运算符、仅位置参数、`list[str]` / `dict[str, str]`、`match` 或 `X | None`。需要类型标注时使用 `typing.List`、`typing.Dict` 和 `typing.Optional`。
- 依赖安装和卸载只通过 `python_pip`，不通过 shell 直接调用 `pip` 或 `conda`。不为格式化、语法检查或试探自动安装依赖。

## 日志输出

- CodeFlow 模板中的 `from xbot import print` 会让源码里的 `print(...)` 调用 XBot 日志接口，而不是 Python 内置 `print`。`xbot.print` 会向当前应用运行日志写入普通信息日志。
- 生成或修改源码时不得依赖 Python 内置 `print`；如果源码尚未导入 XBot 版本，应添加 `from xbot import print`，或者显式使用 `xbot.logging.*`。不要使用 `builtins.print` 输出运行进度，因为其原生控制台输出对应用用户不可见。
- 普通进度、关键步骤摘要和结果数量使用 `xbot.print`；需要表达日志级别时使用 `xbot.logging.debug/info/success/warning/error`。`xbot.app.logging` 与 `xbot.logging` 指向同一日志模块，示例统一使用较简洁的 `xbot.logging`。
- 日志只记录定位问题所需的摘要，不输出 Cookie、Token、密码、验证码、完整页面内容或其它敏感数据。

```python
import xbot
from xbot import print

print("开始处理")
xbot.logging.success("处理完成")
xbot.logging.warning("部分可选字段缺失")
xbot.logging.error("外部服务调用失败")
```

## Flow 与模块调用

- 普通 CodeFlow / VisualFlow 调用统一使用 `process.run`，目标 `flow_id`、In/Out 参数名和结果引用都来自当前 App 与最新实例 form。
- `process.invoke_module` 只用于直接调用 CodeFlow 中真实存在的 Python helper，不用于调用 `main(args)` 或替代 Flow 参数合同。
- 使用 `process.invoke_module` 时，`module` 来自准确的 CodeFlow 模块，`function` 必须与源码中的 callable 一致，参数按最新实例 form 的 group-array 行填写并与函数签名对齐；不要把参数列表写成单个对象或凭历史持久化前缀拼接字段。
- 任何跨 Flow 公开输入和输出继续遵循 `wiki/guides/flow-parameters`。

## 实现实践

- 文件、网络、浏览器、Office/COM 等资源具有明确释放责任，优先使用上下文管理器或 `try/finally`。
- 外部等待和重试必须有业务可解释的上限。失败路径保留能够区分超时、权限、输入、SDK 与外部系统故障的上下文。
- 默认不捕获异常，让异常沿调用链暴露并进入运行修复闭环。不得为了“更健壮”或让流程继续运行而给 SDK、Selector、输入校验、解析或 I/O 调用随意添加 `try/except`。
- 只有任务或业务合同已经明确规定恢复、重试或降级语义，或者需要补充当前业务上下文后立即重新抛出时，才捕获当前操作已知的具体异常。`except Exception` 只允许位于最外层诊断边界，并且记录上下文后必须继续 `raise`。
- 捕获异常后禁止返回 `""`、`None`、`0`、空集合等哨兵值来伪造正常结果。正常无数据、输入无效和 SDK、Selector、浏览器或外部系统故障必须保持可区分。
- 默认在关键执行边界添加简洁、可定位的诊断日志，包括流程开始和结束、重要输入摘要、外部操作阶段、关键分支或重试决策以及结果数量。日志不输出 Cookie、Token、密码、验证码、完整页面内容或无关的逐项循环噪声。
- 默认为非显然的业务规则、副作用边界、兼容性限制、Selector/SDK 约束与 workaround 添加注释或 docstring；注释解释原因和约束，不逐行复述代码。
- 不为检查、格式化或试探自动安装依赖。

## 表格与 Excel 处理

- **新需求默认用 `openpyxl` / `pandas` 读写工作簿，不用 `xbot.excel`。** 这两个库直接读写 xlsx 文件，不依赖本机安装 Excel、不拉起 COM 进程，速度更快也更适合无人值守运行。依赖通过 `python_pip` 安装，Python 3.7 基线上注意选择兼容版本。
- **修改已有 CodeFlow 时沿用该源码原有的实现方式。** 已经用 `xbot.excel` 的继续用 `xbot.excel`，不要在维护性改动里顺手迁移；已经用 `openpyxl` / `pandas` 的同样保持。同一份源码里混用两套工作簿生命周期是缺陷来源，迁移是独立任务，需要单独确认。
- 只有确实需要驱动本机可见的 Excel 应用时才选 `xbot.excel`：接管用户已打开的工作簿、执行宏、依赖 Office 自身的重算或另存为其它格式。`xbot.excel.open/create` 返回的是 COM 工作簿对象，用完按 `## 实现实践` 的释放责任显式关闭。
- 无论哪种方式，工作簿路径、Sheet 名和列名都来自 Flow 参数或配置，不写死在源码里。
- `wiki/blocks/excel.*`（如 `excel.launch`）是 VisualFlow 指令文档，描述的是可视化指令的参数，不能当作 CodeFlow 里 Python 写法的依据；`wiki.search` 搜 "excel" 命中的通常就是这类文档。

## 运行时知识路由

| 知识缺口 | 读取 |
| --- | --- |
| 编码版正式支持能力清单 | `wiki/xbot_sdk/capabilities` |
| 常规输出与分级日志 | `wiki/xbot_sdk/logging` |
| Flow 参数、全局变量、跨 Flow 返回 | `wiki/guides/flow-parameters` |
| 诊断、调试日志、运行失败与修复循环 | `wiki/guides/diagnostics/completion-gate` |
| OCR 与结构化识别 | `wiki/xbot_sdk/ocr` |
| 剪贴板、数据表格、运行时交互框 | `wiki/xbot_sdk/clipboard`、`wiki/xbot_sdk/databook`、`wiki/xbot_sdk/dialog` |
| Excel / 工作簿读写选型 | 本页 `## 表格与 Excel 处理`；选型结论已给出，不需要再 `wiki.search` 确认 |
| FTP/SFTP、非元素 Win32、根目录通用模块 | `wiki/xbot_sdk/ftp`、`wiki/xbot_sdk/win32`、`wiki/xbot_sdk/common` |
| Web CodeFlow 结构、等待和 Selector 实践 | `wiki/guides/web/codeflow` |
| 模块级 `xbot.web.*` | `wiki/xbot_sdk/web` |
| `WebBrowser.*` | `wiki/xbot_sdk/web/browser` |
| `WebElement.*` | `wiki/xbot_sdk/web/element` |
| Web Selector 来源与使用边界 | `wiki/guides/web/selector` |

- Web CodeFlow 在首次写入源码前，必须一次性直接读取 `wiki/guides/web/codeflow`、`wiki/xbot_sdk/web`、`wiki/xbot_sdk/web/browser` 和 `wiki/xbot_sdk/web/element`。前者是 Web CodeFlow 编写指南，后三者是 SDK 参考。
- `catalog.block_summary` 和 VisualFlow block prototype 只证明可视化指令存在，不能作为 CodeFlow SDK 名称或签名的证据，也不能替代上述读取。
- 非 Web 领域在首次使用前读取匹配的 `xbot_sdk` 文档。`wiki/xbot_sdk/capabilities` 是公开能力清单；未列出的运行时模块、实现类和对象方法不能假设为编码版正式支持能力。Win32 仅使用 `wiki/xbot_sdk/win32` 明确列出的非元素 API。
- `clipboard`、`databook`、`dialog` 和 `ocr` 都通过 `import xbot` 后的顶级属性调用；不要生成 `import xbot.<domain>` 或 `from xbot.<domain> import ...`。`xbot.app` 原生接口、`xbot.ftp`、`xbot.win32` 和根目录模块按各自 Wiki 的导入方式调用。
- 未知领域先用 `wiki.search` 发现文档，再读取返回的 `doc_id`。
- SDK 名称、签名、Selector 用法和返回结构必须来自当前官方 Wiki、工具返回或工程事实；名称看起来合理不构成 API 证据。

## 验证与失败处理

- 语法通过只证明源码可解析，不证明参数接口、持久化或业务行为正确。
- 补丁后分别验证源码、参数、语法、持久化和调用接口；只有行为声明依赖执行时才增加代表性运行。
- 运行失败先按证据区分参数、源码、环境、SDK 与外部系统，再判断是否需要继续改代码。缺少区分性证据时先取证，不用猜测性补丁推进。
- 需要运行时使用已授权的最小代表性输入；超时后继续等待同一次 run，不启动一个输入与实现均未变化的新 run。
