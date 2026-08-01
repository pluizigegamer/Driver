param(
    [string]$TargetId
)

#Requires -RunAsAdministrator
$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$manifestUrl = "https://pluizigegamer.github.io/Driver/manifest.json"
try {
    $tools = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing
} catch {
    Write-Host "[!] Failed to fetch configuration manifest from GitHub." -ForegroundColor Red
    if (-not $TargetId) { Start-Sleep -Seconds 3 }
    Exit
}

function Install-Tool {
    param($tool)
    Write-Host "[*] Downloading $($tool.name)..." -ForegroundColor Yellow
    $tempFile = "$env:TEMP\$($tool.id).exe"
    try {
        Invoke-WebRequest -Uri $tool.url -OutFile $tempFile -UseBasicParsing
        Write-Host "[*] Installing $($tool.name)..." -ForegroundColor Yellow
        Start-Process -FilePath $tempFile -ArgumentList $tool.args -Wait
        Remove-Item $tempFile -Force
        Write-Host "[+] Successfully installed $($tool.name)!" -ForegroundColor Green
    } catch {
        Write-Host "[!] Error installing $($tool.name): $_" -ForegroundColor Red
    }
}

# DIRECT FLIPPER INSTALL MODE (e.g., menu.ps1 -TargetId nvidia)
if ($TargetId) {
    $matched = $tools | Where-Object { $_.id -eq $TargetId }
    if ($matched) {
        Install-Tool -tool $matched
    } else {
        Write-Host "[!] Driver ID '$TargetId' not found in manifest." -ForegroundColor Red
    }
    Exit
}

# INTERACTIVE CENTERED TERMINAL UI MODE
$host.UI.RawUI.WindowTitle = "Flipper Remote Deployment Center"
$groupedTools = $tools | Group-Object category

function Show-CenteredMenu {
    Clear-Host
    $maxWidth = 60
    $pad = [Math]::Max(0, [Math]::Floor((([Console]::WindowWidth - $maxWidth) / 2)))
    $indent = " " * $pad

    Write-Host ""
    Write-Host "$indent$([char]0x2554)$([char]0x2550 * ($maxWidth - 2))$([char]0x2557)" -ForegroundColor Cyan
    Write-Host "$indent$([char]0x2551)          FLIPPER ZERO REMOTE DEPLOYMENT CENTER          $([char]0x2551)" -ForegroundColor Yellow
    Write-Host "$indent$([char]0x2560)$([char]0x2550 * ($maxWidth - 2))$([char]0x2569)" -ForegroundColor Cyan

    foreach ($group in $groupedTools) {
        Write-Host ""
        Write-Host "$indent  $($group.Name.ToUpper())" -ForegroundColor DarkCyan
        Write-Host "$indent  $("-" * $($group.Name.Length + 2))" -ForegroundColor DarkGray
        
        foreach ($tool in $group.Group) {
            $line = "   [$($tool.id)] $($tool.name)"
            Write-Host "$indent$line" -ForegroundColor White
        }
    }

    Write-Host ""
    Write-Host "$indent  [A] Install All Listed Tools" -ForegroundColor Green
    Write-Host "$indent  [Q] Exit Terminal" -ForegroundColor Red
    Write-Host ""
    Write-Host "$indent$([char]0x255A)$([char]0x2550 * ($maxWidth - 2))$([char]0x2557)" -ForegroundColor Cyan
}

do {
    Show-CenteredMenu
    $choice = Read-Host "Select option ID"

    if ($choice -eq 'Q') { Break }
    if ($choice -eq 'A') {
        foreach ($tool in $tools) { Install-Tool -tool $tool }
        Read-Host "Batch complete. Press Enter to return..."
    } else {
        $selected = $tools | Where-Object { $_.id -eq $choice }
        if ($selected) {
            Install-Tool -tool $selected
            Read-Host "Installation finished. Press Enter to return..."
        }
    }
} while ($true)
