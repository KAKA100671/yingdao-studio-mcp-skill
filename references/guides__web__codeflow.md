# Web CodeFlow 编码规范与标准模板

- DocId: `wiki/guides/web/codeflow`
- Source: `guides/web/codeflow.md`
- Tags: `pattern`, `web`, `codeflow`, `template`
- UpdatedAt(UTC): 08/14/2026 10:54:28

---

# Web CodeFlow 编码规范与标准模板

本页是 `wiki/guides/codeflow` 的 Web 专项必读附加规范，定义 Web 自动化 CodeFlow 的运行环境约束、结构规范和标准模板。API 参考见 `wiki/xbot_sdk/web` 系列文档；selector 治理见 `wiki/guides/web/selector`。

## 适用范围

- CodeFlow 是优先交付方式，本页适用于所有 Web 自动化 CodeFlow 的编写与修改。
- 只有用户明确要求 VisualFlow，或编辑目标是已包含业务 block 的 VisualFlow 时，才改用 VisualFlow 编排；空的 VisualFlow 主流程不构成理由，业务逻辑进入新建 CodeFlow，主流程只保留最小调用编排。
- Explorer 打开的页面默认只提供浏览器模式、入口 URL、Selector 和页面行为证据，不自动成为生成代码的运行环境。除非任务明确要求操作已有页面，生成的 Web CodeFlow 默认从 `xbot.web.create(target_url, mode=...)` 创建并持有自己的新页面，避免隐式依赖探索阶段遗留的页面。

## 运行环境

- 运行环境默认为 Python 3.7。不使用 `list[str]`、`dict[str, str]`、`X | None`、`match` 等较新语法；需要类型标注时使用 `typing.List`、`typing.Dict`、`typing.Optional`。
- 依赖第三方包或版本敏感语法前，先调用 `python_pip` 核对当前环境。
- 只导入实际使用的模块。已有 CodeFlow 的标准模板头和仍在使用的标准导入应保留，不要为了风格优化重写无关区域。

```python
import xbot.web

from . import package
```

禁用清单：

- 不使用 `xbot_visual`、`xbot_playwright`、标准 Playwright。
- 不使用 `ChromeAutomation`、`CEFAutomation` 等浏览器实现类；它们是运行时实现细节，不是稳定业务入口。
- 不生成、推荐或回退到 IE 模式，即使运行时签名或历史文档中出现 `ie`。

## 结构规范

成熟的 CodeFlow 不按 SDK 调用顺序堆叠代码，而按以下边界组织：

1. 在 `main(args)` 边界校验并归一化业务输入；参数传递遵循 `wiki/guides/flow-parameters`。浏览器模式、入口 URL 等按证据确认的稳定事实写死为模块常量，不设计成运行时分支。
2. 默认调用 `xbot.web.create(TARGET_URL, mode=BROWSER_MODE, ...)` 建立本次运行持有的新页面，并通过返回的 `WebBrowser` 继续操作。只有任务明确要求操作当前页面、匹配已有页面或枚举已有页面时，才分别选择 `get_active()`、`get()` 或 `get_all()`；匹配条件来自业务要求和当前证据，不把 Explorer 遗留页面作为隐式回退。
3. 使用 `package.selector()` 获取稳定控件；动态 CSS/XPath 只消费 Explorer 已验证的补充证据。完整能力边界和 API 特例见 `wiki/guides/web/selector`。
4. 用 `load_timeout`、`wait_appear`、`wait_disappear` 和 `find(..., timeout=...)` 等状态等待，不使用固定长 `sleep` 代替页面状态。
5. 将重复且有明确职责的操作提取为 helper，让 `main(args)` 只负责编排。
6. 对外只产生稳定、可 JSON 序列化的业务值，不暴露 `WebBrowser`、`WebElement` 或 selector 对象。

`print` 只用于对人有意义的诊断日志。普通 helper 函数可按正常 Python 语义返回内部计算值；Flow 输出边界不在本页重复定义。

## 页面获取与关闭

生成的 Web CodeFlow 默认用 `create()` 建立新的起始页面，因为 `get()`、`get_active()` 和 `get_all()` 会读取现有浏览器状态，Explorer 或用户预先打开的同站点页面可能因此改变匹配结果、登录态、页面位置和最终输出。

任务明确要求使用用户当前页面、复用指定已有页面或枚举页面时，可以选择相应 API，并显式说明页面识别条件与生命周期。使用 `create()` 时，入口 URL 作为第一个参数传入，浏览器模式使用 `mode=` 命名参数；`xbot.web.create("chrome")` 后再调用 `get(url)` 不是有效的新建页面方式。

