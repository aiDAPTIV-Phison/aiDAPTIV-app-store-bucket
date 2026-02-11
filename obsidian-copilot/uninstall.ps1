# aiDAPTIV+ Auto Uninstaller - SECURE VERSION
# Auto uninstall from all Obsidian Vaults

$ErrorActionPreference = 'SilentlyContinue'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "aiDAPTIV+ SECURE Uninstaller" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$targetPluginName = "aiDAPTIV-Integration-Obsidian"

# Check if obsidian.json exists
$ObsidianConfig = Join-Path $env:APPDATA "obsidian\obsidian.json"
if (-not (Test-Path $ObsidianConfig)) {
    Write-Host "[INFO] Obsidian config not found. Nothing to do." -ForegroundColor Yellow
    exit 0
}

$config = $null
try {
    $config = Get-Content $ObsidianConfig -Raw | ConvertFrom-Json
}
catch {
    Write-Host "[ERROR] Failed to parse Obsidian config: $($_.Exception.Message)" -ForegroundColor Red
    exit 0
}

if ($null -eq $config -or $null -eq $config.vaults) {
    Write-Host "[INFO] No vaults found in Obsidian config." -ForegroundColor Yellow
    exit 0
}

foreach ($vault in $config.vaults.PSObject.Properties) {
    $vaultPath = $vault.Value.path
    if (-not (Test-Path $vaultPath)) { continue }

    $pluginsPath = Join-Path $vaultPath ".obsidian\plugins"
    if (-not (Test-Path $pluginsPath)) { continue }

    $pluginDir = Join-Path $pluginsPath $targetPluginName

    if (-not (Test-Path $pluginDir)) { continue }

    $item = Get-Item $pluginDir -ErrorAction SilentlyContinue
    if ($null -eq $item) { continue }

    # Safety checks
    if (-not $item.PSIsContainer) { continue }
    if ($item.Name -ne $targetPluginName) { continue }

    $manifestCheck = Join-Path $pluginDir "manifest.json"
    if (-not (Test-Path $manifestCheck)) {
        Write-Host "[SKIP] No manifest.json in $pluginDir" -ForegroundColor Yellow
        continue
    }

    Write-Host "[REMOVE] $vaultPath" -ForegroundColor Green
    Remove-Item -Path $pluginDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Uninstallation cleanup finished." -ForegroundColor Green
