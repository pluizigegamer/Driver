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
$basket = [System.Collections.Generic.List[PSCustomObject]]::new()

# ==========================================
# 2. DUAL-TERMINAL BASKET ENGINE LOOP
# ==========================================
while ($true) {
    if (Test-Path $choiceFile) { Remove-Item $choiceFile -Force }

    $batContent = New-Object System.Collections.Generic.List[String]
    $batContent.Add("@echo off")
    $batContent.Add("mode con cols=80 lines=29")
    $batContent.Add("title Administrator: Flipper Deployment Center [Basket Items: $($basket.Count)]")
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
        $batContent.Add("echo               Basket: $($basket.Count) driver(s) selected")
        $batContent.Add("echo       ----------------------------------------------------------------")
        $batContent.Add("echo               [C] Checkout / View Basket")
        $batContent.Add("echo               [Q] Quit")
        $batContent.Add("echo.")
        $batContent.Add("echo       ----------------------------------------------------------------")
        $batContent.Add("echo.")
        $batContent.Add('set /p choice="       Choose option [1..' + ($i-1) + ', C, Q] : "')
        $batContent.Add('echo %choice% > "' + $choiceFile + '"')
    } 
    elseif ($state -eq "SUB") {
        $batContent.Add("echo               Category: $($selectedGroup.Name.ToUpper())")
        $batContent.Add("echo.")
        $i = 1
        foreach ($tool in $selectedGroup.Group) {
            $inBasket = $basket | Where-Object { $_.id -eq $tool.id }
            $tag = if ($inBasket) { " [IN BASKET]" } else { "" }
            $batContent.Add("echo               [$i] $($tool.name)$tag")
            $i++
        }
        $batContent.Add("echo.")
        $batContent.Add("echo       ----------------------------------------------------------------")
        $batContent.Add("echo               [B] Back to Categories")
        $batContent.Add("echo.")
        $batContent.Add("echo       ----------------------------------------------------------------")
        $batContent.Add("echo.")
        $batContent.Add('set /p choice="       Add to basket (e.g. 1 or 1,2) or B : "')
        $batContent.Add('echo %choice% > "' + $choiceFile + '"')
    }
    elseif ($state -eq "CART") {
        $batContent.Add("echo               Shopping Basket Checkout:")
        $batContent.Add("echo.")
        if ($basket.Count -eq 0) {
            $batContent.Add("echo               Your basket is currently empty!")
        } else {
            $ci = 1
            foreach ($item in $basket) {
                $batContent.Add("echo               [$ci] $($item.name)")
                $ci++
            }
        }
        $batContent.Add("echo.")
        $batContent.Add("echo       ----------------------------------------------------------------")
        $batContent.Add("echo               [I] Install All Basket Items Now")
        $batContent.Add("echo               [CLEAR] Clear Basket")
        $batContent.Add("echo               [B] Back to Categories")
        $batContent.Add("echo.")
        $batContent.Add("echo       ----------------------------------------------------------------")
        $batContent.Add("echo.")
        $batContent.Add('set /p choice="       Select action [I, CLEAR, B] : "')
        $batContent.Add('echo %choice% > "' + $choiceFile + '"')
    }

    Set-Content -Path $batPath -Value ($batContent -join "`r`n") -Encoding Ascii

    # Clear PowerShell window and prepare it to catch actions
    Clear-Host
    Write-Host "`n==================================================================" -ForegroundColor DarkGray
    Write-Host " WORKER TERMINAL (PowerShell) - Download & Install logs show here" -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor DarkGray
    Write-Host "[*] Active Basket Items: $($basket.Count)" -ForegroundColor Cyan
    Write-Host "[*] Menu running in separate CMD window..." -ForegroundColor DarkGray

    Start-Process cmd.exe -ArgumentList "/c `"$batPath`"" -WindowStyle Normal -Wait

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
        elseif ($result -eq 'C') {
            $state = "CART"
        }
        else {
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
    } 
    elseif ($state -eq "SUB") {
        if ($result -eq 'B') {
            $state = "MAIN"
        } else {
            $toolMap = @{}
            $i = 1
            foreach ($tool in $selectedGroup.Group) {
                $toolMap[$i.ToString()] = $tool
                $i++
            }

            $selections = $result -split ',' | ForEach-Object { $_.Trim() }
            foreach ($sel in $selections) {
                if ($toolMap.ContainsKey($sel)) {
                    $tool = $toolMap[$sel]
                    if (-not ($basket | Where-Object { $_.id -eq $tool.id })) {
                        $basket.Add($tool)
                        Write-Host "[+] Added to basket: $($tool.name)" -ForegroundColor Green
                    } else {
                        Write-Host "[*] Already in basket: $($tool.name)" -ForegroundColor DarkYellow
                    }
                }
            }
        }
    }
    elseif ($state -eq "CART") {
        if ($result -eq 'B') {
            $state = "MAIN"
        }
        elseif ($result -eq 'CLEAR') {
            $basket.Clear()
            Write-Host "[-] Basket cleared." -ForegroundColor Red
            $state = "MAIN"
        }
        elseif ($result -eq 'I') {
            if ($basket.Count -gt 0) {
                Write-Host "`n------------------------------------------------------------------" -ForegroundColor DarkGray
                Write-Host "[*] Starting batch installation of $($basket.Count) items..." -ForegroundColor Yellow
                
                foreach ($tool in $basket) {
                    Write-Host "`n[*] Downloading: $($tool.name)..." -ForegroundColor Yellow
                    $tempFile = "$env:TEMP\$($tool.id).exe"
                    
                    try {
                        Invoke-WebRequest -Uri $tool.url -OutFile $tempFile -UseBasicParsing
                        Write-Host "[*] Installing: $($tool.name)..." -ForegroundColor Cyan
                        Start-Process -FilePath $tempFile -ArgumentList $tool.args -Wait
                        Remove-Item $tempFile -Force
                        Write-Host "[+] Successfully installed $($tool.name)!" -ForegroundColor Green
                    } catch {
                        Write-Host "[!] Error installing $($tool.name): $_" -ForegroundColor Red
                    }
                }

                Write-Host "`n[+] All basket items processed! Clearing cart..." -ForegroundColor Green
                $basket.Clear()
                Start-Sleep -Seconds 3
                $state = "MAIN"
            }
        }
    }
}
