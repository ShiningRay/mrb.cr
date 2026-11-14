# Build mruby 4.0.0 and the mrb.cr C shim on Windows.
#
# Supports MSVC (cl.exe) and MinGW gcc toolchains.
# From a Developer Command Prompt / MSYS2 shell:
#   powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1
# Or with a specific Ruby: $env:RUBY = 'C:\Ruby31\bin\ruby.exe'; .\scripts\build_windows.ps1
#
# Produces (canonical, for Crystal x86_64-w64-mingw32 target):
#   lib/libmruby.a
#   lib/mrb_shim.o
# and Windows aliases for compatibility:
#   lib/libmruby.lib
#   lib/mrb_shim.obj

param(
  [string]$MrubyVersion = "4.0.0",
  [string]$MrubyRepo    = "https://github.com/mruby/mruby.git",
  [string]$MrubyDir     = "vendor/mruby",
  [string]$Ruby         = $(if ($env:RUBY) { $env:RUBY } else { "ruby" })
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Native {
  param([scriptblock]$Command)
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "command failed with exit code $LASTEXITCODE: $Command"
  }
}

function Resolve-CCompiler {
  $cl = Get-Command cl.exe -ErrorAction SilentlyContinue
  if ($cl) {
    return @{ Name = "msvc"; Exe = $cl.Source }
  }
  $gcc = Get-Command gcc -ErrorAction SilentlyContinue
  if ($gcc) {
    return @{ Name = "gcc"; Exe = $gcc.Source }
  }
  throw "no supported C compiler found in PATH (need cl.exe or gcc)"
}

Push-Location $RepoRoot
try {
  $cc = Resolve-CCompiler
  Write-Host "Using C compiler: $($cc.Exe)"

  New-Item -ItemType Directory -Force (Split-Path $MrubyDir) | Out-Null
  if (Test-Path (Join-Path $MrubyDir ".git")) {
    Push-Location $MrubyDir
    try {
      Invoke-Native { git fetch --depth 1 origin tag $MrubyVersion }
      Invoke-Native { git checkout -q $MrubyVersion }
    } finally { Pop-Location }
  } elseif (!(Test-Path $MrubyDir)) {
    Invoke-Native { git clone --depth 1 --branch $MrubyVersion $MrubyRepo $MrubyDir }
  }

  # mruby writes a .lock next to MRUBY_CONFIG; copy the config to a writable
  # build directory so the repo checkout/config stays read-only and clean.
  $configSrc = Join-Path $RepoRoot "build_config/mrb_cr.rb"
  $configDstDir = Join-Path $MrubyDir "build"
  $configDst = Join-Path $configDstDir "mrb_cr.rb"
  New-Item -ItemType Directory -Force $configDstDir | Out-Null
  Copy-Item $configSrc $configDst -Force

  Push-Location $MrubyDir
  try {
    $env:MRUBY_CONFIG = "build/mrb_cr.rb"
    Invoke-Native { & $Ruby -S rake -j4 }
  } finally { Pop-Location }

  New-Item -ItemType Directory -Force "lib" | Out-Null
  $mrubyLib = Join-Path $MrubyDir "build/host/lib/libmruby.a"
  if (!(Test-Path $mrubyLib)) {
    throw "mruby build did not produce $mrubyLib"
  }
  Copy-Item $mrubyLib "lib/libmruby.a" -Force
  Copy-Item "lib/libmruby.a" "lib/libmruby.lib" -Force

  $include = Join-Path $MrubyDir "include"
  $buildInclude = Join-Path $MrubyDir "build/host/include"
  if ($cc.Name -eq "msvc") {
    Invoke-Native { & $cc.Exe /nologo /c /O2 /I $include /I $buildInclude /Fobuild_mrb_shim.obj src/mrb/shim.c }
    Copy-Item "build_mrb_shim.obj" "lib/mrb_shim.obj" -Force
    Copy-Item "lib/mrb_shim.obj" "lib/mrb_shim.o" -Force
    Remove-Item "build_mrb_shim.obj" -ErrorAction SilentlyContinue
  } else {
    Invoke-Native { & $cc.Exe -O2 -I $include -I $buildInclude -c src/mrb/shim.c -o lib/mrb_shim.o }
    Copy-Item "lib/mrb_shim.o" "lib/mrb_shim.obj" -Force
  }

  Write-Host "mruby artifacts built: lib/libmruby.a, lib/mrb_shim.o (with .lib/.obj aliases)"
} finally {
  Pop-Location
}
