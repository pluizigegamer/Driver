#Requires -RunAsAdministrator
$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Fetch Manifest from GitHub Pages
$manifestUrl = "https://pluizigegamer.github.io/Driver/manifest.json"
try {
    $tools = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing
} catch {
    Write-Host "[!] Failed to fetch configuration manifest from GitHub." -ForegroundColor Red
    Pause
    Exit
}

function Show-Menu {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "       FLIPPER ZERO REMOTE DEPLOYMENT TERMINAL v1.0             " -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host " Select software to deploy remotely via GitHub Pages:`n" -ForegroundColor White

    foreach ($tool in $tools) {
        Write-Host "  [$($tool.id)] " -ForegroundColor Green -NoNewline
        Write-Host "$($tool.name)" -ForegroundColor White
    }
    
    Write-Host "  [A] " -ForegroundColor Cyan -NoNewline
    Write-Host "Install ALL Listed Tools" -ForegroundColor White
    Write-Host "  [Q] " -ForegroundColor Red -NoNewline
    Write-Host "Exit Terminal`n" -ForegroundColor White
    Write-Host "================================================================" -ForegroundColor Cyan
}

function Install-Tool {
    param($tool)
    Write-Host "`n[*] Downloading: $($tool.name)..." -ForegroundColor Yellow
    $tempFile = "$env:TEMP\$($tool.name -replace '[^\w]', '_').exe"
    
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

do {
    Show-Menu
    $choice = Read-Host "Select an option"

    switch ($choice.ToUpper()) {
        'A' {
            foreach ($tool in $tools) {
                Install-Tool -tool $tool
            }
            Write-Host "`n[+] Batch installation complete!" -ForegroundColor Green
            Start-Sleep -Seconds 2
        }
        'Q' {
            Write-Host "`n[*] Exiting terminal..." -ForegroundColor Cyan
            Exit
        }
        default {
            $selectedTool = $tools | Where-Object { $_.id -eq $choice }
            if ($selectedTool) {
                Install-Tool -tool $selectedTool
                Write-Host "`n[+] Press any key to return to menu..." -ForegroundColor DarkGray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            } else {
                Write-Host "`n[!] Invalid selection. Try again." -ForegroundColor Red
                Start-Sleep -Seconds 1.5
            }
        }
    }
} while ($true)
