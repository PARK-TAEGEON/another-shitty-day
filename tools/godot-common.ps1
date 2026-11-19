# Shared helpers for Windows PowerShell 5.1 and PowerShell 7.
# All settings apply to the current command only. No user environment is changed.

Set-StrictMode -Version Latest

function Invoke-DeskBreakerGodot {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    # Native stderr can contain harmless Godot warnings on Windows PowerShell.
    # Inspect the process exit code and Godot error prefixes explicitly instead.
    $previousPreference = $ErrorActionPreference
    $lines = New-Object System.Collections.Generic.List[string]
    try {
        $ErrorActionPreference = 'Continue'
        # Stream both pipes while the process runs. Collecting 2>&1 only after
        # exit can fill the pipe and leave Godot blocked on a long log.
        & $Executable @Arguments 2>&1 | ForEach-Object {
            $line = $_.ToString()
            $lines.Add($line)
            Write-Host $line
        }
        $nativeExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    $text = $lines -join "`n"
    if ($nativeExitCode -ne 0) {
        throw "Godot exited with code $nativeExitCode. See the output above."
    }
    if ($text -match '(?m)^\s*(SCRIPT ERROR|ERROR):') {
        throw 'Godot reported an error despite returning zero. See the output above.'
    }
    return $text
}

function Resolve-DeskBreakerGodot {
    param([Parameter(Mandatory = $true)][string]$GodotPath)

    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        throw "Godot executable not found: $GodotPath"
    }
    $executable = (Resolve-Path -LiteralPath $GodotPath).Path
    $version = Invoke-DeskBreakerGodot -Executable $executable -Arguments @('--version')
    if ($version.Trim() -notmatch '^4\.7\.2\.stable(?:\.|$)') {
        throw 'This project requires Godot 4.7.2 stable. On Windows, pass its console executable for reliable logs.'
    }
    return $executable
}
