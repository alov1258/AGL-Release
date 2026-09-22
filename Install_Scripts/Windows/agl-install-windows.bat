@echo off
rem =====================================================================
rem  AGL installer / updater - Windows
rem
rem  This .bat is a thin launcher. It starts PowerShell and hands it the
rem  PowerShell code stored further down this same file (everything after
rem  the PSBEGIN marker line). That way:
rem    - you can still just double-click it (no .ps1 execution-policy setup)
rem    - all the real work runs in PowerShell (progress bar, folder chooser)
rem    - there is still only ONE file to distribute
rem
rem  Settings to edit are at the top of the PowerShell part.
rem =====================================================================
setlocal
powershell -NoProfile -STA -Command "$t = Get-Content -LiteralPath '%~f0' -Raw; $t = $t -replace '(?s)\A.*?\r?\n#PSBEGIN\r?\n', ''; & ([scriptblock]::Create($t))"
exit /b %ERRORLEVEL%
#PSBEGIN
# =====================================================================
#  AGL installer / updater - PowerShell part.
#  Everything below the marker line above is run by PowerShell.
#  cmd.exe never reads past the "exit /b" line at the top of this file.
# =====================================================================
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Runs a native/API call without a normal use of stderr becoming a terminating
# error under $ErrorActionPreference = 'Stop' (see Invoke-Native's use below -
# this script has none today, but Get-GitHubJson shares the same concern for
# Invoke-RestMethod's own errors, handled there directly with try/catch).

# ======================= SETTINGS (edit only if the repo itself moves) =======================
# GitHubRepo     "owner/repo" of the public release repo. Everything else - which
#                app version is current, which runtime and map builds exist - is
#                found automatically from what is actually published there; this
#                file does not need editing for a normal app, runtime, or map release.
# VersionDirPrefix  the version folder is <prefix><AGL_GEN>, e.g. Java25
# ShortcutScript script in the version folder that creates the Desktop icon
# StartScript    script in the version folder read for its AGL_TILES line
# DefaultParent  folder the chooser opens on
$GitHubRepo       = 'alov1258/AGL-Release'
$VersionDirPrefix = 'Java'
$ShortcutScript   = 'AGL_shortcut.bat'
$StartScript      = 'AGL_start.bat'
$DefaultParent    = 'C:\SOL'

# Other-OS clean-up: names/wildcards matched against items directly inside the version
# folder; a match is removed with its contents. Nothing this installer downloads is ever
# an other-OS file - these only matter for tidying up a folder from an older, single-zip
# release that had every OS's files together. Keep in step with the Linux/macOS lists.
$CleanupWindows = @('*.sh', 'macOS_jre*', 'AGL_launcher.app', 'linux_jre2*', 'AGL.png', 'AGL.icns')
# ===============================================================================

$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
$ApiBase = "https://api.github.com/repos/$GitHubRepo"

# ---------------------------------------------------------------- shared helpers

function Pause-Exit([int]$Code) {
    Write-Host ''
    [void](Read-Host 'Press Enter to close')
    exit $Code
}

function Stop-WithError([string]$Message) {
    Write-Host ''
    Write-Host "*** $Message" -ForegroundColor Red
    Pause-Exit 1
}

# Returns the first letter, upper-cased, or $Default when Enter is pressed.
function Read-Choice([string]$Prompt, [string]$Default) {
    $answer = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer.Trim().Substring(0, 1).ToUpper()
}

function Select-ParentFolder([string]$StartPath) {
    Add-Type -AssemblyName System.Windows.Forms
    $owner = New-Object System.Windows.Forms.Form
    $owner.TopMost = $true
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose the PARENT folder for AGL (the release folder, e.g. Java25, is created inside it)'
    $dialog.SelectedPath = $StartPath
    $dialog.ShowNewFolderButton = $true
    try {
        if ($dialog.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) {
            return $dialog.SelectedPath
        }
    }
    finally {
        $dialog.Dispose()
        $owner.Dispose()
    }
    return $null
}

function Get-DownloadsFolder {
    try {
        $p = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
        if ($p) { return $p }
    } catch { }
    return (Join-Path $env:USERPROFILE 'Downloads')
}

# ---------------------------------------------------------------- GitHub API

