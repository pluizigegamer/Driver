#Requires -RunAsAdministrator
$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$manifestUrl = "https://pluizigegamer.github.io/Driver/manifest.json"
$choiceFile = "$env:TEMP\flipper_choice.txt"
$batPath = "$env:TEMP\flipper_menu.cmd"

# Fetch Manifest
try {
    $tools = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing
} catch {
    Write-Host "`n[!] Failed to fetch configuration manifest from GitHub." -ForegroundColor Red
    Start-Sleep -Seconds 3
    Exit
}

# ==========================================
# 1. DIRECT FLIPPER INSTALL (NO MENU)
# ==========================================
if ($env:FLIPPER_TARGET) {
    Write-Host "`n[*] Direct Install Triggered for: $env:FLIPPER_TARGET" -ForegroundColor Cyan
    $targetTool = $tools | Where-Object { $_.id -eq $env:FLIPPER_TARGET }
    if ($targetTool) {
        $tempFile = "$env:TEMP\$($targetTool.id).exe"
        Write-Host "[*] Downloading $($targetTool.name)..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $targetTool.url -OutFile $tempFile -UseBasicParsing
        Write-Host "[*] Installing $($targetTool.name)..." -ForegroundColor Cyan
        Start-Process -FilePath $tempFile -ArgumentList $targetTool.args -Wait
        Remove-Item $tempFile -Force
        Write-Host "[+] Successfully installed $($targetTool.name)!" -ForegroundColor Green
    } else {
        Write-Host "[!] Driver ID '$env:FLIPPER_TARGET' not found." -ForegroundColor Red
    }
    Exit
}

$groupedTools = $tools | Group-Object category
$state = "MAIN"
$selectedGroup = $null

# ==========================================
# 2. DUAL-TERMINAL ENGINE LOOP
# ==========================================
while ($true) {
    if (Test-Path $choiceFile) { Remove-Item $choiceFile -Force }

    # Dynamically build the true CMD Batch file for the menu window
    $batContent = New-Object System.Collections.Generic.List[String]
    $batContent.Add("@echo off")
    $batContent.Add("mode con cols=80 lines=25")
    $batContent.Add("title Administrator: Flipper Deployment Center")
    $batContent.Add("color 07")
    $batContent.Add("cls")
    $batContent.Add("echo.")
    $batContent.Add("echo       ----------------------------------------------------------------")
    $batContent.Add("echo.")

    if ($state -eq "MAIN") {
        $batContent.Add("echo               Driver Categories:")
        $batContent.Add("echo.")
        $i = 1
        $catMap = @{}
        foreach ($group in $groupedTools) {
            $batContent.Add("echo               [$i] $($group.Name)")
            $catMap[$i.ToString()] = $group
            $i++
        }
        $batContent.Add("echo.")
        $batContent.Add("echo       ----------------------------------------------------------------")
        $batContent.Add("echo.")
        $batContent.Add("echo               [Q] Quit")
        $batContent.Add("echo.")
        $batContent.Add("echo       ----------------------------------------------------------------")
        $batContent.Add("echo.")
        $batContent.Add('set /p choice="       Choose a menu option using your keyboard [1..' + ($i-1) + ', Q] : "')
        $batContent.Add('echo %choice% > "' + $choiceFile + '"')
    } 
    elseif ($state -eq "SUB") {
        $batContent.Add("echo               $($selectedGroup.Name.ToUpper()):")
        $batContent.Add("echo.")
        $i = 1
        foreach ($tool in $selectedGroup.Group) {
            $batContent.Add("echo               [$i] $($tool.name)")
            $i++
        }
        $batContent.Add("echo.")
        $batContent.Add("echo       ----------------------------------------------------------------")
        $batContent.Add("echo.")
        $batContent.Add("echo               [B] Go Back")
        $batContent.Add("echo.")
        $batContent.Add("echo       ----------------------------------------------------------------")
        $batContent.Add("echo.")
        $batContent.Add('set /p choice="       Select drivers (e.g. 1 or 1,3) or B : "')
        $batContent.Add('echo %choice% > "' + $choiceFile + '"')
    }

    Set-Content -Path $batPath -Value ($batContent -join "`r`n") -Encoding Ascii

    # Clear PowerShell window and prepare it to catch downloads
    Clear-Host
    Write-Host "`n==================================================================" -ForegroundColor DarkGray
    Write-Host " WORKER TERMINAL (PowerShell) - Download & Install logs show here" -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor DarkGray
    Write-Host "[*] Interactive menu launched in a separate CMD window..." -ForegroundColor Cyan

    # Launch Terminal 2 (CMD) and pause PowerShell until a choice is made
    Start-Process cmd.exe -ArgumentList "/c `"$batPath`"" -WindowStyle Normal -Wait

    # If the user closed the CMD window without picking anything, exit script
    if (-not (Test-Path $choiceFile)) {
        Write-Host "`n[*] Menu closed. Exiting..." -ForegroundColor DarkGray
        Exit
    }

    $result = (Get-Content $choiceFile).Trim().ToUpper()

    if ($state -eq "MAIN") {
        if ($result -eq 'Q') {
            Write-Host "`n[*] Exiting..." -ForegroundColor Cyan
            Exit
        }
        
        $i = 1
        $catMap = @{}
        foreach ($group in $groupedTools) {
            $catMap[$i.ToString()] = $group
            $i++
        }

        if ($catMap.ContainsKey($result)) {
            $selectedGroup = $catMap[$result]
            $state = "SUB"
        }
    } 
    elseif ($state -eq "SUB") {
        if ($result -eq 'B') {
            $state = "MAIN"
        } else {
            $i = 1
            $toolMap = @{}
            foreach ($tool in $selectedGroup.Group) {
                $toolMap[$i.ToString()] = $tool
                $i++
            }

            $selections = $result -split ',' | ForEach-Object { $_.Trim() }
            $executedAny = $false

            foreach ($sel in $selections) {
                if ($toolMap.ContainsKey($sel)) {
                    $tool = $toolMap[$sel]
                    Write-Host "`n------------------------------------------------------------------" -ForegroundColor DarkGray
                    Write-Host "[*] Downloading: $($tool.name)..." -ForegroundColor Yellow
                    $tempFile = "$env:TEMP\$($tool.id).exe"
                    
                    try {
                        Invoke-WebRequest -Uri $tool.url -OutFile $tempFile -UseBasicParsing
                        Write-Host "[*] Installing: $($tool.name)..." -ForegroundColor Cyan
                        Start-Process -FilePath $tempFile -ArgumentList $tool.args -Wait
                        Remove-Item $tempFile -Force
                        Write-Host "[+] Successfully installed $($tool.name)!" -ForegroundColor Green
                        $executedAny = $true
                    } catch {
                        Write-Host "[!] Error installing $($tool.name): $_" -ForegroundColor Red
                    }
                }
            }

            if ($executedAny) {
                Write-Host "`n[+] Tasks completed. Returning to menu..." -ForegroundColor Green
                Start-Sleep -Seconds 2
            }
        }
    }
}
