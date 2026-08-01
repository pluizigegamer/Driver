#Requires -RunAsAdministrator
$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$manifestUrl = "https://pluizigegamer.github.io/Driver/manifest.json"

# ==========================================
# 1. DIRECT FLIPPER INSTALL (NO MENU)
# ==========================================
# If the Flipper passes a target, install it silently in the current hidden window and exit.
if ($env:FLIPPER_TARGET) {
    $tools = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing
    $targetTool = $tools | Where-Object { $_.id -eq $env:FLIPPER_TARGET }
    
    if ($targetTool) {
        $tempFile = "$env:TEMP\$($targetTool.id).exe"
        Invoke-WebRequest -Uri $targetTool.url -OutFile $tempFile -UseBasicParsing
        Start-Process -FilePath $tempFile -ArgumentList $targetTool.args -Wait
        Remove-Item $tempFile -Force
    }
    Exit
}

# ==========================================
# 2. SPAWN SEPARATE WINDOW (JUST LIKE MAS)
# ==========================================
if ($env:FLIPPER_SPAWNED -ne '1') {
    # We are in the original terminal. Spawn a NEW separate terminal and exit this one.
    $spawnCmd = "`$env:FLIPPER_SPAWNED='1'; irm https://pluizigegamer.github.io/Driver/menu.ps1 | iex"
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -Command `"$spawnCmd`""
    Exit 
}

# ==========================================
# 3. CONTINUOUS MENU UI (Runs in the new window)
# ==========================================
# Make it look exactly like the MAS CMD window
$host.UI.RawUI.WindowTitle = "Administrator: Flipper Deployment Center"
[Console]::BackgroundColor = "Black"
[Console]::ForegroundColor = "Gray"
Clear-Host

try {
    $tools = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing
} catch {
    Write-Host "`n [!] Failed to fetch configuration manifest from GitHub." -ForegroundColor Red
    Start-Sleep -Seconds 3
    Exit
}

function Install-Tool {
    param($tool)
    Write-Host "`n       [*] Downloading: $($tool.name)..." -ForegroundColor Yellow
    $tempFile = "$env:TEMP\$($tool.id).exe"
    try {
        Invoke-WebRequest -Uri $tool.url -OutFile $tempFile -UseBasicParsing
        Write-Host "       [*] Installing: $($tool.name)..." -ForegroundColor Cyan
        Start-Process -FilePath $tempFile -ArgumentList $tool.args -Wait
        Remove-Item $tempFile -Force
        Write-Host "       [+] Successfully installed $($tool.name)!" -ForegroundColor Green
    } catch {
        Write-Host "       [!] Error installing $($tool.name): $_" -ForegroundColor Red
    }
}

$groupedTools = $tools | Group-Object category
$state = "MAIN"
$selectedGroup = $null

while ($true) {
    Clear-Host
    Write-Host ""
    Write-Host ""
    Write-Host "       ----------------------------------------------------------------"
    Write-Host ""

    if ($state -eq "MAIN") {
        Write-Host "               Driver Categories:" -ForegroundColor White
        Write-Host ""
        
        $catMap = @{}
        $i = 1
        foreach ($group in $groupedTools) {
            Write-Host "               [" -NoNewline; Write-Host "$i" -NoNewline -ForegroundColor Green; Write-Host "] $($group.Name)" -ForegroundColor White
            $catMap[$i.ToString()] = $group
            $i++
        }
        
        Write-Host ""
        Write-Host "       ----------------------------------------------------------------"
        Write-Host ""
        Write-Host "               [" -NoNewline; Write-Host "Q" -NoNewline -ForegroundColor Red; Write-Host "] Quit" -ForegroundColor White
        Write-Host ""
        Write-Host "       ----------------------------------------------------------------"
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
            Write-Host "               [" -NoNewline; Write-Host "$i" -NoNewline -ForegroundColor Green; Write-Host "] $($tool.name)" -ForegroundColor White
            $toolMap[$i.ToString()] = $tool
            $i++
        }
        
        Write-Host ""
        Write-Host "       ----------------------------------------------------------------"
        Write-Host ""
        Write-Host "               [" -NoNewline; Write-Host "B" -NoNewline -ForegroundColor Red; Write-Host "] Go Back" -ForegroundColor White
        Write-Host ""
        Write-Host "       ----------------------------------------------------------------"
        Write-Host ""
        
        Write-Host "       Select drivers (e.g. 1 or 1,3) or B : " -NoNewline -ForegroundColor Green
        $choice = Read-Host
        $choice = $choice.Trim().ToUpper()

        if ($choice -eq 'B') {
            $state = "MAIN"
        } else {
            # Handle comma-separated installs
            $selections = $choice -split ',' | ForEach-Object { $_.Trim() }
            $installedAny = $false
            
            foreach ($sel in $selections) {
                if ($toolMap.ContainsKey($sel)) {
                    Install-Tool -tool $toolMap[$sel]
                    $installedAny = $true
                }
            }
            
            if ($installedAny) {
                Write-Host "`n       Press Enter to return to menu..."
                Read-Host
            }
        }
    }
}
