#Requires -RunAsAdministrator
$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ==========================================
# FORCE COMMAND PROMPT THEME
# ==========================================
[Console]::BackgroundColor = [ConsoleColor]::Black
[Console]::ForegroundColor = [ConsoleColor]::Gray
$host.UI.RawUI.WindowTitle = "Command Prompt"
Clear-Host

$manifestUrl = "https://pluizigegamer.github.io/Driver/manifest.json"

# ==========================================
# 1. DIRECT INSTALL BYPASS (NO MENU)
# ==========================================
if ($env:FLIPPER_TARGET) {
    $tools = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing
    $targetTool = $tools | Where-Object { $_.id -eq $env:FLIPPER_TARGET }
    
    if ($targetTool) {
        $tempFile = "$env:TEMP\$($targetTool.id).exe"
        Invoke-WebRequest -Uri $targetTool.url -OutFile $tempFile -UseBasicParsing
        Start-Process -FilePath $tempFile -ArgumentList $targetTool.args -Wait
        Remove-Item $tempFile -Force
    }
    # Reset colors and exit
    [Console]::ResetColor()
    Exit
}

# ==========================================
# 2. INTERACTIVE UI MODE
# ==========================================
try {
    $tools = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing
} catch {
    Write-Host "[!] Failed to fetch configuration manifest from GitHub." -ForegroundColor Red
    Start-Sleep -Seconds 3
    Exit
}

function Install-Tool {
    param($tool)
    Write-Host "`n[*] Downloading $($tool.name)..." -ForegroundColor Yellow
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

$groupedTools = $tools | Group-Object category

while ($true) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       SELECT A DRIVER CATEGORY         " -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $catIndex = 1
    $catMap = @{}
    foreach ($group in $groupedTools) {
        Write-Host "  [$catIndex] $($group.Name)" -ForegroundColor Gray
        $catMap[$catIndex.ToString()] = $group
        $catIndex++
    }
    
    Write-Host "`n  [Q] Exit" -ForegroundColor DarkRed
    Write-Host "========================================" -ForegroundColor Cyan
    
    $choice = Read-Host "`nSelect category"
    if ($choice.ToUpper() -eq 'Q') { 
        [Console]::ResetColor()
        Clear-Host
        Exit 
    }

    if ($catMap.ContainsKey($choice)) {
        $selectedGroup = $catMap[$choice]
        $inCategory = $true
        
        while ($inCategory) {
            Clear-Host
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host " FOLDER: $($selectedGroup.Name.ToUpper())" -ForegroundColor Yellow
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            
            $toolIndex = 1
            $toolMap = @{}
            foreach ($tool in $selectedGroup.Group) {
                Write-Host "  [$toolIndex] $($tool.name)" -ForegroundColor Gray
                $toolMap[$toolIndex.ToString()] = $tool
                $toolIndex++
            }
            
            Write-Host "`n  [B] Go Back" -ForegroundColor DarkGray
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "Hint: Select multiple by separating with commas (e.g., 1, 3)" -ForegroundColor DarkGray
            
            $subChoice = Read-Host "`nSelect drivers to install"
            
            if ($subChoice.ToUpper() -eq 'B') {
                $inCategory = $false
            } else {
                # Handle comma-separated inputs (e.g., "1, 3")
                $selections = $subChoice -split ',' | ForEach-Object { $_.Trim() }
                $installedAny = $false
                
                foreach ($sel in $selections) {
                    if ($toolMap.ContainsKey($sel)) {
                        Install-Tool -tool $toolMap[$sel]
                        $installedAny = $true
                    }
                }
                
                if ($installedAny) {
                    Read-Host "`nInstallations complete. Press Enter to continue..."
                } else {
                    Write-Host "[!] Invalid selection." -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
        }
    }
}