# GET $ApiBase/$Path as parsed JSON. GitHub's public read endpoints need no
# authentication, just a User-Agent header.
function Get-GitHubJson([string]$Path) {
    $headers = @{ 'User-Agent' = $UserAgent; 'Accept' = 'application/vnd.github+json' }
    $result = $null
    try {
        $result = Invoke-RestMethod -Uri "$ApiBase/$Path" -Headers $headers
    }
    catch {
        throw "Could not reach GitHub ($($_.Exception.Message)). Check your internet connection and try again."
    }
    return $result
}

# The App release currently marked Latest: its generation, version, folder name,
# and the download URL + size of its one zip asset.
function Get-LatestApp {
    $release = Get-GitHubJson 'releases/latest'
    $asset = @($release.assets | Where-Object { $_.name -match '^agl(\d+)_[\d_]+\.zip$' }) | Select-Object -First 1
    if (-not $asset) {
        throw "The latest release ($($release.tag_name)) has no agl<gen>_<version>.zip asset."
    }
    $null = $asset.name -match '^agl(?<gen>\d+)_(?<ver>[\d_]+)\.zip$'
    return [ordered]@{
        Gen     = $Matches['gen']
        Version = $Matches['gen'] + '.' + ($Matches['ver'] -replace '_', '.')
        Name    = $asset.name
        Url     = $asset.browser_download_url
        Size    = $asset.size
    }
}

# The highest-numbered "<TagPrefix>-<n>" release's asset named $AssetName - this is
# how the current windows_jre25.zip / agl25_lib.zip is found without ever having to
# hardcode a tag number in this file. Returns $null if there is no such release yet.
function Get-RuntimeAsset([string]$TagPrefix, [string]$AssetName) {
    $releases = @(Get-GitHubJson 'releases')
    $pattern = '^' + [regex]::Escape($TagPrefix) + '-(\d+)$'
    $best = $null; $bestN = -1
    foreach ($r in $releases) {
        if ($r.tag_name -match $pattern) {
            $n = [int]$Matches[1]
            if ($n -gt $bestN) { $bestN = $n; $best = $r }
        }
    }
    if (-not $best) { return $null }
    $asset = @($best.assets | Where-Object { $_.name -eq $AssetName }) | Select-Object -First 1
    if (-not $asset) { return $null }
    return [ordered]@{ Tag = $best.tag_name; Name = $asset.name; Url = $asset.browser_download_url; Size = $asset.size }
}

# A map zip's tag is always its own name (maps_2_4_3, ...), so its URL needs no
# lookup at all - this is the one part of the settings that used to be a table.
function Get-MapZipUrl([string]$TileName) {
    return "https://github.com/$GitHubRepo/releases/download/$TileName/$TileName.zip"
}

# ---------------------------------------------------------------- download

# One console line that is rewritten in place (the built-in progress pane can get
# stuck on screen in some consoles, so it is not used here).
function Write-InPlace([string]$Text) {
    $width = 79
    try { if ([Console]::BufferWidth -gt 40) { $width = [Console]::BufferWidth - 1 } } catch { }
    if ($Text.Length -gt $width) { $Text = $Text.Substring(0, $width) }
    Write-Host ("`r" + $Text.PadRight($width)) -NoNewline
}

