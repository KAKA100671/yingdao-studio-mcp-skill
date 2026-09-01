# yingdao-studio-mcp-skill

opencode skill：通过影刀 Studio 内嵌的 studio-mcp（本地 HTTP MCP 端点）让外部 AI agent 完整操控影刀设计器——搭建/编辑可视化流程（VisualFlow）、编写代码流（CodeFlow）、运行验证、查询指令文档。拥有与影刀内置 AI 流程助手完全相同的 40 个工具。

## 目录结构

- `SKILL.md` — skill 入口说明：接入流程、40 个工具清单、VisualFlow 搭建标准顺序、关键规则、踩坑手册索引
- `scripts/sync-studio-mcp.ps1` — 端口探测 + opencode 配置同步（影刀每次重启后运行）
- `references/orchestration-rules.md` — 影刀内置 AI 助手的完整领域规则
- `references/visual-blocks/` — 全量指令清单（block_catalog）与字段详情（block_detail）
- `references/guides__*.md` — 9 篇官方指南离线 dump（VisualFlow/CodeFlow/选择器/验收门禁等）

## 使用前提

1. 影刀 Studio 已打开应用
2. 运行 `scripts/sync-studio-mcp.ps1` 探测端口并写入 opencode 配置
3. 重启 opencode，会话中出现 studio-mcp 工具

## 安全提示

studio-mcp 端点对本机所有程序零鉴权开放，属于影刀未公开内部接口，升级可能变更，请勿用于正式生产流程的稳定性依赖。
