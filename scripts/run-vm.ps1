$ErrorActionPreference = "Stop"

$vbox = Join-Path $env:ProgramFiles "Oracle\VirtualBox\VBoxManage.exe"
if (-not (Test-Path -LiteralPath $vbox)) {
    $command = Get-Command VBoxManage -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "VirtualBox is required. Install Oracle VirtualBox, then run this script again."
    }
    $vbox = $command.Source
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$iso = Join-Path $projectRoot "dist\LumenOS.iso"
if (-not (Test-Path -LiteralPath $iso)) {
    throw "dist\LumenOS.iso is missing. Run .\scripts\build.ps1 first."
}

$name = "LumenOS-BIOS-Test"
$registered = (& $vbox list vms | Out-String)
if ($LASTEXITCODE -ne 0) { throw "Could not list VirtualBox VMs." }

if ($registered -notmatch [regex]::Escape("`"$name`"")) {
    & $vbox createvm --name $name --ostype Other --register
    if ($LASTEXITCODE -ne 0) { throw "Could not create the LumenOS virtual machine." }

    & $vbox modifyvm $name --memory 64 --vram 16 --firmware bios --boot1 dvd --boot2 none --boot3 none --boot4 none --graphicscontroller vmsvga --nic1 none
    if ($LASTEXITCODE -ne 0) { throw "Could not configure the LumenOS virtual machine." }

    & $vbox storagectl $name --name IDE --add ide --controller PIIX4
    if ($LASTEXITCODE -ne 0) { throw "Could not add the virtual CD controller." }
}

$running = (& $vbox list runningvms | Out-String)
if ($LASTEXITCODE -ne 0) { throw "Could not check running VirtualBox VMs." }
if ($running -match [regex]::Escape("`"$name`"")) {
    Write-Output "$name is already running."
    exit 0
}

& $vbox storageattach $name --storagectl IDE --port 0 --device 0 --type dvddrive --medium $iso
if ($LASTEXITCODE -ne 0) { throw "Could not attach LumenOS.iso to the virtual machine." }

& $vbox startvm $name --type gui
if ($LASTEXITCODE -ne 0) { throw "VirtualBox could not start the LumenOS virtual machine." }