# Streams the file itself so we can show live feedback: MB / percent / speed, and
# a note if data stops arriving for a while (which can happen on a slow link
# without the download having actually failed).
function Save-DownloadStream([string]$Url, [string]$Dest) {
    Add-Type -AssemblyName System.Net.Http
    $label = [System.IO.Path]::GetFileName($Dest) -replace '\.part$', ''
    $client = New-Object System.Net.Http.HttpClient
    $client.Timeout = [TimeSpan]::FromHours(2)
    [void]$client.DefaultRequestHeaders.UserAgent.ParseAdd($UserAgent)
    $shown = $false
    try {
        $clock = [System.Diagnostics.Stopwatch]::StartNew()
        $headers = $client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
        while (-not $headers.Wait(1000)) {
            Write-InPlace ("  Connecting ({0}) - {1}s so far" -f $label, [int]$clock.Elapsed.TotalSeconds)
            $shown = $true
        }
        $response = $headers.GetAwaiter().GetResult()
        [void]$response.EnsureSuccessStatusCode()
        $total = $response.Content.Headers.ContentLength
        $inStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $outStream = [System.IO.File]::Create($Dest)
        try {
            $buffer = New-Object byte[] 262144
            $done = [long]0
            $began = $clock.ElapsedMilliseconds
            $lastData = $began
            $lastShown = -1000
            while ($true) {
                $read = $inStream.ReadAsync($buffer, 0, $buffer.Length)
                while (-not $read.Wait(1000)) {
                    $quiet = [int](($clock.ElapsedMilliseconds - $lastData) / 1000)
                    Write-InPlace ("  {0}: {1:N1} MB so far - no data for {2}s, still waiting (not stuck)" -f $label, ($done / 1MB), $quiet)
                    $shown = $true
                }
                $n = $read.GetAwaiter().GetResult()
                if ($n -le 0) { break }
                $outStream.Write($buffer, 0, $n)
                $done += $n
                $lastData = $clock.ElapsedMilliseconds
                if (($lastData - $lastShown) -ge 250) {
                    $lastShown = $lastData
                    $secs = [Math]::Max(0.001, ($lastData - $began) / 1000.0)
                    $speed = ($done / 1MB) / $secs
                    if ($total) {
                        Write-InPlace ("  {0}: {1:N1} of {2:N1} MB ({3}%)  {4:N1} MB/s" -f $label, ($done / 1MB), ($total / 1MB), [int](100 * $done / $total), $speed)
                    } else {
                        Write-InPlace ("  {0}: {1:N1} MB  {2:N1} MB/s" -f $label, ($done / 1MB), $speed)
                    }
                    $shown = $true
                }
            }
        }
        finally {
            $outStream.Dispose()
            $inStream.Dispose()
        }
        if ($done -le 0) { throw 'The server sent an empty file.' }
        Write-InPlace ("  {0}: downloaded {1:N1} MB in {2}s" -f $label, ($done / 1MB), [int]$clock.Elapsed.TotalSeconds)
        $shown = $true
    }
    finally {
        if ($shown) { Write-Host '' }
        $client.Dispose()
    }
}

function Save-Download([string]$Url, [string]$Dest) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    try {
        Save-DownloadStream -Url $Url -Dest $Dest
    }
    catch {
        Write-Host "Streaming download did not work ($($_.Exception.Message)); trying the standard downloader..." -ForegroundColor Yellow
        if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Force }
        Invoke-WebRequest -UseBasicParsing -UserAgent $UserAgent -Uri $Url -OutFile $Dest
    }
}

function Test-ZipFile([string]$Path) {
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        $zip.Dispose()
        return $true
    } catch {
        return $false
    }
}

function Test-ZipHasFolder([string]$Path, [string]$Folder) {
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        try {
            foreach ($entry in $zip.Entries) {
                $first = (($entry.FullName -replace '\\', '/') -split '/' | Where-Object { $_ -ne '' } | Select-Object -First 1)
                if ($first -ieq $Folder) { return $true }
            }
            return $false
        }
        finally { $zip.Dispose() }
    } catch {
        return $false
    }
}

# Downloads $Url to $Downloads\$Name if a valid copy containing $ExpectFolder is not
# already sitting there (e.g. from a previous run that got this far). Returns the path.
function Get-OrDownloadZip([string]$Url, [string]$Name, [string]$Downloads, [string]$ExpectFolder) {
    $zipPath = Join-Path $Downloads $Name
    if ((Test-Path -LiteralPath $zipPath) -and (Test-ZipHasFolder $zipPath $ExpectFolder)) {
        Write-Host "$Name is already in your Downloads folder - using it."
        return $zipPath
    }
    $part = "$zipPath.part"
    if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force }
    Write-Host "Downloading $Name ..."
    Save-Download -Url $Url -Dest $part
    if (-not (Test-ZipFile $part)) {
        Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
        throw "$Name did not download as a valid zip file."
    }
    if (-not (Test-ZipHasFolder $part $ExpectFolder)) {
        Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
        throw "$Name does not contain a '$ExpectFolder' folder."
    }
    Move-Item -LiteralPath $part -Destination $zipPath -Force
    return $zipPath
}

# ---------------------------------------------------------------- extract / clean up

function Test-CleanupPattern([string]$Pattern) {
    if ([string]::IsNullOrWhiteSpace($Pattern)) { return $false }
    if ($Pattern.Trim() -eq '*') { return $false }
    if ($Pattern -match '[\\/]') { return $false }
    return $true
}

