---
name: studio-mcp
description: 通过影刀 Studio 内嵌的 studio-mcp（本地 HTTP MCP 端点）让外部 agent 完整操控影刀设计器——搭建/编辑可视化流程（VisualFlow）、编写代码流（CodeFlow）、运行验证、查指令文档。当用户提到影刀、ShadowBot、studio-mcp、搭流程、flow.edit_blocks、VisualFlow、CodeFlow、操作影刀设计器时使用。端口号随影刀会话变化，用前必须先运行 scripts/sync-studio-mcp.ps1 探测并写入 opencode 配置。
---

# studio-mcp：外部 agent 接入影刀设计器

影刀 Studio（ShadowBot.Shell 进程）启动后会暴露一个**零鉴权的本地 HTTP MCP 端点**（streamable transport，EmbedIO 服务，serverInfo.name = `shadowbot-mcp-http`），路径固定为 `/api/v1/mcp`，**端口随会话变化**。影刀内置的 AI 流程助手走的就是这套能力，外部 agent 接入后拥有完全相同的 40 个工具。

## 接入流程（每次影刀重启后必做）

1. 确认影刀 Studio 已打开应用（ShadowBot.Shell 进程存在）
2. 运行同步脚本，自动探测当前端口并写入 `~/.config/opencode/opencode.json` 的 `mcp.studio-mcp`：
   ```powershell
   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.config\opencode\skills\studio-mcp\scripts\sync-studio-mcp.ps1"
   ```
   脚本逻辑：找 ShadowBot.Shell PID → 枚举其监听端口 → 逐个 POST `initialize` 探测（匹配 `shadowbot-mcp-http`）→ `tools/list` 验证 → 合并写入 opencode 配置。
3. **重启 opencode**（MCP 配置不热加载），之后本会话直接出现 studio-mcp 工具。

## 工具清单（40 个）

### 应用级
| 工具 | 作用 |
|---|---|
| `app.get_info` | 当前应用摘要（编辑前先读） |
| `app.list_flows` | 列出所有流程 |
| `app.create_flow` / `copy_flow` / `delete_flow` / `rename_flow` | 流程增删改复制（主流程不可删/改名） |
| `app.save` | 保存并编译 |
| `app.reload` | 从磁盘重开（丢弃未保存修改） |
| `app.update_info` | 应用元数据/设置 |
| `app.global_variables.list` / `write` | 全局变量（运行时引用 `glv['name']`） |
| `app.resource.add` / `list` / `remove` / `rename` | 资源文件（≤20MB） |
| `app.databook.read` / `clear` | 数据表读写 |
| `python_pip` | 管理应用 pip 依赖 |

### 可视化流程（VisualFlow）
| 工具 | 作用 |
|---|---|
| `flow.edit_blocks` | **唯一**能插/删指令块的工具。insert 需 `blocks[{prototype_name, comment}]` + `block_index`（-1 追加）；comment 是必填语义标签，不持久化 |
| `flow.fill_blocks` | 给已有块填字段。语义值：`{variable:name}`、`{expression:code}`、`{selector:name}`、`{array:[...]}`、`{object:{...}}`、`{json:{...}}`；长多行字符串直接传 plain string；重复结构化字段用顶层 `group_fills`（fixed + columns 列式填充） |
| `flow.blocks.list` | 列块；`detail=detail` 返回完整可填表单 |
| `flow.write_parameters` / `list_parameters` | 流程 In/Out 参数；集合类型用 `any`；VisualFlow 计算型 Out 参数省略 value，并把结果赋给同名块输出 |
| `flow.toggle_blocks` | 启用/禁用块（comment/uncomment） |
| `flow.list_variables` | 变量及作用域（静态分析） |
| `flow.get_variable_snapshots` | 运行后读每个块的输入输出快照 |

### 代码流（CodeFlow）
| 工具 | 作用 |
|---|---|
| `codeflow.read` / `write` / `edit` | 读/全量写/精确替换；保存前做 Python ast.parse 校验；用 glv 必须先 `from .package import variables as glv` |

### 运行与诊断
| 工具 | 作用 |
|---|---|
| `app.run` | 自动保存+运行+内联等待（默认 90s）；返回含 `terminal_status` 即为最终结果，**不要**再调 wait_run_finish/run_result；超时才用 `app.wait_run_finish`（传 run_id，禁止重跑） |
| `app.wait_run_finish` / `app.run_result` | 续等/重读结果（仅限上述超时场景） |
| `app.stop_run` | 停止运行 |
| `app.logs` | 运行日志（游标分页） |
| `diagnostics.snapshot` | 静态校验错误 + 最近一次运行时异常 |

### 知识与选择器
| 工具 | 作用 |
|---|---|
| `wiki.search` / `wiki.read` / `wiki.list` | 本地指令文档库（实体：`影刀安装目录\Resources\Copilot\wiki.db`）；块原型名（如 `excel.write_data_to_workbook`）可直接搜出文档 |
| `selector.list` / `selector.details` | 网页元素选择器（按名查 xpath 等） |

