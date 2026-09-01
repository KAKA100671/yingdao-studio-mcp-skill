# 浏览器自动化插件安装

- DocId: `wiki/guides/web/browser-extension-install`
- Source: `guides/web/browser-extension-install.md`
- Tags: `guide`, `web`, `explorer`, `browser-extension`, `recovery`
- UpdatedAt(UTC): 08/14/2026 10:54:28

---

# 浏览器自动化插件安装

Explorer 因浏览器插件缺失停止后，按返回的 `code` 和 `mode` 安装插件。始终使用返回的 `mode`。

## 何时使用

仅当 Explorer 返回 `recovery_required=true`，且 `code` 为下列之一时使用本页：

- `browser_extension_install_required`
- `custom_browser_extension_install_required`
- `shadowbot_browser_bridge_unavailable`

## 内置浏览器：chrome / edge / 360se / firefox

`code=browser_extension_install_required` 时，用 bash 异步拉起交互式安装器。安装器可能提示关闭正在运行的浏览器。

安装器绝对路径由影刀在返回本页时填入：

`D:\影刀6.3.9\shadowbot-6.3.9\support_x64\chrome\ShadowBot.BrowserBridge.Installer.exe`

参数只用下表的 `--kind` 和 `--version`。用 `Start-Process` 拉起 GUI 后即可返回。

| `mode` | `--kind` | `--version` |
| --- | --- | --- |
| `chrome` | `BridgeChrome` | `V3` |
| `edge` | `BridgeEdge` | `V3` |
| `360se` | `Bridge360` | `V2` |
| `firefox` | `BridgeFirefox` | `V2` |

下面示例对应 `mode=edge`；把 `--kind` / `--version` 换成上表对应值：

```bash
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process 'D:\影刀6.3.9\shadowbot-6.3.9\support_x64\chrome\ShadowBot.BrowserBridge.Installer.exe' -ArgumentList '--kind=BridgeEdge','--version=V3'"
```

路径为 `INSTALLER_PATH_UNAVAILABLE`，或 `Start-Process` 失败时：请用户打开 **用户设置** 中的插件安装页面。bash 权限为 `ask` 且用户拒绝时，同样改走该页面。

## 自定义浏览器

`code=custom_browser_extension_install_required` 时，请用户打开 **用户设置** 中的插件安装页面，再选择 **添加自定义浏览器自动化**，按返回的 `mode` 安装对应浏览器。

## 内置影刀浏览器（ShadowBotBrowser，mode=cef）

`code=shadowbot_browser_bridge_unavailable` 时，ShadowBotBrowser（1.0/2.0）是随客户端一起安装的内置浏览器，不是需要另外装扩展的外部浏览器，禁止走上面两条"装插件"路径，也不要引导用户去 **添加自定义浏览器自动化**。

请用户完全关闭正在运行的影刀浏览器（含后台进程），再重新打开一次；确认关闭并重新打开完成后再继续。

## 等待与恢复

安装器可能要求关闭正在运行的浏览器。向用户展示安装指引，等待用户明确回复：安装完成、插件已启用，且目标浏览器已打开。确认后再按原任务重新派发 Explorer。
