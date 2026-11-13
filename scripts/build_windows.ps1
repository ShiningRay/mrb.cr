# Builds libmruby and the mrb.cr shim on Windows.
#
# Status: unverified. The project has no Windows CI runner yet. Run this in a
# "Developer PowerShell for Visual Studio" session with Ruby >= 3.0, Rake, git,
# bison, and gperf on PATH.
#
# Usage:
#   pwsh scripts/build_windows.ps1

$ErrorActionPreference = "Stop"

$mrubyVersion = "4.0.0"
$mrubyRepo = "https://github.com/mruby/mruby.git"
$mrubyDir = Join-Path $PSScriptRoot "..\vendor\mruby"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$libDir = Join-Path $root "lib"

if (-not (Test-Path (Join-Path $mrubyDir ".git"))) {
    git clone --depth 1 --branch $mrubyVersion $mrubyRepo $mrubyDir
}

Push-Location $mrubyDir
try {
    $env:MRUBY_CONFIG = Join-Path $root "build_config\mrb_cr.rb"
    ruby -S rake -j4
} finally {
    Pop-Location
}

New-Item -ItemType Directory -Force $libDir | Out-Null
Copy-Item (Join-Path $mrubyDir "build\host\lib\libmruby.lib") (Join-Path $libDir "libmruby.lib") -Force

& cl.exe /nologo /O2 /c src\mrb\shim.c `
    /I"$mrubyDir\include" `
    /I"$mrubyDir\build\host\include" `
    /Fo"$libDir\mrb_shim.obj"

Write-Host "Built lib/libmruby.lib and lib/mrb_shim.obj"