## 搭建 VisualFlow 的标准顺序

1. `app.get_info` → `app.list_flows` 拿到目标 `flow_id`
2. 用 `wiki.search`/`wiki.read` 查指令原型名和字段（`flow.edit_blocks` 只接受精确 prototype_name）
3. `flow.edit_blocks`（op=insert）插入指令 → 拿返回的 block_id 和可填表单
4. `flow.fill_blocks` 填字段；`flow.write_parameters` 声明参数
5. `app.save` → `diagnostics.snapshot` 查静态错误 → 修正
6. `app.run` 运行验证；失败看 `app.logs` / `diagnostics.snapshot` / `flow.get_variable_snapshots`

## 关键规则

- **超时**：opencode 的 MCP 调用 120 秒硬超时；`app.run`/`wait_run_finish` 的等待上限会被钳到 115s，超时后拿 run_id 续等
- **用户暂停/停止**：返回 `user_paused`/`user_stopped=true` 时立即停止自主操作并询问用户
- **fill_blocks 部分成功**：单块失败不影响同批其他块；只按 `fill_errors[]` 里的 block_id 重试
- **安全**：端点对本机所有程序零鉴权开放；属于影刀未公开内部接口，升级可能变更，不要用于正式生产流程的稳定性依赖

## curl 直连备用（MCP 未加载进会话时）

PowerShell 双引号会吃掉 JSON 引号导致 400，必须**把 JSON 写到文件再 `--data-binary @file`**：

```powershell
# initialize / tools/list / tools/call 均 POST 到 http://127.0.0.1:<port>/api/v1/mcp
# 头: Content-Type: application/json; Accept: application/json, text/event-stream
# tools/call 示例 body:
# {"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"app.get_info","arguments":{}}}
```

## 文件

- `scripts/sync-studio-mcp.ps1` — 端口探测 + 配置同步（见上）
- `references/orchestration-rules.md` — **影刀内置 AI 助手的完整领域规则原文**（确认门禁/能力边界/需求分析/编排循环/值类型系统/完成门禁等 15 节），搭流程、运行、交付前必读。适配差异：explorer 职责由 playwright-cli/bb-browser 承担
- `references/visual-blocks/block_catalog.md`（25KB，全量指令清单）+ `block_detail.md`（164KB，全字段详情，记录格式 `<name>{json}<name/>`）— **插入指令前必须查询**，禁止凭记忆。查询顺序：catalog 找候选名 → 在 detail 里按 `<原型名>` 带尖括号检索字段 → 确认后 `flow.edit_blocks(insert)`。源头文件在 `%LOCALAPPDATA%\ShadowBot\opencode\runtime\shared\knowledge\visual-blocks\`，影刀升级后可重新拷贝刷新
- `references/` 其余文件 — 已从 studio-mcp 离线 dump 的 9 篇官方指南（内容以运行时 wiki.read 为准）：
  - `guides__visualflow.md` — VisualFlow 编写契约（结构/字段/数据流/校验）
  - `guides__visualflow__value-types.md` — fill_blocks 语义值体系（字面量/变量/表达式/选择器/集合）
  - `guides__flow-parameters.md` — 全局变量、流程参数、Out 参数与 process.run 契约
  - `guides__codeflow.md` — CodeFlow 编写规范
  - `guides__web__codeflow.md` — Web CodeFlow 运行时约束与模板
  - `guides__web__selector.md` — 网页选择器契约（Explorer 交接、动态 XPath、跨 frame）
  - `guides__web__browser-extension-install.md` — 浏览器扩展缺失时的恢复
  - `guides__diagnostics__completion-gate.md` — 验收门禁与诊断修复循环
  - `xbot_sdk__capabilities.md` — CodeFlow SDK 公开能力白名单
- 配置落点：`~/.config/opencode/opencode.json` → `mcp.studio-mcp`

## 踩坑手册（实战复盘索引）

- `D:\agent接管影刀rpa文件夹\流程开发复盘.md` — 历次搭流程踩坑记录与调试方法论。**遇到困难先查此手册**。当前收录：
  - Chrome/Edge 插件缺失 → 改用 cef 内置浏览器
  - Clash TUN 代理导致 CEF 间歇性 chrome-error → `web.create` arguments 加 `--proxy-server=127.0.0.1:7897`
  - 百度按钮模拟点击无效 → simulate=False
  - 百度结果异步渲染 → for 轮询 + JS 检测，勿信 wait_load_completed
  - XPath `//` 前缀快照显示异常、get_all_elements 静默返空、循环变量作用域、禁用块连锁校验
  - 调试三板斧：JS 探针看 url/title/DOM 计数 → 区分"页面没打开/没渲染完/选择器不对"
  - 交互前先等元素出现（web.element.wait / 带超时 get_element / 条件轮询），不要固定 sleep 死等