function Test-OtherOsName([string]$Name, [string[]]$Patterns) {
    foreach ($p in $Patterns) {
        if ((Test-CleanupPattern $p) -and ($Name -like $p)) { return $true }
    }
    return $false
}

# Removes other-OS items left behind by an older, single-zip-era install. Nothing
# this installer downloads is ever an other-OS file, so this only ever finds
# something on a folder that pre-dates the split release model.
function Remove-OtherOsLeftovers([string]$VersionPath, [string[]]$OtherOs) {
    $removed = @()
    if (-not (Test-Path -LiteralPath $VersionPath)) { return $removed }
    foreach ($item in @(Get-ChildItem -LiteralPath $VersionPath -Force)) {
        if (Test-OtherOsName $item.Name $OtherOs) {
            Remove-Item -LiteralPath $item.FullName -Recurse -Force
            $removed += $item.Name
        }
    }
    return $removed
}

# Extracts every entry of $ZipPath into $DestRoot (overwriting), after checking the
# zip actually has a top-level $ExpectFolder - the same safety check regardless of
# whether this is the app, a JRE, the lib set, or a map tile zip.
function Expand-ZipInto([string]$ZipPath, [string]$DestRoot, [string]$ExpectFolder) {
    $sep = [System.IO.Path]::DirectorySeparatorChar
    $root = [System.IO.Path]::GetFullPath($DestRoot).TrimEnd('\', '/')
    $files = 0
    $shown = $false
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entries = @($zip.Entries)
        $count = $entries.Count
        $index = 0

        $topNames = @($entries | ForEach-Object { ($_.FullName -replace '\\', '/') -split '/' | Select-Object -First 1 } | Where-Object { $_ } | Select-Object -Unique)
        if ($topNames -notcontains $ExpectFolder) {
            $found = ($topNames | Select-Object -First 5) -join ', '
            throw "The zip does not contain a '$ExpectFolder' folder (its top-level items: $found)."
        }
        $lastShown = [System.Diagnostics.Stopwatch]::StartNew()
        foreach ($entry in $entries) {
            $index++
            $rel = $entry.FullName -replace '\\', '/'
            $parts = @($rel -split '/' | Where-Object { $_ -ne '' })
            if ($parts.Count -eq 0) { continue }

            $target = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($root, ($parts -join $sep)))
            if (-not $target.StartsWith($root + $sep, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Unsafe path in zip: $($entry.FullName)"
            }

            if ($rel.EndsWith('/')) {
                [void](New-Item -ItemType Directory -Path $target -Force)
            } else {
                $folder = [System.IO.Path]::GetDirectoryName($target)
                if (-not (Test-Path -LiteralPath $folder)) { [void](New-Item -ItemType Directory -Path $folder -Force) }
                try {
                    if (Test-Path -LiteralPath $target -PathType Leaf) {
                        $existing = Get-Item -LiteralPath $target -Force
                        if ($existing.IsReadOnly) { $existing.IsReadOnly = $false }
                    }
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
                }
                catch {
                    throw "Could not write '$target' - is AGL still running? ($($_.Exception.Message))"
                }
                $files++
            }

            if ($lastShown.ElapsedMilliseconds -ge 250) {
                $lastShown.Restart()
                Write-InPlace ("  Extracting: {0} of {1} items ({2}%)" -f $index, $count, [int](100 * $index / $count))
                $shown = $true
            }
        }
        Write-InPlace ("  Extracting: {0} of {0} items (100%)" -f $count)
        $shown = $true
    }
    finally {
        if ($shown) { Write-Host '' }
        $zip.Dispose()
    }
    return $files
}

# True when the app zip's own jar already exists in $TargetDir with identical
# content - i.e. this exact app release is already installed there.
function Test-SameAppRelease([string]$ZipPath, [string]$ReleaseDir, [string]$JarName, [string]$TargetDir) {
    $installed = Join-Path $TargetDir $JarName
    if (-not (Test-Path -LiteralPath $installed -PathType Leaf)) { return $false }
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entry = $zip.GetEntry("$ReleaseDir/$JarName")
        if (-not $entry) { return $false }
        if ((Get-Item -LiteralPath $installed).Length -ne $entry.Length) { return $false }
        $stream = $entry.Open()
        try {
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $zipHash = [System.BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '')
        }
        finally { $stream.Dispose() }
        $fileHash = (Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash
        return $zipHash -eq $fileHash
    }
    finally {
        $zip.Dispose()
    }
}

