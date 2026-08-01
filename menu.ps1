#Requires -RunAsAdministrator
$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Set Console Title
$host.UI.RawUI.WindowTitle = "Administrator: Flipper Deployment Center"

$manifestUrl = "https://pluizigegamer.github.io/Driver/manifest.json"

# Fetch Manifest
try {
    $tools = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing
} catch {
    Write-Host "`n [!] Failed to fetch configuration manifest from GitHub." -ForegroundColor Red
    Start-Sleep -Seconds 3
    Exit
}

# Reusable Installation Handler
function Install-Tool {
    param($tool)
    Write-Host "`n [*] Downloading: $($tool.name)..." -ForegroundColor Yellow
    $tempFile = "$env:TEMP\$($tool.id).exe"
    try {
        Invoke-WebRequest -Uri $tool.url -OutFile $tempFile -UseBasicParsing
        Write-Host " [*] Installing: $($tool.name)..." -ForegroundColor Cyan
        Start-Process -FilePath $tempFile -ArgumentList $tool.args -Wait
        Remove-Item $tempFile -Force
        Write-Host " [+] Successfully installed $($tool.name)!" -ForegroundColor Green
    } catch {
        Write-Host " [!] Error installing $($tool.name): $_" -ForegroundColor Red
    }
}

# ==========================================
# 1. DIRECT FLIPPER INSTALL MODE (NO MENU)
# ==========================================
if ($env:FLIPPER_TARGET) {
    Clear-Host
    Write-Host "`n [!] Direct Install Triggered for: $env:FLIPPER_TARGET" -ForegroundColor Cyan
    $targetTool = $tools | Where-Object { $_.id -eq $env:FLIPPER_TARGET }
    
    if ($targetTool) {
        Install-Tool -tool $targetTool
    } else {
        Write-Host " [!] Driver ID '$env:FLIPPER_TARGET' not found in manifest." -ForegroundColor Red
    }
    Exit
}

# ==========================================
# 2. PERSISTENT INTERACTIVE MENU (MAS STYLE)
# ==========================================
$groupedTools = $tools | Group-Object category
$state = "MAIN"
$selectedGroup = $null

while ($true) {
    Clear-Host
    Write-Host ""
    Write-Host ""
    Write-Host "       ----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host ""

    if ($state -eq "MAIN") {
        Write-Host "               Driver Categories:" -ForegroundColor White
        Write-Host ""
        
        $catMap = @{}
        $i = 1
        foreach ($group in $groupedTools) {
            Write-Host "               [" -NoNewline -ForegroundColor Gray
            Write-Host "$i" -NoNewline -ForegroundColor Green
            Write-Host "] $($group.Name)" -ForegroundColor White
            $catMap[$i.ToString()] = $group
            $i++
        }
        
        Write-Host ""
        Write-Host "       ----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host ""
        Write-Host "               [" -NoNewline -ForegroundColor Gray
        Write-Host "Q" -NoNewline -ForegroundColor Red
        Write-Host "] Quit" -ForegroundColor White
        Write-Host ""
        Write-Host "       ----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host ""
        
        $maxOpt = $i - 1
        Write-Host "       Choose a menu option using your keyboard [1..$maxOpt, Q] : " -NoNewline -ForegroundColor Green
        $choice = Read-Host
        $choice = $choice.Trim().ToUpper()

        if ($choice -eq 'Q') { Exit }
        if ($catMap.ContainsKey($choice)) {
            $selectedGroup = $catMap[$choice]
            $state = "SUB"
        }
    }
    elseif ($state -eq "SUB") {
        Write-Host "               $($selectedGroup.Name.ToUpper()):" -ForegroundColor White
        Write-Host ""
        
        $toolMap = @{}
        $i = 1
        foreach ($tool in $selectedGroup.Group) {
            Write-Host "               [" -NoNewline -ForegroundColor Gray
            Write-Host "$i" -NoNewline -ForegroundColor Green
            Write-Host "] $($tool.name)" -ForegroundColor White
            $toolMap[$i.ToString()] = $tool
            $i++
        }
        
        Write-Host ""
        Write-Host "       ----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host ""
        Write-Host "               [" -NoNewline -ForegroundColor Gray
        Write-Host "B" -NoNewline -ForegroundColor Red
        Write-Host "] Go Back" -ForegroundColor White
        Write-Host ""
        Write-Host "       ----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "       Select drivers (e.g. 1 or 1,3) or B : " -NoNewline -ForegroundColor Green
        $choice = Read-Host
        $choice = $choice.Trim().ToUpper()

        if ($choice -eq 'B') {
            $state = "MAIN"
        } else {
            # Parse comma-separated choices (e.g. "1, 3")
            $selections = $choice -split ',' | ForEach-Object { $_.Trim() }
            $installedAny = $false
            
            foreach ($sel in $selections) {
                if ($toolMap.ContainsKey($sel)) {
                    Install-Tool -tool $toolMap[$sel]
                    $installedAny = $true
                }
            }
            
            if ($installedAny) {
                Write-Host "`n       Press Enter to return to menu..." -ForegroundColor Gray
                Read-Host
            }
        }
    }
}
