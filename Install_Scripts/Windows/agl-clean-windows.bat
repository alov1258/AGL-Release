@echo off
rem =====================================================================
rem  AGL clean-up - Windows
rem
rem  This .bat is a thin launcher. It starts PowerShell and hands it the
rem  PowerShell code stored further down this same file (everything after
rem  the PSBEGIN marker line). That way:
rem    - you can still just double-click it (no .ps1 execution-policy setup)
rem    - all the real work runs in PowerShell (progress bar, folder chooser)
rem    - there is still only ONE file to distribute
rem
rem  The (rarely needed) settings are at the top of the PowerShell part.
rem =====================================================================
setlocal
powershell -NoProfile -STA -Command "$t = Get-Content -LiteralPath '%~f0' -Raw; $t = $t -replace '(?s)\A.*?\r?\n#PSBEGIN\r?\n', ''; & ([scriptblock]::Create($t))"
exit /b %ERRORLEVEL%
#PSBEGIN
# =====================================================================
#  AGL clean-up (Windows) - PowerShell part.
#  Everything below the marker line above is run by PowerShell.
#  cmd.exe never reads past the "exit /b" line at the top of this file.
# =====================================================================
$ErrorActionPreference = 'Stop'

# ======================= SETTINGS =======================
# Generation          the generation to clean. '' = the one AGL_GEN is set to right now.
#                     ONLY this generation is cleaned: other generations' variables,
#                     preferences, icons and installs are left alone.
# FallbackGeneration  used when Generation is '' and AGL_GEN is not set (any more)
# DownloadNames       files the installers save in your Downloads folder
#                     (map zips, maps_*.zip, are always included)
$Generation         = ''
$FallbackGeneration = '25'
$DownloadNames      = @('AGL_latest_full.zip', 'AGL_latest_patch.zip', 'APL_patch.zip')
# ========================================================

# ---------------------------------------------------------------- the machine (wrapped so it can be tested)

function Pause-Exit([int]$Code) {
    Write-Host ''
    [void](Read-Host 'Press Enter to close')
    exit $Code
}
function Read-Text([string]$Prompt) { return (Read-Host $Prompt) }

# All USER environment variables (the ones setx writes) as a name -> value table.
function Get-UserEnvTable {
    $table = @{}
    $vars = [Environment]::GetEnvironmentVariables('User')
    foreach ($k in $vars.Keys) { $table[[string]$k] = [string]$vars[$k] }
    return $table
}
function Remove-UserEnvVar([string]$Name) { [Environment]::SetEnvironmentVariable($Name, $null, 'User') }
function Get-ProfileFolder { return $env:USERPROFILE }
function Get-DesktopFolder { return [Environment]::GetFolderPath('Desktop') }
function Get-DocumentsFolder { return [Environment]::GetFolderPath('MyDocuments') }
function Get-DownloadsFolder {
    try {
        $p = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
        if ($p) { return $p }
    } catch { }
    return (Join-Path $env:USERPROFILE 'Downloads')
}
function Get-TempFolder { return [System.IO.Path]::GetTempPath() }

# The "Start in" folder of an existing shortcut, or $null if it cannot be read -
# same lookup the installer uses to find an install with no environment variable.
function Get-ShortcutWorkDir([string]$LinkPath) {
    try { return (New-Object -ComObject WScript.Shell).CreateShortcut($LinkPath).WorkingDirectory }
    catch { return $null }
}

# Processes whose program file lives inside Dir (e.g. AGL's bundled java.exe)
function Get-RunningFrom([string]$Dir) {
    $prefix = $Dir.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -and $_.Path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) } catch { $false }
    })
}

