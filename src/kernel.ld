OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)
ENTRY(start)

SECTIONS
{
    . = 0x7e00;
    .text : { *(.text.start) *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : {
        __bss_start = .;
        *(.bss*) *(COMMON)
    }
    __bss_size = SIZEOF(.bss);
    /DISCARD/ : { *(.comment*) *(.eh_frame*) *(.note*) }
}
