# LumenOS

LumenOS is a tiny, standalone 16-bit x86 real-mode operating-system
demonstration. It boots from a BIOS El Torito CD image and provides a
keyboard-driven text shell using BIOS video and keyboard services.

## Build

On Windows, install NASM, Node.js, and LLVM, and make sure `nasm.exe`,
`node.exe`, `clang++.exe`, `ld.lld.exe`, and `llvm-objcopy.exe` are on `PATH`,
then run:

```powershell
winget install --id LLVM.LLVM --exact
.\scripts\build.ps1
```

After installing LLVM, open a new terminal so its tools are available on
`PATH`. NASM and Node.js must also be installed.

The project is organized as follows:

- `src\` — bootloader and kernel assembly source
- `src\user.cpp` — C++ shell commands compiled into the kernel
- `src\kernel.ld` — linker script for the real-mode kernel
- `scripts\` — build and VirtualBox launcher scripts
- `dist\LumenOS.iso` — bootable ISO for a legacy BIOS/CSM virtual machine
- `dist\LumenOS.img` — 1.44 MB floppy image used by the ISO boot catalog

No Node.js packages are required; the ISO9660/El Torito image is built by
`scripts\build.js`.

## Add a C++ command

Edit `src\user.cpp` and add a branch to `user_command`. For example, the
included `hello` command prints a message in the LumenOS shell. Use
`kernel_print("Your message\r\n")` to write text to the screen, then rebuild
with `.\scripts\build.ps1` and boot the updated `dist\LumenOS.iso`.

This is freestanding 16-bit real-mode C++: there is no C++ standard library,
operating-system runtime, or dynamic memory allocator. The boot image builder
enforces the bootloader's 8,704-byte kernel limit. LLVM's Clang, LLD, and
objcopy compile and link the C++ source.

## Run

With Oracle VirtualBox installed, run:

```powershell
.\scripts\run-vm.ps1
```

The script creates and launches a 64 MB legacy-BIOS test VM, attaches
`dist\LumenOS.iso` as a CD, and disables networking. Alternatively, attach
the ISO as a CD/DVD in any VM configured for legacy BIOS or CSM boot. UEFI-only
boot is not supported in this first version. The shell supports `help`,
`about`, `version`, `memory`, `clear`, `reboot`, `halt`, and the example C++
command `hello`.

This is an educational bootable OS prototype, not a general-purpose desktop
operating system. It relies on legacy BIOS services and does not include
protected mode, drivers, a filesystem, networking, or a graphical desktop.
