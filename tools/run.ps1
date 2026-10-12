<#
.SYNOPSIS
Run DESK BREAKER with an explicitly selected Godot 4.7.2 executable.
.EXAMPLE
.\tools\run.ps1 -GodotPath 'C:\Tools\Godot\Godot_console.exe'
.EXAMPLE
.\tools\run.ps1 -GodotPath 'C:\Tools\Godot\Godot_console.exe' -Editor
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [switch]$Editor
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot-common.ps1')
$executable = Resolve-DeskBreakerGodot -GodotPath $GodotPath
$projectPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'game'
$arguments = @('--path', $projectPath)
if ($Editor) { $arguments += '--editor' }

Write-Host 'Starting DESK BREAKER. Close the game or editor to return to this terminal.'
$null = Invoke-DeskBreakerGodot -Executable $executable -Arguments $arguments
