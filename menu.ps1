#Requires -RunAsAdministrator
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$host.UI.RawUI.WindowTitle = "Flipper Deployment Center"

$manifestUrl = "https://pluizigegamer.github.io/Driver/manifest.json"

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
        Write-Host "[*] Downloading $($targetTool.name)... (Large files may take a moment)" -ForegroundColor Yellow
        
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($targetTool.url, $tempFile)
        
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
# 2. UNIFIED SINGLE-WINDOW WEB-SHOP MENU
# ==========================================
while ($true) {
    Clear-Host
    Write-Host ""
    Write-Host "       ----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host ""

    if ($state -eq "MAIN") {
        Write-Host "               Driver Categories:" -ForegroundColor White
        Write-Host ""
        $i = 1
        $catMap = @{}
        foreach ($group in $groupedTools) {
            Write-Host "               [" -NoNewline; Write-Host "$i" -NoNewline -ForegroundColor Green; Write-Host "] $($group.Name)" -ForegroundColor White
            $catMap[$i.ToString()] = $group
            $i++
        }
        Write-Host ""
        Write-Host "       ----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host "               Basket: $($basket.Count) item(s) selected" -ForegroundColor Yellow
        Write-Host "       ----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host "               [C] Checkout / View Basket" -ForegroundColor White
        Write-Host "               [Q] Quit" -ForegroundColor Red
        Write-Host ""
        Write-Host "       ----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host ""
        
        $choice = Read-Host "       Choose option [1..$($i-1), C, Q]"
        $choice = $choice.Trim().ToUpper()

        if ($choice -eq 'Q') { Exit }
        elseif ($choice -eq 'C') { $state = "CART" }
        elseif ($catMap.ContainsKey($choice)) {
            $selectedGroup = $catMap[$choice]
            $state = "SUB"
        }
    }
    elseif ($state -eq "SUB") {
        Write-Host "               Category: $($selectedGroup.Name.ToUpper())" -ForegroundColor White
        Write-Host ""
        $i = 1
        $toolMap = @{}
        foreach ($tool in $selectedGroup.Group) {
            $inBasket = $basket | Where-Object { $_.id -eq $tool.id }
            $tag = if ($inBasket) { " [IN BASKET]" } else { "" }
            Write-Host "               [" -NoNewline; Write-Host "$i" -NoNewline -ForegroundColor Green; Write-Host "] $($tool.name)$tag" -ForegroundColor White
            $toolMap[$i.ToString()] = $tool
            $i++
        }
        Write-Host ""
        Write-Host "       ----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host "               [B] Back to Categories" -ForegroundColor Yellow
        Write-Host "       ----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host ""
        
        $choice = Read-Host "       Add to basket (e.g. 1 or 1,2) or B"
        $choice = $choice.Trim().ToUpper()

        if ($choice -eq 'B') {
            $state = "MAIN"
        } else {
            $selections = $choice -split ',' | ForEach-Object { $_.Trim() }
            foreach ($sel in $selections) {
                if ($toolMap.ContainsKey($sel)) {
                    $tool = $toolMap[$sel]
                    if (-not ($basket | Where-Object { $_.id -eq $tool.id })) {
                        $basket.Add($tool)
                        Write-Host "       [+] Added to basket: $($tool.name)" -ForegroundColor Green
                    } else {
                        Write-Host "       [*] Already in basket: $($tool.name)" -ForegroundColor DarkYellow
                    }
                }
            }
            Start-Sleep -Seconds 1
        }
    }
    elseif ($state -eq "CART") {
        Write-Host "               Shopping Basket Checkout:" -ForegroundColor White
        Write-Host ""
        if ($basket.Count -eq 0) {
            Write-Host "               Your basket is empty!" -ForegroundColor Yellow
        } else {
            $ci = 1
            foreach ($item in $basket) {
                Write-Host "               [$ci] $($item.name)" -ForegroundColor White
                $ci++
            }
        }
        Write-Host ""
        Write-Host "       ----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host "               [I] Install All Basket Items Now" -ForegroundColor Green
        Write-Host "               [CLEAR] Clear Basket" -ForegroundColor Red
        Write-Host "               [B] Back to Categories" -ForegroundColor Yellow
        Write-Host "       ----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host ""
        
        $choice = Read-Host "       Select action [I, CLEAR, B]"
        $choice = $choice.Trim().ToUpper()

        if ($choice -eq 'B') {
            $state = "MAIN"
        }
        elseif ($choice -eq 'CLEAR') {
            $basket.Clear()
            Write-Host "       [-] Basket cleared." -ForegroundColor Red
            Start-Sleep -Seconds 1
            $state = "MAIN"
        }
        elseif ($choice -eq 'I') {
            if ($basket.Count -gt 0) {
                Write-Host ""
                Write-Host "       ----------------------------------------------------------------" -ForegroundColor DarkGray
                Write-Host "       [!] Starting batch download and installation..." -ForegroundColor Cyan
                Write-Host "       [!] Large downloads may take time. Please wait..." -ForegroundColor Yellow
                Write-Host "       ----------------------------------------------------------------" -ForegroundColor DarkGray

                foreach ($tool in $basket) {
                    Write-Host "`n       [*] Downloading: $($tool.name)..." -ForegroundColor Yellow
                    $tempFile = "$env:TEMP\$($tool.id).exe"
                    
                    try {
                        $webClient = New-Object System.Net.WebClient
                        $webClient.DownloadFile($tool.url, $tempFile)
                        
                        Write-Host "       [*] Installing: $($tool.name)..." -ForegroundColor Cyan
                        Start-Process -FilePath $tempFile -ArgumentList $tool.args -Wait
                        Remove-Item $tempFile -Force
                        Write-Host "       [+] Successfully installed $($tool.name)!" -ForegroundColor Green
                    } catch {
                        Write-Host "       [!] Error installing $($tool.name): $_" -ForegroundColor Red
                    }
                }

                Write-Host ""
                Write-Host "       [+] All basket items processed! Clearing cart." -ForegroundColor Green
                $basket.Clear()
                Write-Host "       Press Enter to return to the menu..." -ForegroundColor Gray
                $null = Read-Host
                $state = "MAIN"
            }
        }
    }
}
