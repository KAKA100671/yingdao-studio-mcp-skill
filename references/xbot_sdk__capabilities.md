# XBot SDK 能力清单

- DocId: `wiki/xbot_sdk/capabilities`
- Source: `xbot_sdk/capabilities.md`
- Tags: `xbot`, `sdk`
- UpdatedAt(UTC): 08/14/2026 10:54:28

---

本页是编码版可使用的 XBot SDK 白名单。只有下表列出的模块，以及对应 Wiki 明确列出的类和方法，才属于公开能力；运行时源码中存在但未列出的模块、实现类或辅助函数不构成可用合同。

尤其注意：`xbot.win32.element`、`Win32Element` 和窗口元素查找不属于公开能力；Web 浏览器的内部实现模块同样不能因源码中存在就直接导入。应始终从下表入口进入对应 Wiki，再按该页列出的 API 编写代码。

| 模块能力 | Wiki ID |
| --- | --- |
| 大语言模型 AI 能力 | `wiki/xbot_sdk/chatgpt` |
| 剪贴板 | `wiki/xbot_sdk/clipboard` |
| 数据表格 | `wiki/xbot_sdk/databook` |
| 对话框 | `wiki/xbot_sdk/dialog` |
| OCR 与结构化识别 | `wiki/xbot_sdk/ocr` |
| FTP/SFTP | `wiki/xbot_sdk/ftp` |
| Windows 桌面操作 | `wiki/xbot_sdk/win32` |
| 通用模块 | `wiki/xbot_sdk/common` |
| Web 模块 | `wiki/xbot_sdk/web` |
| WebBrowser | `wiki/xbot_sdk/web/browser` |
| WebElement | `wiki/xbot_sdk/web/element` |
| 日志 | `wiki/xbot_sdk/logging` |