# Reads AGL_TILES=... out of the extracted AGL_start.bat, the same way the start
# script itself decides which map folder it wants.
function Get-TileNameFromStartScript([string]$StartScriptPath) {
    if (-not (Test-Path -LiteralPath $StartScriptPath)) { return $null }
    $text = Get-Content -LiteralPath $StartScriptPath -Raw
    $m = [regex]::Match($text, '(?im)^\s*set\s+"?AGL_TILES=([^"\r\n]*)"?')
    if ($m.Success -and $m.Groups[1].Value) { return $m.Groups[1].Value }
    return $null
}

# ---------------------------------------------------------------- runtime components

# Downloads and extracts $AssetName into $VersionPath only if $ExpectFolder is not
# already there - the JRE and lib zips are large and change rarely, so this is
# never re-fetched just because the app itself was updated.
function Install-IfMissing([string]$Url, [string]$AssetName, [string]$ExpectFolder, [string]$VersionPath, [string]$Downloads) {
    $target = Join-Path $VersionPath $ExpectFolder
    if (Test-Path -LiteralPath $target -PathType Container) {
        Write-Host "$ExpectFolder is already present."
        return
    }
    $zipPath = Get-OrDownloadZip -Url $Url -Name $AssetName -Downloads $Downloads -ExpectFolder $ExpectFolder
    Write-Host "Extracting $AssetName ..."
    [void](Expand-ZipInto -ZipPath $zipPath -DestRoot $VersionPath -ExpectFolder $ExpectFolder)
    Write-Host "$ExpectFolder installed."
}

# Downloads and extracts the current agl25_lib.zip unconditionally, overwriting
# whatever is there - unlike the JRE, a lib jar can be patched on its own between
# app releases, so every install/patch run picks up whatever is current.
function Install-LibAlways([string]$Url, [string]$AssetName, [string]$ExpectFolder, [string]$VersionPath, [string]$Downloads) {
    $zipPath = Get-OrDownloadZip -Url $Url -Name $AssetName -Downloads $Downloads -ExpectFolder $ExpectFolder
    Write-Host "Extracting $AssetName ..."
    [void](Expand-ZipInto -ZipPath $zipPath -DestRoot $VersionPath -ExpectFolder $ExpectFolder)
    Write-Host "$ExpectFolder updated."
}

# Makes sure <VersionPath>\<TileName> exists. Never throws: a failure here must
# not abort an otherwise finished install. Returns $true when the folder is there.
function Install-MapTiles([string]$VersionPath, [string]$TileName, [string]$Downloads) {
    $target = Join-Path $VersionPath $TileName
    if (Test-Path -LiteralPath $target -PathType Container) {
        Write-Host "Map tiles '$TileName' are already present."
        return $true
    }
    $temp = Join-Path $VersionPath '_tiles_tmp'
    try {
        Write-Host "Map tiles '$TileName' are missing - downloading (a big download: it can take several minutes) ..."
        $zipPath = Get-OrDownloadZip -Url (Get-MapZipUrl $TileName) -Name "$TileName.zip" -Downloads $Downloads -ExpectFolder $TileName
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
        Write-Host 'Extracting map tiles...'
        [void](Expand-ZipInto -ZipPath $zipPath -DestRoot $temp -ExpectFolder $TileName)
        Move-Item -LiteralPath (Join-Path $temp $TileName) -Destination $target
        Remove-Item -LiteralPath $temp -Recurse -Force
        Write-Host "Map tiles installed in $target"
        return $true
    }
    catch {
        Write-Host "*** Map tiles were NOT installed: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
        return $false
    }
}

# ---------------------------------------------------------------- desktop icon

function Get-DesktopFolder {
    return [Environment]::GetFolderPath('Desktop')
}

# The "Start in" folder of an existing shortcut, or $null if it cannot be read.
function Get-ShortcutWorkDir([string]$LinkPath) {
    try { return (New-Object -ComObject WScript.Shell).CreateShortcut($LinkPath).WorkingDirectory }
    catch { return $null }
}