# rd /s /q is far quicker than Remove-Item for a folder holding tens of thousands of map tiles
function Remove-Folder([string]$Path) {
    $cmd = $null
    if ($env:SystemRoot) { $cmd = Join-Path $env:SystemRoot 'System32\cmd.exe' }
    if ($cmd -and (Test-Path -LiteralPath $cmd)) { & $cmd /c rd /s /q $Path 2>&1 | Out-Null }
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------- what counts

# The generation to clean: the setting, else what the AGL_GEN user variable says now, else the fallback.
function Get-TargetGeneration {
    if ($Generation) { return @{ Gen = $Generation; Why = 'set in this script' } }
    $table = Get-UserEnvTable
    if ($table.ContainsKey('AGL_GEN') -and ($table['AGL_GEN'] -match '^\s*(\d+)\s*$')) { return @{ Gen = $Matches[1]; Why = 'from AGL_GEN' } }
    return @{ Gen = $FallbackGeneration; Why = 'AGL_GEN is not set - using the default' }
}

# $TargetGen is set in Invoke-Cleaner
function Test-GenWanted([string]$Gen) { return ($Gen -eq $TargetGen) }

# Why this folder must NOT be deleted ($null when it is safe to delete)
function Get-InstallProblem([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return 'not a folder (already gone?)' }
    $sep = [System.IO.Path]::DirectorySeparatorChar
    $fullRaw = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetPathRoot($fullRaw)
    $full = $fullRaw.TrimEnd('\', '/')
    if ($full.Length -le $root.TrimEnd('\', '/').Length) { return 'that is a drive root' }
    $below = @($fullRaw.Substring($root.Length) -split '[\\/]' | Where-Object { $_ })
    if ($below.Count -lt 2) { return 'too close to the top of the drive (an install sits inside a parent folder, e.g. D:\SOL\Java25)' }
    $profileDir = (Get-ProfileFolder).TrimEnd('\', '/')
    if (($profileDir -ieq $full) -or $profileDir.StartsWith($full + $sep, [System.StringComparison]::OrdinalIgnoreCase)) {
        return 'it is, or contains, your user profile'
    }
    foreach ($p in @((Get-DesktopFolder), (Get-DocumentsFolder), (Get-DownloadsFolder))) {
        if ($p -and ($p.TrimEnd('\', '/') -ieq $full)) { return 'that is one of your personal folders' }
    }
    $marker = (Test-Path -LiteralPath (Join-Path $full 'agl_launcher.jar')) -or
              (Test-Path -LiteralPath (Join-Path $full 'installWIN.bat')) -or
              (@(Get-ChildItem -LiteralPath $full -Directory -Filter 'agl*_lib' -ErrorAction SilentlyContinue).Count -gt 0)
    if (-not $marker) { return 'it does not look like an AGL install (no agl_launcher.jar, installWIN.bat or agl*_lib)' }
    if (@(Get-RunningFrom $full).Count -gt 0) { return 'AGL seems to be running from it - close it first' }
    return $null
}

# The launcher's preferences file is a Java properties file: \: and \\ are escapes.
function Get-PrefRaceDirs([string]$PrefFile) {
    $found = @()
    foreach ($line in @(Get-Content -LiteralPath $PrefFile -ErrorAction SilentlyContinue)) {
        if ($line -match '^AGL\d+_Race_Dir=(.*)$') { $found += [regex]::Replace($Matches[1], '\\(.)', '$1') }
    }
    return $found
}

# ---------------------------------------------------------------- scan

function Get-CleanPlan([string]$ExtraInstall) {
    $plan = @{ Vars = @(); Prefs = @(); Icons = @(); Downloads = @(); Temps = @(); Installs = @(); Refused = @(); Races = @() }
    $table = Get-UserEnvTable
    $installs = @()
    foreach ($name in @($table.Keys | Sort-Object)) {
        $wanted = $false
        if ($name -ieq 'AGL_GEN' -or $name -ieq 'AGL_PREV_GEN') { $wanted = $true }
        elseif ($name -match '^AG(\d+)[A-Za-z]+$') { $wanted = Test-GenWanted $Matches[1] }
        elseif ($name -match '^AGL(\d+)_Race_Dir$') { $wanted = Test-GenWanted $Matches[1] }
        if ($wanted) { $plan.Vars += [pscustomobject]@{ Name = $name; Value = $table[$name] } }
        if ($wanted -and $name -match '^AG\d+InstallDir$' -and $table[$name]) { $installs += $table[$name] }
        if ($wanted -and $name -match '^AGL\d+_Race_Dir$' -and $table[$name]) { $plan.Races += $table[$name] }
    }
    if ($ExtraInstall) { $installs += $ExtraInstall }

    $profileDir = Get-ProfileFolder
    foreach ($f in @(Get-ChildItem -LiteralPath $profileDir -Filter '.agl*_launcher.properties' -Force -File -ErrorAction SilentlyContinue)) {
        if ($f.Name -match '^\.agl(\d+)_launcher\.properties$' -and (Test-GenWanted $Matches[1])) {
            $plan.Prefs += $f.FullName
            $plan.Races += @(Get-PrefRaceDirs $f.FullName)
        }
    }
    foreach ($f in @(Get-ChildItem -LiteralPath (Get-DesktopFolder) -Force -File -ErrorAction SilentlyContinue)) {
        if ($f.Name -match '^(AGL|APL)(\d+)\.lnk$' -and (Test-GenWanted $Matches[2])) {
            $plan.Icons += $f.FullName
            # No environment variable points at the install any more - the new installer and
            # AGL_shortcut.bat both find it through this same shortcut, so this is how the
            # cleaner finds it too.
            $dir = Get-ShortcutWorkDir $f.FullName
            if ($dir) { $installs += $dir }
        }
    }
    $dl = Get-DownloadsFolder
    foreach ($f in @(Get-ChildItem -LiteralPath $dl -Force -File -ErrorAction SilentlyContinue)) {
        $base = $f.Name -replace '\.part$', ''
        if (($DownloadNames -contains $base) -or ($base -like 'maps_*.zip')) { $plan.Downloads += $f.FullName }
    }
    foreach ($d in @(Get-ChildItem -LiteralPath (Get-TempFolder) -Directory -Filter 'agl_patch_*' -Force -ErrorAction SilentlyContinue)) {
        $plan.Temps += $d.FullName
    }
    foreach ($d in @($installs | Where-Object { $_ } | Sort-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $d -PathType Container)) { continue }
        $why = Get-InstallProblem $d
        if ($why) { $plan.Refused += [pscustomobject]@{ Path = $d; Why = $why } } else { $plan.Installs += $d }
    }
    $plan.Races = @($plan.Races | Where-Object { $_ } | Sort-Object -Unique)
    return $plan
}

function Get-PlanCount($Plan) {
    return (@($Plan.Vars).Count + @($Plan.Prefs).Count + @($Plan.Icons).Count + @($Plan.Downloads).Count + @($Plan.Temps).Count + @($Plan.Installs).Count)
}

function Show-Plan($Plan) {
    Write-Host ''
    Write-Host 'What will be removed' -ForegroundColor Cyan
    foreach ($v in $Plan.Vars)      { Write-Host ("  user variable       : {0} = {1}" -f $v.Name, $v.Value) }
    foreach ($f in $Plan.Prefs)     { Write-Host "  launcher preferences: $f" }
    foreach ($f in $Plan.Icons)     { Write-Host "  Desktop icon        : $f" }
    foreach ($f in $Plan.Downloads) { Write-Host "  saved download      : $f" }
    foreach ($f in $Plan.Temps)     { Write-Host "  temporary folder    : $f" }
    foreach ($d in $Plan.Installs)  { Write-Host "  INSTALL FOLDER      : $d   (everything inside, including maps)" }
    if (@($Plan.Refused).Count -gt 0) {
        Write-Host ''
        foreach ($r in $Plan.Refused) { Write-Host "  NOT removing folder : $($r.Path)  - $($r.Why)" -ForegroundColor Yellow }
    }
    if (@($Plan.Races).Count -gt 0) {
        Write-Host ''
        foreach ($r in $Plan.Races) { Write-Host "  NOT touched - your races folder: $r" -ForegroundColor Green }
    }
}

# ---------------------------------------------------------------- main

function Invoke-Cleaner {
    try {
        Write-Host ''
        Write-Host 'AGL clean-up (Windows)' -ForegroundColor Cyan
        Write-Host 'Puts this account back to "AGL was never installed". Your races folder is never touched.'
        $target = Get-TargetGeneration
        $TargetGen = $target.Gen
        Write-Host "Scope: generation $TargetGen only ($($target.Why)). Other generations are left alone."
        if ($TargetGen -ne $FallbackGeneration) {
            Write-Host "Note: this is not the usual generation ($FallbackGeneration). Set Generation at the top of this script to override." -ForegroundColor Yellow
        }

        $plan = Get-CleanPlan ''
        Show-Plan $plan

        Write-Host ''
        $extra = Read-Text 'Another AGL install folder to remove (full path), or press Enter for none'
        if ($extra) {
            $extra = $extra.Trim().Trim('"')
            if (-not (Test-Path -LiteralPath $extra -PathType Container)) {
                Write-Host "Not found, ignored: $extra" -ForegroundColor Yellow
                $extra = ''
            } else {
                $plan = Get-CleanPlan $extra
                Show-Plan $plan
            }
        }

        if ((Get-PlanCount $plan) -eq 0) {
            Write-Host ''
            if (@($plan.Refused).Count -gt 0) {
                Write-Host 'Nothing could be removed - see the folders above.' -ForegroundColor Yellow
            } else {
                Write-Host 'Nothing to remove - this account already looks like a fresh one.' -ForegroundColor Green
            }
            Pause-Exit 0
        }
        $refused = @($plan.Refused)

        Write-Host ''
        $answer = Read-Text 'Type YES to remove everything listed above'
        if ($answer -ne 'YES') {
            Write-Host ''
            Write-Host 'Nothing was changed.'
            Pause-Exit 0
        }

        Write-Host ''
        $failed = 0
        foreach ($v in $plan.Vars) {
            try { Remove-UserEnvVar $v.Name; Write-Host "removed variable $($v.Name)" }
            catch { Write-Host "could not remove variable $($v.Name): $($_.Exception.Message)" -ForegroundColor Red; $failed++ }
        }
        foreach ($f in @($plan.Prefs) + @($plan.Icons) + @($plan.Downloads)) {
            try { Remove-Item -LiteralPath $f -Force; Write-Host "removed $f" }
            catch { Write-Host "could not remove ${f}: $($_.Exception.Message)" -ForegroundColor Red; $failed++ }
        }
        foreach ($d in @($plan.Temps)) { Remove-Folder $d }
        foreach ($d in @($plan.Installs)) {
            Write-Host "removing $d (this can take a while - it holds many map tiles) ..."
            Remove-Folder $d
            if (Test-Path -LiteralPath $d) { Write-Host "could not remove all of $d (is something using it?)" -ForegroundColor Red; $failed++ }
            else { Write-Host "removed $d" }
        }

        # verify
        $after = Get-CleanPlan $extra
        $left = Get-PlanCount $after
        Write-Host ''
        if ($left -eq 0 -and $failed -eq 0) {
            if ($refused.Count -eq 0) { Write-Host 'Clean. Nothing AGL-related is left in this account.' -ForegroundColor Green }
            else { Write-Host 'Clean, except for the folders left in place on purpose:' -ForegroundColor Yellow }
        } else {
            Write-Host "Finished with $failed problem(s); $left item(s) still listed:" -ForegroundColor Yellow
            Show-Plan $after
        }
        foreach ($r in $refused) { Write-Host "  left in place: $($r.Path)  - $($r.Why)" -ForegroundColor Yellow }
        Write-Host ''
        Write-Host 'To finish: close and reopen any Command Prompt or PowerShell windows (they keep the old variables),'
        Write-Host 'then run agl-install-windows.bat for the clean install.'
        Pause-Exit 0
    }
    catch {
        Write-Host ''
        Write-Host "*** $($_.Exception.Message)" -ForegroundColor Red
        Pause-Exit 1
    }
}

Invoke-Cleaner
