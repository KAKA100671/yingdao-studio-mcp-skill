[CmdletBinding()]
param(
    [string]$ConfigPath = "$env:USERPROFILE\.config\opencode\opencode.json",
    [string]$ServerName = "studio-mcp"
)

$ErrorActionPreference = 'Stop'

function Test-McpEndpoint {
    param([int]$Port)
    $url = "http://127.0.0.1:$Port/api/v1/mcp"
    $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"sync-studio-mcp","version":"1.0"}}}'
    try {
        $resp = Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 3
        if ($resp.result.serverInfo.name -eq 'shadowbot-mcp-http') {
            return $url
        }
    } catch {}
    return $null
}

# 1. Locate ShadowBot.Shell process
$proc = Get-Process -Name 'ShadowBot.Shell' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) {
    Write-Error "ShadowBot.Shell process not found. Open ShadowBot Studio with an app first."
    exit 1
}
Write-Output "[1/4] ShadowBot.Shell PID: $($proc.Id)"

# 2. Enumerate its listening ports and probe for the MCP endpoint
$ports = Get-NetTCPConnection -State Listen -OwningProcess $proc.Id -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalAddress -in @('127.0.0.1', '::1', '0.0.0.0', '::') } |
    Select-Object -ExpandProperty LocalPort -Unique | Sort-Object

if (-not $ports) {
    Write-Error "No listening ports found on ShadowBot.Shell."
    exit 1
}
Write-Output "[2/4] Candidate ports: $($ports -join ', ')"

$mcpUrl = $null
foreach ($p in $ports) {
    $mcpUrl = Test-McpEndpoint -Port $p
    if ($mcpUrl) { break }
}
if (-not $mcpUrl) {
    Write-Error "No studio-mcp endpoint found on any listening port. Is the Studio app fully loaded?"
    exit 1
}
Write-Output "[3/4] Found studio-mcp endpoint: $mcpUrl"

# 3. Verify tool surface
$toolsBody = '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
$tools = Invoke-RestMethod -Uri $mcpUrl -Method Post -ContentType 'application/json' -Body $toolsBody -TimeoutSec 10
$toolCount = $tools.result.tools.Count
Write-Output "       tools/list OK, $toolCount tools exposed"

# 4. Merge into opencode config
if (-not (Test-Path $ConfigPath)) {
    Write-Error "opencode config not found at $ConfigPath"
    exit 1
}
$raw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
$cfg = $raw | ConvertFrom-Json

if (-not $cfg.PSObject.Properties['mcp']) {
    $cfg | Add-Member -NotePropertyName 'mcp' -NotePropertyValue ([pscustomobject]@{})
}
$entry = [pscustomobject]@{
    type    = 'remote'
    url     = $mcpUrl
    enabled = $true
}
if ($cfg.mcp.PSObject.Properties[$ServerName]) {
    $cfg.mcp.$ServerName = $entry
} else {
    $cfg.mcp | Add-Member -NotePropertyName $ServerName -NotePropertyValue $entry
}

$json = $cfg | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($ConfigPath, $json, (New-Object System.Text.UTF8Encoding $false))
Write-Output "[4/4] Wrote mcp.$ServerName -> $mcpUrl into $ConfigPath"
Write-Output ""
Write-Output "Done. Restart opencode to load the new MCP server."