# AGL_shortcut.bat names the icon from %AGL_GEN%, passed explicitly here since
# there is no environment variable carrying it between processes any more.
function Invoke-ShortcutScript([string]$ScriptPath, [string]$WorkDir, [string]$Gen) {
    $env:AGL_GEN = $Gen
    Start-Process -FilePath 'cmd.exe' -ArgumentList "/c call `"$ScriptPath`" < nul" -WorkingDirectory $WorkDir -Wait -NoNewWindow
}

function Update-Shortcut([string]$VersionPath, [string]$Gen) {
    $script = Join-Path $VersionPath $ShortcutScript
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Host "Desktop icon skipped: $ShortcutScript was not found in $VersionPath." -ForegroundColor Yellow
        return
    }
    $linkName = "AGL$Gen.lnk"
    $linkPath = Join-Path (Get-DesktopFolder) $linkName
    Write-Host ''
    if (Test-Path -LiteralPath $linkPath) {
        $here = $VersionPath.TrimEnd('\', '/')
        $there = "$(Get-ShortcutWorkDir $linkPath)".TrimEnd('\', '/')
        if ($there -ieq $here) {
            Write-Host "The Desktop icon $linkName already points at this install."
            return
        }
        $question = "The Desktop icon $linkName points somewhere else ($there). Update it to this install? (Y/N) [Y]"
    } else {
        $question = 'Add an AGL icon to the Desktop? (Y/N) [Y]'
    }
    if ((Read-Choice $question 'Y') -ne 'Y') {
        Write-Host 'No icon added.'
        return
    }
    Invoke-ShortcutScript $script $VersionPath $Gen
    if (Test-Path -LiteralPath $linkPath) {
        Write-Host "Desktop icon $linkName created."
    } else {
        Write-Host 'The icon script ran, but no icon was found afterwards - check the Desktop.' -ForegroundColor Yellow
    }
}

# The install this generation's Desktop icon already points at, or $null.
function Find-ExistingInstall([string]$Gen) {
    $linkPath = Join-Path (Get-DesktopFolder) "AGL$Gen.lnk"
    if (-not (Test-Path -LiteralPath $linkPath)) { return $null }
    $dir = Get-ShortcutWorkDir $linkPath
    if ($dir -and (Test-Path -LiteralPath $dir -PathType Container)) { return $dir }
    return $null
}

# ---------------------------------------------------------------- main

function Invoke-Installer {
    try {
        Write-Host ''
        Write-Host 'AGL installer / updater' -ForegroundColor Cyan
        Write-Host ''
        Write-Host 'Note: the screen can seem to stand still for a while during downloads and unpacking.' -ForegroundColor Yellow
        Write-Host 'Windows may also scan the unpacked files. Nothing is wrong - please be patient.' -ForegroundColor Yellow
        Write-Host ''

        # 1. Which app release is current, and where does it belong?
        Write-Host 'Checking the latest release...'
        $app = Get-LatestApp
        $releaseDir = "$VersionDirPrefix$($app.Gen)"
        Write-Host "Latest release: AGL $($app.Version)"

        # 2. Is it already installed somewhere this PC knows about? If so, skip the
        #    folder chooser entirely; otherwise ask, same as a first install.
        $existing = Find-ExistingInstall $app.Gen
        if ($existing) {
            $parent = Split-Path -Parent $existing
            Write-Host ''
            Write-Host "Found an existing generation $($app.Gen) install: $existing"
            if ((Read-Choice 'Update it? (Y/N) [Y]' 'Y') -ne 'Y') {
                Write-Host 'Cancelled - nothing was installed or changed.'
                Pause-Exit 0
            }
        } else {
            $start = $DefaultParent
            $createdStart = $false
            try {
                if (-not (Test-Path -LiteralPath $start)) { [void](New-Item -ItemType Directory -Path $start -Force); $createdStart = $true }
            } catch { }
            if (-not (Test-Path -LiteralPath $start -PathType Container)) { $start = $env:USERPROFILE; $createdStart = $false }
            Write-Host 'A folder chooser is opening. Pick the PARENT folder; the release folder (e.g. Java25) is created inside it.'
            $parent = Select-ParentFolder $start
            if ($createdStart) {
                $picked = $false
                if (-not [string]::IsNullOrWhiteSpace($parent)) { $picked = ($parent.TrimEnd('\', '/') -ieq $start.TrimEnd('\', '/')) }
                if (-not $picked) {
                    try { if (@(Get-ChildItem -LiteralPath $start -Force -ErrorAction Stop).Count -eq 0) { Remove-Item -LiteralPath $start -ErrorAction Stop } } catch { }
                }
            }
            if ([string]::IsNullOrWhiteSpace($parent)) {
                Write-Host 'Cancelled - nothing was installed.'
                Pause-Exit 1
            }
            if (-not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
        }
        $versionPath = Join-Path $parent $releaseDir
        $isUpdate = Test-Path -LiteralPath $versionPath

        # 3. Downloads folder
        $downloads = Get-DownloadsFolder
        if (-not (Test-Path -LiteralPath $downloads)) { [void](New-Item -ItemType Directory -Path $downloads -Force) }

        Write-Host ''
        Write-Host "  Install folder : $versionPath"
        Write-Host "  Zips saved to  : $downloads"
        Write-Host ''

        # 4. App zip
        $zipFile = Get-OrDownloadZip -Url $app.Url -Name $app.Name -Downloads $downloads -ExpectFolder $releaseDir

        # 4b. Is this exact release already installed here?
        $jarName = $app.Name -replace '\.zip$', '.jar'
        if ($isUpdate) {
            if (Test-SameAppRelease -ZipPath $zipFile -ReleaseDir $releaseDir -JarName $jarName -TargetDir $versionPath) {
                Write-Host ''
                Write-Host "AGL $($app.Version) is already installed in $versionPath." -ForegroundColor Yellow
                $again = Read-Choice 'Continue and reinstall anyway? (Y/N) [N]' 'N'
                if ($again -ne 'Y') {
                    Write-Host 'Nothing was changed. (The download is still in your Downloads folder.)'
                    Pause-Exit 0
                }
            }
        }

        # 5. Extract the app zip and clear any pre-split-model leftovers
        Write-Host 'Extracting...'
        $fileCount = Expand-ZipInto -ZipPath $zipFile -DestRoot $parent -ExpectFolder $releaseDir
        if (-not (Test-Path -LiteralPath $versionPath)) {
            Stop-WithError "Extraction finished but '$releaseDir' was not created."
        }
        $leftovers = @(Remove-OtherOsLeftovers $versionPath $CleanupWindows)
        Write-Host "Extracted $fileCount files into $versionPath"
        if ($leftovers.Count -gt 0) { Write-Host "Removed other-OS items from an earlier install: $($leftovers -join ', ')" }

        # 6. Windows JRE - only if missing
        Write-Host ''
        $jre = Get-RuntimeAsset -TagPrefix 'jre25-windows' -AssetName 'windows_jre25.zip'
        if ($jre) {
            Install-IfMissing -Url $jre.Url -AssetName $jre.Name -ExpectFolder 'windows_jre25' -VersionPath $versionPath -Downloads $downloads
        } else {
            Write-Host 'WARNING: no windows_jre25 runtime release was found.' -ForegroundColor Yellow
        }

        # 7. Library jars - always refreshed, since one can be patched on its own
        $lib = Get-RuntimeAsset -TagPrefix 'lib25' -AssetName 'agl25_lib.zip'
        if ($lib) {
            Install-LibAlways -Url $lib.Url -AssetName $lib.Name -ExpectFolder 'agl25_lib' -VersionPath $versionPath -Downloads $downloads
        } else {
            Write-Host 'WARNING: no agl25_lib runtime release was found.' -ForegroundColor Yellow
        }

        # 8. Map tiles named by AGL_start.bat - downloaded only when that folder is missing
        $tilesOk = $true
        $tileName = Get-TileNameFromStartScript (Join-Path $versionPath $StartScript)
        if ($tileName) {
            Write-Host ''
            $tilesOk = Install-MapTiles $versionPath $tileName $downloads
        } else {
            Write-Host "$StartScript names no map tile folder - map tile step skipped."
        }

        # 9. Desktop icon (named from the generation of this release)
        Update-Shortcut $versionPath $app.Gen

        Write-Host ''
        if (-not $tilesOk) {
            Write-Host "WARNING: the map tiles ($tileName) are not installed, so AGL will have no maps yet. Run this installer again to retry." -ForegroundColor Yellow
        }
        if ($isUpdate) { Write-Host 'Update complete.' -ForegroundColor Green }
        else { Write-Host 'Install complete.' -ForegroundColor Green }
        Write-Host "AGL is in $versionPath"
        Pause-Exit 0
    }
    catch {
        Stop-WithError $_.Exception.Message
    }
}

Invoke-Installer
