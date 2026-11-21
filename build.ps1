$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools\Bundle.ps1')
$source = Get-DrawuiBundle -ProjectPath $PSScriptRoot
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'Drawui.luau'), $source, [Text.UTF8Encoding]::new($false))
Write-Output 'Built Drawui.luau'
