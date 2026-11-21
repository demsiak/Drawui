param([string]$LuauPath = 'luau')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools\Bundle.ps1')
$read = { param($p) [IO.File]::ReadAllText((Join-Path $PSScriptRoot $p)) }
$lib = Get-DrawuiBundle -ProjectPath $PSScriptRoot
# The demo loads the library with readfile; under test it receives the bundle as a parameter instead.
$demo = (& $read 'examples\demo.luau') -replace '^local UI = [^\r\n]*\r?\n', ''
$source = "$(& $read 'tests\mock.luau')`nlocal UI = (function()`n$lib`nend)()`nlocal function createDemo(UI)`n$demo`nend`n$(& $read 'tests\spec.luau')"
$testFile = Join-Path ([IO.Path]::GetTempPath()) 'Drawui.test.luau'
[IO.File]::WriteAllText($testFile, $source, [Text.UTF8Encoding]::new($false))
& $LuauPath $testFile
if ($LASTEXITCODE -ne 0) { throw 'Drawui tests failed' }
