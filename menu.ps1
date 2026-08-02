#Requires -RunAsAdministrator
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$host.UI.RawUI.WindowTitle = "Flipper Deployment Center"

$manifestUrl = "https://pluizigegamer.github.io/Driver/manifest.json"

# ==========================================
# INSTALLATION ENGINE
# ==========================================
function Install-Tool {
    param($tool)
    $tempFile = "$env:TEMP\$($tool.id).exe"
    
    try {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }

        Write-Host "`n       [*] Downloading: $($tool.name)..." -ForegroundColor Yellow
        
        # WebClient with User-Agent header to bypass 403 Forbidden errors
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        $webClient.DownloadFile($tool.url, $tempFile)
        
        # Verify file download (catch HTML 403 error pages)
        $fileInfo = Get-Item $tempFile
        if ($fileInfo.Length -lt 100000) {
            throw "Downloaded file is too small ($($fileInfo.Length) bytes). URL may be invalid, blocked, or returning an error page."
        }

        Write-Host "       [*] Installing: $($tool.name)..." -ForegroundColor Cyan
        
        # Support both silent args and GUI installers (empty args)
        if ([string]::IsNullOrWhiteSpace($tool.args)) {
            Start-Process -FilePath $tempFile -Wait
        } else {
            Start-Process -FilePath $tempFile -ArgumentList $tool.args -Wait
        }
        
        Remove-Item $tempFile -Force
        Write-Host "       [+] Successfully finished: $($tool.name)!" -ForegroundColor Green
    } catch {
        Write-Host "       [!] Error installing $($tool.name): $_" -ForegroundColor Red
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    }
}

# Fetch Manifest from GitHub Pages
try {
    $tools = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing
} catch {
    Write-Host "`n [!] Failed to fetch configuration manifest from GitHub." -ForegroundColor Red
    Start-Sleep -Seconds 3
    Exit
}

# ==========================================
# 1. DIRECT FLIPPER INSTALL MODE (NO MENU)
# ==========================================
if ($env:FLIPPER_TARGET) {
    Clear-Host
    Write-Host "`n [*] Direct Install Triggered for ID: $env:FLIPPER_TARGET" -ForegroundColor Cyan
    $targetTool = $tools | Where-Object { $_.id -eq $env:FLIPPER_TARGET }
    
    if ($targetTool) {
        Install-Tool -tool $targetTool
    } else {
        Write-Host " [!] Driver ID '$env:FLIPPER_TARGET' not found in manifest." -ForegroundColor Red
    }
    Exit
}

# ==========================================
# 2. INTERACTIVE SHOPPING BASKET UI MODE
# ==========================================
$groupedTools = $tools | Group-Object category
$state = "MAIN"
$selectedGroup = $null
$basket = [System.Collections.Generic.List[PSCustomObject]]::new()

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
                Write-Host "       ----------------------------------------------------------------" -ForegroundColor DarkGray

                foreach ($tool in $basket) {
                    Install-Tool -tool $tool
                }

                Write-Host ""
                Write-Host "       [+] All basket items processed! Clearing basket." -ForegroundColor Green
                $basket.Clear()
                Write-Host "       Press Enter to return to main menu..." -ForegroundColor Gray
                $null = Read-Host
                $state = "MAIN"
            }
        }
    }
}
