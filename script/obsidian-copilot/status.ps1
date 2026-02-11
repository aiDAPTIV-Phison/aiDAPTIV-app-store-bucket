$ErrorActionPreference = 'Stop'

$pluginName = "aiDAPTIV-Integration-Obsidian"

# Check if Obsidian process is running
try {
    $procs = Get-Process -Name 'Obsidian' -ErrorAction SilentlyContinue
    $isRunning = ($procs -ne $null -and $procs.Count -gt 0)
} catch {
    $isRunning = $false
}

# Check if plugin is installed in at least one vault
$isInstalled = $false
$obsidianConfigPath = Join-Path $env:APPDATA "obsidian\obsidian.json"

if (Test-Path $obsidianConfigPath) {
    try {
        $obsidianConfig = Get-Content $obsidianConfigPath -Raw | ConvertFrom-Json
        foreach ($vault in $obsidianConfig.vaults.PSObject.Properties) {
            $vaultPath = $vault.Value.path
            if (Test-Path $vaultPath) {
                $pluginDir = Join-Path $vaultPath ".obsidian\plugins\$pluginName"
                $mainJs = Join-Path $pluginDir "main.js"
                $manifestJson = Join-Path $pluginDir "manifest.json"

                if ((Test-Path $pluginDir) -and (Test-Path $mainJs) -and (Test-Path $manifestJson)) {
                    $isInstalled = $true
                    break
                }
            }
        }
    } catch {
        $isInstalled = $false
    }
}

# Return JSON status (1 only if Obsidian is running AND plugin is installed)
$status = if ($isRunning -and $isInstalled) { 1 } else { 0 }
$json = @{
    status = $status
} | ConvertTo-Json -Compress

Write-Host $json
