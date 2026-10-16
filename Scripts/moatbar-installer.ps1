# Install or update MoatBar from its GitHub release, for the current user only:
# %LOCALAPPDATA%\Programs\MoatBar and a Start menu entry. The download is checked
# against the release's SHA256SUMS before anything is installed.
# $env:MOATBAR_VERSION = "0.1.0" installs that version instead of the latest.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = 'crocodile-labs/moatbar'
$version = if ($env:MOATBAR_VERSION) { $env:MOATBAR_VERSION } else { 'latest' }
$base = if ($version -eq 'latest') { "https://github.com/$repo/releases/latest/download" }
        else { "https://github.com/$repo/releases/download/v$version" }
$asset = 'MoatBar-windows-x64.zip'

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("moatbar-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    foreach ($name in @('SHA256SUMS', $asset)) {
        # MOATBAR_DIST_DIR takes the files from a folder instead (how CI tests this script).
        if ($env:MOATBAR_DIST_DIR) { Copy-Item (Join-Path $env:MOATBAR_DIST_DIR $name) "$tmp\$name" }
        else { Invoke-WebRequest -UseBasicParsing "$base/$name" -OutFile "$tmp\$name" }
    }

    $line = Get-Content "$tmp\SHA256SUMS" | Where-Object { ($_ -split '\s+')[1] -in @($asset, "*$asset") }
    if (-not $line) { throw "$asset is not in SHA256SUMS" }
    $expected = ($line -split '\s+')[0]
    $actual = (Get-FileHash -Algorithm SHA256 "$tmp\$asset").Hash
    if ($expected -ne $actual) { throw "$asset does not match SHA256SUMS; nothing was installed" }

    $dest = Join-Path $env:LOCALAPPDATA 'Programs\MoatBar'
    Get-Process -Name moatbar -ErrorAction SilentlyContinue | Stop-Process -Force
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    Expand-Archive -Path "$tmp\$asset" -DestinationPath $dest
    $exe = Join-Path $dest 'moatbar.exe'
    if (-not (Test-Path $exe)) { throw "$asset has no moatbar.exe" }

    $menu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\MoatBar.lnk'
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($menu)
    $shortcut.TargetPath = $exe
    $shortcut.WorkingDirectory = $dest
    $shortcut.Description = 'See what OpenMoat does for your coding agents. Read-only.'
    $shortcut.Save()

    Write-Host "moatbar-installer: installed $dest"
    Write-Host 'moatbar-installer: start it from the Start menu (MoatBar)'
    if (-not (Get-Command moat -ErrorAction SilentlyContinue)) {
        Write-Host 'moatbar-installer: MoatBar shows what OpenMoat does; install OpenMoat too: https://github.com/crocodile-labs/openmoat#install'
    }
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
