$ErrorActionPreference = 'Stop'

Write-Host "[INFO] Starting Obsidian..."

# Stop existing Obsidian processes (multi-method detection)
$obsidianProcesses = @()
$obsidianProcesses += Get-Process -Name "Obsidian" -ErrorAction SilentlyContinue
if ($obsidianProcesses.Count -eq 0) {
    $obsidianProcesses += Get-Process | Where-Object { $_.ProcessName -like "*obsidian*" }
}
if ($obsidianProcesses.Count -eq 0) {
    $obsidianProcesses += Get-Process | Where-Object {
        try { $_.Path -and ($_.Path -like "*obsidian*") } catch { $false }
    }
}

if ($obsidianProcesses -and $obsidianProcesses.Count -gt 0) {
    Write-Host "[INFO] Closing existing Obsidian instances ($($obsidianProcesses.Count) found)..."
    $obsidianProcesses | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# Search paths for Obsidian executable
$obsidianPaths = @(
    "${env:LOCALAPPDATA}\Obsidian\Obsidian.exe",
    "${env:LOCALAPPDATA}\Programs\Obsidian\Obsidian.exe",
    "${env:PROGRAMFILES}\Obsidian\Obsidian.exe",
    "${env:PROGRAMFILES(x86)}\Obsidian\Obsidian.exe",
    "${env:APPDATA}\Obsidian\Obsidian.exe"
)

try {
    $obsidianCmd = Get-Command "Obsidian" -ErrorAction SilentlyContinue
    if ($obsidianCmd) { $obsidianPaths += $obsidianCmd.Source }
} catch { }

try {
    $whereResult = cmd /c "where obsidian.exe 2>nul"
    if ($whereResult) {
        $obsidianPaths += ($whereResult -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and (Test-Path $_) })
    }
} catch { }

try {
    $shortcut = Get-ChildItem -Path "${env:APPDATA}\Microsoft\Windows\Start Menu\Programs" -Recurse -Filter "*Obsidian*.lnk" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($shortcut) {
        $shell = New-Object -ComObject WScript.Shell
        $targetPath = $shell.CreateShortcut($shortcut.FullName).TargetPath
        if ($targetPath -and (Test-Path $targetPath)) { $obsidianPaths += $targetPath }
    }
} catch { }

$obsidianPaths = $obsidianPaths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

# Try to start Obsidian from discovered paths
foreach ($path in $obsidianPaths) {
    try {
        Write-Host "[INFO] Starting Obsidian from: $path"
        Start-Process cmd.exe -ArgumentList "/c", "start", '""', "`"$path`"" -WindowStyle Hidden
        Write-Host "[INFO] Obsidian started successfully"
        exit 0
    } catch { }
}

# Last resort: try shortcut directly
try {
    $shortcut = Get-ChildItem -Path "${env:APPDATA}\Microsoft\Windows\Start Menu\Programs" -Recurse -Filter "*Obsidian*.lnk" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($shortcut) {
        Write-Host "[INFO] Starting Obsidian via shortcut: $($shortcut.Name)"
        Start-Process cmd.exe -ArgumentList "/c", "start", '""', "`"$($shortcut.FullName)`"" -WindowStyle Hidden
        Write-Host "[INFO] Obsidian started successfully"
        exit 0
    }
} catch { }

Write-Error "Failed to find Obsidian executable. Please start Obsidian manually."
exit 1
