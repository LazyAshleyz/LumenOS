$ErrorActionPreference = "Stop"

$nasm = Get-Command nasm -ErrorAction SilentlyContinue
if (-not $nasm) {
    $nasmRoot = Join-Path $env:LOCALAPPDATA "Programs\NASM"
    $nasmExe = Get-ChildItem -LiteralPath $nasmRoot -Filter nasm.exe -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($nasmExe) {
        $nasmPath = $nasmExe.FullName
    }
}
else {
    $nasmPath = $nasm.Source
}
if (-not $nasmPath) {
    throw "NASM is required to build LumenOS. Install NASM and add nasm.exe to PATH: https://www.nasm.us/"
}
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    throw "Node.js is required to build the ISO. Install Node.js and add node.exe to PATH."
}
if (-not (Get-Command clang++ -ErrorAction SilentlyContinue) -or
    -not (Get-Command ld.lld -ErrorAction SilentlyContinue) -or
    -not (Get-Command llvm-objcopy -ErrorAction SilentlyContinue)) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    foreach ($pathEntry in ($userPath -split ";")) {
        if ($pathEntry -and
            (Test-Path -LiteralPath (Join-Path $pathEntry "clang++.exe")) -and
            (Test-Path -LiteralPath (Join-Path $pathEntry "ld.lld.exe")) -and
            (Test-Path -LiteralPath (Join-Path $pathEntry "llvm-objcopy.exe"))) {
            $env:Path = "$pathEntry;$env:Path"
            break
        }
    }
}
$clang = Get-Command clang++ -ErrorAction SilentlyContinue
$linker = Get-Command ld.lld -ErrorAction SilentlyContinue
$objcopy = Get-Command llvm-objcopy -ErrorAction SilentlyContinue
if (-not $clang -or -not $linker -or -not $objcopy) {
    throw "LLVM is required to compile the C++ kernel. Install LLVM and add clang++.exe, ld.lld.exe, and llvm-objcopy.exe to PATH."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $projectRoot "dist"
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$bootBinary = Join-Path $outputDirectory "boot.bin"
$kernelBinary = Join-Path $outputDirectory "kernel.bin"
$kernelElf = Join-Path $outputDirectory "kernel.elf"
$kernelObject = Join-Path $outputDirectory "kernel-asm.o"
$userObject = Join-Path $outputDirectory "user.o"

try {
    & $nasmPath -f bin (Join-Path $projectRoot "src\boot.asm") -o $bootBinary
    if ($LASTEXITCODE -ne 0) { throw "NASM failed to assemble boot.asm." }

    & $nasmPath -f elf32 (Join-Path $projectRoot "src\kernel.asm") -o $kernelObject
    if ($LASTEXITCODE -ne 0) { throw "NASM failed to assemble kernel.asm." }

    & $clang.Source --target=i386-unknown-none-elf -m16 -std=c++17 -Os -ffreestanding -fno-exceptions -fno-rtti -fno-stack-protector -fno-pic -fno-pie -fno-builtin -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-use-cxa-atexit -fno-threadsafe-statics -c (Join-Path $projectRoot "src\user.cpp") -o $userObject
    if ($LASTEXITCODE -ne 0) { throw "Clang failed to compile user.cpp." }

    & $linker.Source -m elf_i386 -T (Join-Path $projectRoot "src\kernel.ld") -o $kernelElf $kernelObject $userObject
    if ($LASTEXITCODE -ne 0) { throw "LLD failed to link the C++ kernel." }

    & $objcopy.Source -O binary $kernelElf $kernelBinary
    if ($LASTEXITCODE -ne 0) { throw "LLVM objcopy failed to create the kernel binary." }

    & $node.Source (Join-Path $PSScriptRoot "build.js")
    if ($LASTEXITCODE -ne 0) { throw "The ISO image builder failed." }
}
finally {
    Remove-Item -LiteralPath $bootBinary, $kernelBinary, $kernelElf, $kernelObject, $userObject -Force -ErrorAction SilentlyContinue
}
