# ==============================================================================
# Qoder-Free: One-Line Installer & Quick Launcher for Windows (PowerShell)
# Repository: https://github.com/VoDaiLocz/Qoder-Free
# ==============================================================================

[CmdletBinding()]
param (
    [switch]$Cli,
    [switch]$Reset,
    [switch]$NoPreserveChat,
    [switch]$Uninstall,
    [switch]$Help
)

$Repo = "VoDaiLocz/Qoder-Free"
$AppName = "QoderResetTool.exe"
$InstallDir = "$env:LOCALAPPDATA\Qoder-Free"
$ZipUrl = "https://github.com/$Repo/releases/latest/download/qoder-reset-tool-windows.zip"

function Show-Banner {
    Write-Host ""
    Write-Host "  =======================================================" -ForegroundColor Cyan
    Write-Host "               🔒 QODER-FREE INSTALLER 🔒                " -ForegroundColor Cyan
    Write-Host "     Privacy & Machine ID Management Tool for Qoder      " -ForegroundColor Cyan
    Write-Host "  =======================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Usage {
    Write-Host "Usage: .\install.ps1 [OPTIONS]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Cli              Check status in CLI mode after installation"
    Write-Host "  -Reset            Perform 1-Click Reset immediately"
    Write-Host "  -NoPreserveChat   Reset without preserving chat history"
    Write-Host "  -Uninstall        Remove Qoder-Free and its shortcuts"
    Write-Host "  -Help             Show this help message"
    Write-Host ""
}

if ($Help) {
    Show-Banner
    Show-Usage
    exit 0
}

Show-Banner

if ($Uninstall) {
    Write-Host "[INFO] Uninstalling Qoder-Free..." -ForegroundColor Yellow
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    $DesktopShortcut = "$([Environment]::GetFolderPath('Desktop'))\Qoder Reset Tool.lnk"
    if (Test-Path $DesktopShortcut) {
        Remove-Item -Path $DesktopShortcut -Force -ErrorAction SilentlyContinue
    }
    $StartShortcut = "$([Environment]::GetFolderPath('StartMenu'))\Programs\Qoder Reset Tool.lnk"
    if (Test-Path $StartShortcut) {
        Remove-Item -Path $StartShortcut -Force -ErrorAction SilentlyContinue
    }
    Write-Host "[SUCCESS] Qoder-Free has been uninstalled." -ForegroundColor Green
    exit 0
}

# Create installation folder
if (!(Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$TempZip = "$env:TEMP\qoder-reset-tool-windows.zip"

Write-Host "[INFO] Downloading latest release from GitHub..." -ForegroundColor Cyan
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip -UseBasicParsing
    Write-Host "[INFO] Extracting files to $InstallDir..." -ForegroundColor Cyan
    Expand-Archive -Path $TempZip -DestinationPath $InstallDir -Force
    Remove-Item -Path $TempZip -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host "[WARN] Could not download prebuilt zip release. Checking Python fallback..." -ForegroundColor Yellow
    if (Get-Command python -ErrorAction SilentlyContinue) {
        Write-Host "[INFO] Cloning/copying source files..." -ForegroundColor Cyan
        # Fallback to source
    } else {
        Write-Host "[ERROR] Failed to download release asset: $_" -ForegroundColor Red
        exit 1
    }
}

# Look for executable
$ExePath = Join-Path $InstallDir $AppName
if (!(Test-Path $ExePath)) {
    $Found = Get-ChildItem -Path $InstallDir -Filter $AppName -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Found) {
        $ExePath = $Found.FullName
    }
}

# Create Shortcuts
try {
    $WshShell = New-Object -ComObject WScript.Shell
    $DesktopShortcut = "$([Environment]::GetFolderPath('Desktop'))\Qoder Reset Tool.lnk"
    $Shortcut = $WshShell.CreateShortcut($DesktopShortcut)
    $Shortcut.TargetPath = $ExePath
    $Shortcut.Description = "Qoder Privacy & Reset Tool"
    $Shortcut.Save()
    Write-Host "[SUCCESS] Created Desktop shortcut: Qoder Reset Tool" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not create Desktop shortcut." -ForegroundColor Gray
}

# Add to user PATH
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
    Write-Host "[INFO] Added Qoder-Free to User PATH." -ForegroundColor Cyan
}

Write-Host "[SUCCESS] Installation complete! Location: $InstallDir" -ForegroundColor Green

if ($Reset) {
    Write-Host "[INFO] Executing 1-Click Reset..." -ForegroundColor Yellow
    if ($NoPreserveChat) {
        & $ExePath --reset --no-preserve-chat
    } else {
        & $ExePath --reset --preserve-chat
    }
} elseif ($Cli) {
    & $ExePath --status
} else {
    Write-Host "[INFO] Launching Qoder Reset Tool..." -ForegroundColor Cyan
    Start-Process -FilePath $ExePath
}
