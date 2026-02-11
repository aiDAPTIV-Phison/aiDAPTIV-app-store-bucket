# aiDAPTIV+ Auto Installer - PowerShell Version
# Auto install to all Obsidian Vaults

param(
    [string]$InstallDir = "",
    [switch]$Verbose = $false,
    [int]$RestartObsidian = 0  # 0 = no restart, 1 = restart Obsidian
)

# Set console encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Function to find all Obsidian processes (multi-method detection)
function Get-ObsidianProcesses {
    $processes = @()
    
    # Method 1: Try exact name match
    $processes += Get-Process -Name "Obsidian" -ErrorAction SilentlyContinue
    
    # Method 2: Try case-insensitive wildcard match (in case of different naming)
    if ($processes.Count -eq 0) {
        $processes += Get-Process | Where-Object { $_.ProcessName -like "*obsidian*" }
    }
    
    # Method 3: Match by executable path (most reliable)
    if ($processes.Count -eq 0) {
        $processes += Get-Process | Where-Object { 
            try {
                $_.Path -and ($_.Path -like "*obsidian*")
            } catch {
                $false
            }
        }
    }
    
    return $processes
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "aiDAPTIV+ Auto Installer (PowerShell)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Determine script directory
if ([string]::IsNullOrEmpty($InstallDir)) {
    $InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Plugin source path (Scoop extracts the zip, so we look for the folder)
$PluginSourceDir = Join-Path $InstallDir "aiDAPTIV-Integration-Obsidian"
$PluginZip = Join-Path $InstallDir "aiDAPTIV-Integration-Obsidian.zip"

# Check if plugin source exists (folder or zip)
$UseExtractedFolder = $false
if (Test-Path $PluginSourceDir) {
    $UseExtractedFolder = $true
    Write-Host "[OK] Plugin folder found!" -ForegroundColor Green
} elseif (Test-Path $PluginZip) {
    $UseExtractedFolder = $false
    Write-Host "[OK] Plugin zip found!" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Plugin source not found:" -ForegroundColor Red
    Write-Host "  Folder: $PluginSourceDir" -ForegroundColor Red
    Write-Host "  Zip: $PluginZip" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure the plugin files exist." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
Write-Host ""

# Check if obsidian.json exists
$ObsidianConfig = Join-Path $env:APPDATA "obsidian\obsidian.json"
if (-not (Test-Path $ObsidianConfig)) {
    Write-Host "[ERROR] Obsidian config file not found:" -ForegroundColor Red
    Write-Host "  $ObsidianConfig" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure Obsidian is installed and has been opened at least once." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "[OK] Obsidian config file found!" -ForegroundColor Green
Write-Host ""
Write-Host "Scanning all your Vaults..." -ForegroundColor Cyan
Write-Host ""

try {
    # Parse Obsidian configuration
    $obsidianConfigContent = Get-Content $ObsidianConfig -Raw | ConvertFrom-Json

    $vaultCount = 0
    $installedCount = 0
    $skippedCount = 0
    $errorCount = 0

    foreach ($vault in $obsidianConfigContent.vaults.PSObject.Properties) {
        $vaultCount++
        $vaultPath = $vault.Value.path
        $vaultName = Split-Path $vaultPath -Leaf

        Write-Host "[$vaultCount] Checking Vault: $vaultName" -ForegroundColor White
        if ($Verbose) {
            Write-Host "    Path: $vaultPath" -ForegroundColor Gray
        }

        # Check if vault path exists
        if (-not (Test-Path $vaultPath)) {
            Write-Host "    [SKIP] Vault path does not exist" -ForegroundColor Yellow
            continue
        }

        # Define plugin paths
        $obsidianDir = Join-Path $vaultPath '.obsidian'
        $pluginsDir = Join-Path $obsidianDir 'plugins'
        $pluginDir = Join-Path $pluginsDir 'aiDAPTIV-Integration-Obsidian'
        $mainJs = Join-Path $pluginDir 'main.js'
        $manifestJson = Join-Path $pluginDir 'manifest.json'

        # Check if plugin is already installed (comprehensive check)
        if ((Test-Path $pluginDir) -and (Test-Path $mainJs) -and (Test-Path $manifestJson)) {
            Write-Host "    [SKIP] Plugin already installed" -ForegroundColor Green
            $skippedCount++
            continue
        }

        Write-Host "    [INSTALL] Installing plugin..." -ForegroundColor Cyan

        try {
            # Create directories if they don't exist
            if (-not (Test-Path $obsidianDir)) {
                New-Item -ItemType Directory -Path $obsidianDir -Force | Out-Null
                if ($Verbose) { Write-Host "    Created .obsidian folder" -ForegroundColor Gray }
            }

            if (-not (Test-Path $pluginsDir)) {
                New-Item -ItemType Directory -Path $pluginsDir -Force | Out-Null
                if ($Verbose) { Write-Host "    Created plugins folder" -ForegroundColor Gray }
            }

            # Remove existing plugin folder if it exists (might be incomplete)
            if (Test-Path $pluginDir) {
                Remove-Item -Path $pluginDir -Recurse -Force
                if ($Verbose) { Write-Host "    Removed incomplete plugin folder" -ForegroundColor Gray }
            }

            # Create plugin directory
            New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null

            if ($UseExtractedFolder) {
                # Copy from extracted folder
                if ($Verbose) { Write-Host "    Copying from extracted folder..." -ForegroundColor Gray }
                Copy-Item -Path "$PluginSourceDir\*" -Destination $pluginDir -Recurse -Force
            } else {
                # Extract from zip file
                if ($Verbose) { Write-Host "    Extracting from zip file..." -ForegroundColor Gray }
                Expand-Archive -Path $PluginZip -DestinationPath $pluginDir -Force

                # Check if files were extracted to a subfolder and move them up
                $subfolderPath = Join-Path $pluginDir 'aiDAPTIV-Integration-Obsidian'
                if (Test-Path $subfolderPath) {
                    if ($Verbose) { Write-Host "    Moving files from subfolder..." -ForegroundColor Gray }
                    Get-ChildItem -Path $subfolderPath | Move-Item -Destination $pluginDir -Force
                    Remove-Item -Path $subfolderPath -Recurse -Force
                }
            }

            # Verify installation
            if ((Test-Path $mainJs) -and (Test-Path $manifestJson)) {
                Write-Host "    [SUCCESS] Installation successful!" -ForegroundColor Green
                $installedCount++
            } else {
                Write-Host "    [ERROR] Installation failed - missing required files" -ForegroundColor Red
                $errorCount++

                if ($Verbose) {
                    Write-Host "    Check results:" -ForegroundColor Gray
                    Write-Host "      main.js: $(if (Test-Path $mainJs) { 'exists' } else { 'missing' })" -ForegroundColor Gray
                    Write-Host "      manifest.json: $(if (Test-Path $manifestJson) { 'exists' } else { 'missing' })" -ForegroundColor Gray
                }
            }

        } catch {
            Write-Host "    [ERROR] Installation error: $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
        }

        Write-Host ""
    }

} catch {
    Write-Host "[ERROR] Critical error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    if ($Verbose) {
        Write-Host "Detailed error information:" -ForegroundColor Gray
        Write-Host $_.Exception.StackTrace -ForegroundColor Gray
    }
    exit 1
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Vaults found: $vaultCount" -ForegroundColor White
Write-Host "Newly installed: $installedCount" -ForegroundColor Green
Write-Host "Already installed (skipped): $skippedCount" -ForegroundColor Yellow
if ($errorCount -gt 0) {
    Write-Host "Installation failed: $errorCount" -ForegroundColor Red
}
Write-Host ""

# Handle Obsidian restart if requested
if ($RestartObsidian -eq 1) {
    Write-Host ""
    Write-Host "Restarting Obsidian..." -ForegroundColor Cyan

    # Kill existing Obsidian processes
    $obsidianProcesses = Get-ObsidianProcesses
    if ($obsidianProcesses -and $obsidianProcesses.Count -gt 0) {
        Write-Host "Closing existing Obsidian instances..." -ForegroundColor Yellow
        if ($Verbose) {
            Write-Host "    Found $($obsidianProcesses.Count) Obsidian process(es)" -ForegroundColor Gray
        }
        $obsidianProcesses | Stop-Process -Force
        Start-Sleep -Seconds 2
    }

    # Try to find and start Obsidian - expanded search paths
    $obsidianPaths = @(
        "${env:LOCALAPPDATA}\Obsidian\Obsidian.exe",
        "${env:LOCALAPPDATA}\Programs\Obsidian\Obsidian.exe",
        "${env:PROGRAMFILES}\Obsidian\Obsidian.exe",
        "${env:PROGRAMFILES(x86)}\Obsidian\Obsidian.exe",
        "${env:APPDATA}\Obsidian\Obsidian.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Obsidian\Obsidian.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Programs\Obsidian\Obsidian.exe"
    )

    # Also try to find via Windows Registry or Start Menu
    try {
        $startMenuPath = Get-ChildItem -Path "${env:APPDATA}\Microsoft\Windows\Start Menu\Programs" -Recurse -Filter "*Obsidian*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($startMenuPath) {
            $obsidianPaths += $startMenuPath.FullName
        }
    } catch { }

    # Try to find via Get-Command (if in PATH)
    try {
        $obsidianCmd = Get-Command "Obsidian" -ErrorAction SilentlyContinue
        if ($obsidianCmd) {
            $obsidianPaths += $obsidianCmd.Source
        }
    } catch { }

    # Remove duplicates and filter existing paths
    $obsidianPaths = $obsidianPaths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    $obsidianFound = $false

    # Try each path
    foreach ($path in $obsidianPaths) {
        try {
            Write-Host "Starting Obsidian from: $path" -ForegroundColor Green
            # Use cmd /c start to completely detach from console
            Start-Process cmd.exe -ArgumentList "/c", "start", '""', "`"$path`"" -WindowStyle Hidden
            $obsidianFound = $true
            break
        } catch {
            if ($Verbose) {
                Write-Host "    Failed to start from: $path" -ForegroundColor Gray
            }
        }
    }

    # If still not found, try alternative methods
    if (-not $obsidianFound) {
        # Try using Windows 'where' command
        try {
            $whereResult = cmd /c "where obsidian.exe 2>nul"
            if ($whereResult -and (Test-Path $whereResult)) {
                Write-Host "Starting Obsidian from: $whereResult" -ForegroundColor Green
                Start-Process cmd.exe -ArgumentList "/c", "start", '""', "`"$whereResult`"" -WindowStyle Hidden
                $obsidianFound = $true
            }
        } catch { }
    }

    # Last resort: try to start via Windows Start Menu shortcut
    if (-not $obsidianFound) {
        try {
            $shortcut = Get-ChildItem -Path "${env:APPDATA}\Microsoft\Windows\Start Menu\Programs" -Recurse -Filter "*Obsidian*.lnk" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($shortcut) {
                Write-Host "Starting Obsidian via shortcut: $($shortcut.Name)" -ForegroundColor Green
                Start-Process cmd.exe -ArgumentList "/c", "start", '""', "`"$($shortcut.FullName)`"" -WindowStyle Hidden
                $obsidianFound = $true
            }
        } catch { }
    }

    if (-not $obsidianFound) {
        Write-Host "Could not find Obsidian executable. Please start Obsidian manually." -ForegroundColor Yellow
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Start Obsidian" -ForegroundColor White
        Write-Host "2. Go to Settings > Community plugins" -ForegroundColor White
        Write-Host "3. Enable 'aiDAPTIV-Integration-Obsidian' plugin" -ForegroundColor White
    } else {
        Write-Host "Obsidian restarted successfully!" -ForegroundColor Green
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Go to Settings > Community plugins" -ForegroundColor White
        Write-Host "2. Enable 'aiDAPTIV-Integration-Obsidian' plugin" -ForegroundColor White
    }
} elseif ($installedCount -gt 0) {
    # Auto-restart Obsidian if new installations were made
    Write-Host ""
    Write-Host "Starting/Restarting Obsidian..." -ForegroundColor Cyan
    
    # Check if Obsidian is running and close it
    $obsidianProcesses = Get-ObsidianProcesses
    if ($obsidianProcesses -and $obsidianProcesses.Count -gt 0) {
        Write-Host "Closing existing Obsidian instances..." -ForegroundColor Yellow
        if ($Verbose) {
            Write-Host "    Found $($obsidianProcesses.Count) Obsidian process(es)" -ForegroundColor Gray
        }
        $obsidianProcesses | Stop-Process -Force
        Start-Sleep -Seconds 2
    }

    # Try to find and start Obsidian
    $obsidianPaths = @(
        "${env:LOCALAPPDATA}\Obsidian\Obsidian.exe",
        "${env:LOCALAPPDATA}\Programs\Obsidian\Obsidian.exe",
        "${env:PROGRAMFILES}\Obsidian\Obsidian.exe",
        "${env:PROGRAMFILES(x86)}\Obsidian\Obsidian.exe",
        "${env:APPDATA}\Obsidian\Obsidian.exe"
    )

    # Try to find via Get-Command (if in PATH)
    try {
        $obsidianCmd = Get-Command "Obsidian" -ErrorAction SilentlyContinue
        if ($obsidianCmd) {
            $obsidianPaths += $obsidianCmd.Source
        }
    } catch { }

    # Try using Windows 'where' command
    try {
        $whereResult = cmd /c "where obsidian.exe 2>nul"
        if ($whereResult) {
            $whereResults = $whereResult -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and (Test-Path $_) }
            $obsidianPaths += $whereResults
        }
    } catch { }

    # Try to find via Start Menu shortcut
    try {
        $shortcut = Get-ChildItem -Path "${env:APPDATA}\Microsoft\Windows\Start Menu\Programs" -Recurse -Filter "*Obsidian*.lnk" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($shortcut) {
            try {
                $shell = New-Object -ComObject WScript.Shell
                $shortcutObj = $shell.CreateShortcut($shortcut.FullName)
                $targetPath = $shortcutObj.TargetPath
                if ($targetPath -and (Test-Path $targetPath)) {
                    $obsidianPaths += $targetPath
                }
            } catch { }
        }
    } catch { }

    # Remove duplicates and filter existing paths
    $obsidianPaths = $obsidianPaths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    $obsidianFound = $false

    # Try each path
    foreach ($path in $obsidianPaths) {
        try {
            Write-Host "Starting Obsidian from: $path" -ForegroundColor Green
            # Use cmd /c start to completely detach from console
            Start-Process cmd.exe -ArgumentList "/c", "start", '""', "`"$path`"" -WindowStyle Hidden
            $obsidianFound = $true
            break
        } catch {
            if ($Verbose) {
                Write-Host "    Failed to start from: $path" -ForegroundColor Gray
                Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
            }
        }
    }

    if (-not $obsidianFound) {
        Write-Host "Could not auto-start Obsidian. Please start it manually." -ForegroundColor Yellow
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Start Obsidian" -ForegroundColor White
        Write-Host "2. Go to Settings > Community plugins" -ForegroundColor White
        Write-Host "3. Enable 'aiDAPTIV-Integration-Obsidian' plugin" -ForegroundColor White
    } else {
        Write-Host "Obsidian started successfully!" -ForegroundColor Green
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Go to Settings > Community plugins" -ForegroundColor White
        Write-Host "2. Enable 'aiDAPTIV-Integration-Obsidian' plugin" -ForegroundColor White
    }
} else {
    # Show message if no new installations
    if ($skippedCount -gt 0 -and $errorCount -eq 0) {
        Write-Host "All Vaults already have the plugin installed!" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Installation script completed." -ForegroundColor Green

