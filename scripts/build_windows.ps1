# Build mruby 4.0.0 and the mrb.cr C shim on Windows.
#
# Supports MSVC (cl.exe) and MinGW gcc toolchains. mruby's toolchain is
# auto-detected: inside a Developer Command Prompt (VisualStudioVersion set)
# it uses visualcpp; otherwise gcc.
# From a Developer Command Prompt / MSYS2 shell:
#   powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1
# Or with a specific Ruby: $env:RUBY = 'C:\Ruby31\bin\ruby.exe'; .\scripts\build_windows.ps1
#
# Produces both artifact name pairs, so either Crystal target annotation
# resolves (MinGW links .a/.o, MSVC links .lib/.obj):
#   lib/libmruby.a + lib/mrb_shim.o   (used by Crystal x86_64-w64-windows-gnu)
#   lib/libmruby.lib + lib/mrb_shim.obj (used by the Crystal MSVC target)
# One file of each pair is a byte copy of the toolchain's native output.
#
# Verify the C layer with the toolchain-independent smoke test, e.g. (MSVC):
#   cl /I vendor/mruby/include /I vendor/mruby/build/host/include /Fe:build\smoke.exe scripts/c_smoke.c lib/mrb_shim.obj lib/libmruby.lib
#   .\build\smoke.exe

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
    throw "command failed with exit code ${LASTEXITCODE}: $Command"
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

  if ($cc.Name -eq "msvc") {
    # mruby's rake shells out commands unquoted through cmd.exe, so:
    # - bare link.exe can resolve to a GNU coreutils `link` (bundled with Git
    #   for Windows / RubyInstaller's MSYS) instead of the MSVC linker;
    # - a quoted or spaced absolute path gets split at whitespace.
    # Pin LD/AR to space-free 8.3 absolute paths (fall back to quoting when
    # short names are disabled). CC stays a bare cl.exe: nothing shadows it,
    # and setting CC would switch mruby's toolchain autodetection to gcc.
    if ($env:VCToolsInstallDir) {
      $hostArch = if ($env:VSCMD_ARG_HOST_ARCH) { $env:VSCMD_ARG_HOST_ARCH } else { "x64" }
      $tgtArch  = if ($env:VSCMD_ARG_TGT_ARCH)  { $env:VSCMD_ARG_TGT_ARCH }  else { "x64" }
      $vcBin = Join-Path $env:VCToolsInstallDir "bin\Host$hostArch\$tgtArch"
      $fso = New-Object -ComObject Scripting.FileSystemObject
      $short = $fso.GetFolder($vcBin).ShortPath
      if ($short -notlike "* *") {
        $linkExe = Join-Path $short "link.exe"
        $libExe = Join-Path $short "lib.exe"
      } else {
        $linkExe = '"{0}"' -f (Join-Path $vcBin "link.exe")
        $libExe = '"{0}"' -f (Join-Path $vcBin "lib.exe")
      }
      $env:LD = $linkExe
      $env:AR = $libExe
      Write-Host "Pinned MSVC linker: $env:LD"
      Write-Host "Pinned MSVC archiver: $env:AR"
    } else {
      Write-Warning "VCToolsInstallDir is not set; mruby will resolve link.exe from PATH and may pick up a GNU coreutils link"
    }
  }

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
  # mruby's visualcpp toolchain archives with lib.exe into libmruby.lib;
  # gcc/clang toolchains use ar into libmruby.a. Accept either.
  $mrubyLib = @(
    (Join-Path $MrubyDir "build/host/lib/libmruby.lib"),
    (Join-Path $MrubyDir "build/host/lib/libmruby.a")
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (!$mrubyLib) {
    throw "mruby build produced neither build/host/lib/libmruby.lib nor build/host/lib/libmruby.a"
  }
  # Stage both canonical name pairs so either Crystal target annotation
  # (MinGW: .a/.o, MSVC: .lib/.obj) resolves; one of each pair is a copy.
  Copy-Item $mrubyLib "lib/libmruby.lib" -Force
  Copy-Item $mrubyLib "lib/libmruby.a" -Force

  $include = Join-Path $MrubyDir "include"
  $buildInclude = Join-Path $MrubyDir "build/host/include"
  if ($cc.Name -eq "msvc") {
    # Mirror the flags mruby's visualcpp toolchain used for libmruby so the
    # shim sees the same ABI (/MD, MRB_STACK_EXTEND_DOUBLING).
    Invoke-Native { & $cc.Exe /nologo /c /O2 /MD /D_CRT_SECURE_NO_WARNINGS /D MRB_STACK_EXTEND_DOUBLING /I $include /I $buildInclude /Fobuild_mrb_shim.obj src/mrb/shim.c }
    Copy-Item "build_mrb_shim.obj" "lib/mrb_shim.obj" -Force
    Remove-Item "build_mrb_shim.obj" -ErrorAction SilentlyContinue
  } else {
    Invoke-Native { & $cc.Exe -O2 -I $include -I $buildInclude -c src/mrb/shim.c -o lib/mrb_shim.o }
  }
  Copy-Item "lib/mrb_shim.obj" "lib/mrb_shim.o" -ErrorAction SilentlyContinue
  Copy-Item "lib/mrb_shim.o" "lib/mrb_shim.obj" -ErrorAction SilentlyContinue

  Write-Host "mruby artifacts built: lib/libmruby.a + lib/mrb_shim.o and lib/libmruby.lib + lib/mrb_shim.obj"
  Write-Host "C compiler used: $($cc.Name) ($($cc.Exe))"
} finally {
  Pop-Location
}
