#Requires -RunAsAdministrator
$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$manifestUrl = "https://pluizigegamer.github.io/Driver/manifest.json"
$choiceFile = "$env:TEMP\flipper_choice.txt"

# ==========================================
# 1. DIRECT FLIPPER INSTALL (NO MENU)
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
    Exit
}

# ==========================================
# 2. FETCH MANIFEST & SETUP
# ==========================================
try {
    $tools = Invoke-RestMethod -Uri $manifestUrl -UseBasicParsing
} catch {
    Write-Host "[!] Failed to fetch configuration manifest from GitHub." -ForegroundColor Red
    Start-Sleep -Seconds 3
    Exit
}

$groupedTools = $tools | Group-Object category
$state = "MAIN"
$selectedGroup = $null

# ==========================================
# 3. CMD BATCH UI GENERATOR
# ==========================================
while ($true) {
    if (Test-Path $choiceFile) { Remove-Item $choiceFile -Force }

    $batPath = "$env:TEMP\flipper_ui.cmd"
    $batContent = New-Object System.Collections.Generic.List[String]
    
    # Authentic CMD styling (matches the MAS screenshot)
    $batContent.Add("@echo off")
    $batContent.Add("mode con cols=85 lines=28")
    $batContent.Add("title Administrator: Flipper Deployment Center")
    $batContent.Add("color 07")
    $batContent.Add("cls")
    $batContent.Add("echo.")
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
        $batContent.Add('set /p choice="       Choose a menu option using your keyboard [1..$($i-1), Q] : "')
        $batContent.Add('echo %choice% > "' + $choiceFile + '"')
    }
    elseif ($state -eq "SUB") {
        $batContent.Add("echo               $($selectedGroup.Name.ToUpper()):")
        $batContent.Add("echo.")
        $i = 1
        $toolMap = @{}
        foreach ($tool in $selectedGroup.Group) {
            $batContent.Add("echo               [$i] $($tool.name)")
            $toolMap[$i.ToString()] = $tool
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

    # Save the batch file
    Set-Content -Path $batPath -Value ($batContent -join "`r`n") -Encoding Ascii

    # Clear the original PowerShell window and launch the CMD window
    Clear-Host
    Write-Host "`n[*] Waiting for selection in the Flipper Deployment Center window..." -ForegroundColor DarkGray
    
    Start-Process cmd.exe -ArgumentList "/c `"$batPath`"" -WindowStyle Normal -Wait

    # If the user clicked the 'X' to close the CMD window, exit script
    if (-not (Test-Path $choiceFile)) { Exit }
    
    $result = (Get-Content $choiceFile).Trim().ToUpper()
    
    # Process the results back in PowerShell
    if ($state -eq "MAIN") {
        if ($result -eq 'Q') { Exit }
        if ($catMap.ContainsKey($result)) {
            $selectedGroup = $catMap[$result]
            $state = "SUB"
        }
    }
    elseif ($state -eq "SUB") {
        if ($result -eq 'B') {
            $state = "MAIN"
        } else {
            Clear-Host
            $selections = $result -split ',' | ForEach-Object { $_.Trim() }
            $ranAny = $false
            
            foreach ($sel in $selections) {
                if ($toolMap.ContainsKey($sel)) {
                    $tool = $toolMap[$sel]
                    Write-Host "`n[*] Downloading: $($tool.name)..." -ForegroundColor Yellow
                    $tempFile = "$env:TEMP\$($tool.id).exe"
                    
                    try {
                        Invoke-WebRequest -Uri $tool.url -OutFile $tempFile -UseBasicParsing
                        Write-Host "[*] Installing: $($tool.name)..." -ForegroundColor Cyan
                        Start-Process -FilePath $tempFile -ArgumentList $tool.args -Wait
                        Remove-Item $tempFile -Force
                        Write-Host "[+] Successfully installed $($tool.name)!" -ForegroundColor Green
                        $ranAny = $true
                    } catch {
                        Write-Host "[!] Error installing $($tool.name): $_" -ForegroundColor Red
                    }
                }
            }
            if ($ranAny) {
                Write-Host "`n[*] Installations complete. Returning to menu..." -ForegroundColor DarkGray
                Start-Sleep -Seconds 3
            }
        }
    }
}
