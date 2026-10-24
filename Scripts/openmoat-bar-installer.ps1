# Install or update OpenMoat Bar from its GitHub release, for the current user only:
# %LOCALAPPDATA%\Programs\OpenMoat Bar and a Start menu entry. The download is checked
# against the release's SHA256SUMS before anything is installed.
# $env:OPENMOAT_BAR_VERSION = "0.3.0" installs that version instead of the latest.
# An install from before the rename (MoatBar) is replaced, and its start at login carried over.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = 'crocodile-labs/openmoat-bar'
$version = if ($env:OPENMOAT_BAR_VERSION) { $env:OPENMOAT_BAR_VERSION }
           elseif ($env:MOATBAR_VERSION) { $env:MOATBAR_VERSION } else { 'latest' }
$base = if ($version -eq 'latest') { "https://github.com/$repo/releases/latest/download" }
        else { "https://github.com/$repo/releases/download/v$version" }
$asset = 'openmoat-bar-windows-x64.zip'
# OPENMOAT_BAR_DIST_DIR takes the files from a folder instead (how CI tests this script).
$distDir = if ($env:OPENMOAT_BAR_DIST_DIR) { $env:OPENMOAT_BAR_DIST_DIR } else { $env:MOATBAR_DIST_DIR }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("openmoat-bar-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    foreach ($name in @('SHA256SUMS', $asset)) {
        if ($distDir) { Copy-Item (Join-Path $distDir $name) "$tmp\$name" }
        else { Invoke-WebRequest -UseBasicParsing "$base/$name" -OutFile "$tmp\$name" }
    }

    $line = Get-Content "$tmp\SHA256SUMS" | Where-Object { ($_ -split '\s+')[1] -in @($asset, "*$asset") }
    if (-not $line) { throw "$asset is not in SHA256SUMS" }
    $expected = ($line -split '\s+')[0]
    $actual = (Get-FileHash -Algorithm SHA256 "$tmp\$asset").Hash
    if ($expected -ne $actual) { throw "$asset does not match SHA256SUMS; nothing was installed" }

    $dest = Join-Path $env:LOCALAPPDATA 'Programs\OpenMoat Bar'
    Get-Process -Name openmoat-bar -ErrorAction SilentlyContinue | Stop-Process -Force
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    Expand-Archive -Path "$tmp\$asset" -DestinationPath $dest
    $exe = Join-Path $dest 'openmoat-bar.exe'
    if (-not (Test-Path $exe)) { throw "$asset has no openmoat-bar.exe" }

    $programs = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $programs 'OpenMoat Bar.lnk'))
    $shortcut.TargetPath = $exe
    $shortcut.WorkingDirectory = $dest
    $shortcut.Description = 'See what OpenMoat does for your coding agents. Read-only.'
    $shortcut.Save()

    # The same app under its old name, MoatBar: stop it, remove it, and move its
    # start-at-login value to the new name so it does not start twice.
    Get-Process -Name moatbar -ErrorAction SilentlyContinue | Stop-Process -Force
    $old = Join-Path $env:LOCALAPPDATA 'Programs\MoatBar'
    if (Test-Path $old) { Remove-Item -Recurse -Force $old }
    $oldMenu = Join-Path $programs 'MoatBar.lnk'
    if (Test-Path $oldMenu) { Remove-Item -Force $oldMenu }
    $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    if (Get-ItemProperty -Path $run -Name 'MoatBar' -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $run -Name 'MoatBar'
        Set-ItemProperty -Path $run -Name 'OpenMoat Bar' -Value "`"$exe`" --background"
        Write-Host 'openmoat-bar-installer: start at login moved from MoatBar to OpenMoat Bar'
    }

    Write-Host "openmoat-bar-installer: installed $dest"
    Write-Host 'openmoat-bar-installer: start it from the Start menu (OpenMoat Bar)'
    if (-not (Get-Command openmoat -ErrorAction SilentlyContinue) -and -not (Get-Command moat -ErrorAction SilentlyContinue)) {
        Write-Host 'openmoat-bar-installer: OpenMoat Bar shows what OpenMoat does; install OpenMoat too: https://openmoat.dev/docs/quickstart/'
    }
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
