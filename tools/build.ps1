<#
.SYNOPSIS
Export a standalone Windows release executable using Godot 4.7.2.
.DESCRIPTION
Install the matching Godot 4.7.2 standard export templates in Godot first.
The default output is builds\DeskBreaker.exe relative to the repository.
The script does not change PATH, user environment variables, or engine settings.
.EXAMPLE
.\tools\build.ps1 -GodotPath 'C:\Tools\Godot\Godot_console.exe'
.EXAMPLE
.\tools\build.ps1 -GodotPath 'C:\Tools\Godot\Godot_console.exe' -OutputPath 'D:\Games\DeskBreaker.exe'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot-common.ps1')
$executable = Resolve-DeskBreakerGodot -GodotPath $GodotPath
$repoPath = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoPath 'game'
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoPath 'builds\DeskBreaker.exe'
}
if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path (Get-Location).ProviderPath $OutputPath
}
$outputExe = [System.IO.Path]::GetFullPath($OutputPath)
if ([System.IO.Path]::GetExtension($outputExe) -ne '.exe') {
    throw 'OutputPath must end in .exe.'
}
$null = New-Item -ItemType Directory -Path (Split-Path -Parent $outputExe) -Force

Write-Host 'Importing project resources...'
$null = Invoke-DeskBreakerGodot -Executable $executable -Arguments @(
    '--headless', '--path', $projectPath, '--editor', '--import'
)
Write-Host 'Exporting Windows Desktop release...'
$null = Invoke-DeskBreakerGodot -Executable $executable -Arguments @(
    '--headless', '--path', $projectPath, '--export-release', 'Windows Desktop', $outputExe
)
if (-not (Test-Path -LiteralPath $outputExe -PathType Leaf)) {
    throw 'Godot returned without creating the requested executable.'
}
$stream = [System.IO.File]::OpenRead($outputExe)
try {
    if ($stream.Length -lt 1048576 -or $stream.ReadByte() -ne 77 -or $stream.ReadByte() -ne 90) {
        throw 'The export is not a plausible Windows executable.'
    }
}
finally { $stream.Dispose() }

$artifact = Get-Item -LiteralPath $outputExe
$hash = Get-FileHash -LiteralPath $outputExe -Algorithm SHA256
Write-Host "Created: $($artifact.FullName) ($($artifact.Length) bytes)"
Write-Host "SHA256: $($hash.Hash)"
Write-Host 'Export succeeded. Launch the executable on Windows for the platform playtest.'