流程通常只操作自己创建或按业务条件明确选中的 `WebBrowser`。是否在结束时调用 `browser.close()` 由业务是否需要保留结果页面决定；`close_all()`、`reset_user_environment()` 等全局操作只在任务明确要求且影响范围已经确认时使用。


## 标准模板

以“创建全新页面 → 输入搜索词 → 读取结果”为例，展示运行环境隔离、参数边界、Selector 消费、高可靠输入、状态等待、关键日志和稳定输出。`keyword` 必须先声明为 In 参数，`result` 必须先声明为 Out 参数；三个 Selector 必须已经由 Explorer 保存并验证。

```python
import xbot.web
from xbot import print

from . import package


# 浏览器模式与入口 URL 来自用户要求或 Explorer 已验证的证据
BROWSER_MODE = "chrome"
TARGET_URL = "https://www.example.com/"


def main(args):
    """In 参数：keyword（搜索词）；Out 参数：result（搜索结果）。"""
    if args is None:
        args = {}
    keyword = args.get("keyword", "示例关键词")
    if not isinstance(keyword, str) or not keyword.strip():
        raise ValueError("keyword is required")
    keyword = keyword.strip()

    print({
        "event": "web_flow.start",
        "browser_mode": BROWSER_MODE,
        "target_url": TARGET_URL,
    })

    # 每次运行创建独立页面，不连接 Explorer 或用户已经打开的页面
    browser = xbot.web.create(
        TARGET_URL, mode=BROWSER_MODE,
        load_timeout=PAGE_TIMEOUT_SECONDS, stop_if_timeout=True)
    print({"event": "web_flow.browser_created", "url": browser.get_url()})

    # 输入开启 input_check，由 SDK 校验落入页面的实际值
    search_box = browser.find(
        package.selector("搜索输入框"), timeout=ELEMENT_TIMEOUT_SECONDS)
    search_box.input(keyword, simulative=False,
                     input_check=True, check_value=keyword)

    # 点击后以目标元素的出现判断页面就绪，不用固定 sleep
    browser.find(
        package.selector("搜索按钮"), timeout=5).click()
    print({"event": "web_flow.search_submitted"})
    if not browser.wait_appear(
            package.selector("结果区域"), timeout=20):
        raise TimeoutError("result area did not appear after search")

    result_element = browser.find(
        package.selector("结果区域"), timeout=5)
    result = {
        "url": browser.get_url(),
        "title": browser.get_title(),
        "text": result_element.get_text().strip(),
    }
    args["result"] = result
    print({
        "event": "web_flow.completed",
        "result_url": result["url"],
        "result_text_length": len(result["text"]),
    })
```

## 检查清单

提交 CodeFlow 前逐项核对：

- [ ] 浏览器模式来自用户要求或 Explorer 已验证的浏览器证据，不从页面内容猜测、不静默回退到其它浏览器。
- [ ] 未明确要求使用已有页面时，起始页面由 `xbot.web.create(TARGET_URL, mode=BROWSER_MODE, ...)` 新建，没有隐式连接 Explorer 遗留页面。
- [ ] 明确要求使用已有页面时，`get()`、`get_active()` 或 `get_all()` 的选择与页面识别条件有业务依据。
- [ ] 页面关闭策略符合业务要求；全局关闭或重置操作的影响范围已经确认。
- [ ] 所有等待有界且基于页面状态，没有固定长 `sleep`、无限等待或无界轮询。
- [ ] 没有 Explorer refid、截图坐标或临时 AccTree 内容。
- [ ] element、collection 和 TableSelector 按 `kind` 分别交给 `find`、`find_all` 和 `extract_table`，没有混用。
- [ ] 局部子字段从所属父 `WebElement` 范围内查找，没有把局部 selector 放大全页面后取第一个命中。
- [ ] iframe/frame 或 open ShadowRoot 内的元素直接使用已验证的工程 selector，没有手动切换 frame、读取 `shadowRoot`、处理同源策略，或降级为 raw CSS/XPath/页面 JavaScript。
- [ ] 没有把 closed ShadowRoot 或 ShadowRoot 内嵌 iframe/frame 写成受支持场景；raw CSS/XPath 也没有被假定能跨 ShadowRoot 或 frame。
- [ ] 参数使用符合 Flow 合同，对外业务值可 JSON 序列化且不含 `WebBrowser` / `WebElement` / `Selector`。
- [ ] 日志和 Flow Out 参数中没有 Cookie、Token、密码或验证码。
- [ ] 语法兼容 Python 3.7。

## 相关文档

- `wiki/xbot_sdk/web`
- `wiki/xbot_sdk/web/browser`
- `wiki/xbot_sdk/web/element`
- `wiki/guides/web/selector`
