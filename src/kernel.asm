bits 16

global start
global kernel_print
extern user_command
extern __bss_start
extern __bss_size

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x7c00
    mov edi, __bss_start
    mov ecx, __bss_size
    xor eax, eax
    a32 rep stosb
    sti

    mov si, welcome
    call print

prompt:
    mov si, prompt_text
    call print
    xor cx, cx

read_key:
    xor ah, ah
    int 0x16
    cmp al, 13
    je submit
    cmp al, 8
    je backspace
    cmp al, 0x20
    jb read_key
    cmp cx, 63
    jae read_key
    mov bx, cx
    mov [buffer+bx], al
    inc cx
    push cx
    mov ah, 0x0e
    xor bx, bx
    int 0x10
    pop cx
    jmp read_key

backspace:
    test cx, cx
    jz read_key
    dec cx
    mov si, erase_character
    call print
    jmp read_key

submit:
    mov bx, cx
    mov byte [buffer+bx], 0
    mov si, newline
    call print

    mov si, buffer
    mov di, command_help
    call compare
    je show_help

    mov si, buffer
    mov di, command_about
    call compare
    je show_about

    mov si, buffer
    mov di, command_version
    call compare
    je show_version

    mov si, buffer
    mov di, command_memory
    call compare
    je show_memory

    mov si, buffer
    mov di, command_clear
    call compare
    je clear_screen

    mov si, buffer
    mov di, command_reboot
    call compare
    je reboot

    mov si, buffer
    mov di, command_halt
    call compare
    je halt_system

    cmp byte [buffer], 0
    je prompt
    push dword buffer
    call dword user_command
    add esp, 4
    jmp prompt

show_help:
    mov si, help_text
    call print
    jmp prompt

show_about:
    mov si, about_text
    call print
    jmp prompt

show_version:
    mov si, version_text
    call print
    jmp prompt

show_memory:
    int 0x12
    call print_u16
    mov si, memory_suffix
    call print
    jmp prompt

clear_screen:
    mov ax, 0x0600
    mov bh, 0x07
    xor cx, cx
    mov dx, 0x184f
    int 0x10
    mov ah, 0x02
    xor bh, bh
    xor dx, dx
    int 0x10
    mov si, welcome
    call print
    jmp prompt

reboot:
    int 0x19
    jmp $

halt_system:
    mov si, halt_text
    call print
    cli
.halt:
    hlt
    jmp .halt

compare:
    lodsb
    scasb
    jne .done
    test al, al
    jnz compare
.done:
    ret

kernel_print:
    pushad
    mov esi, [esp + 36]
    call print
    popad
    o32 ret

print:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0e
    xor bx, bx
    int 0x10
    jmp print
.done:
    ret

print_u16:
    xor cx, cx
    mov bx, 10
.divide:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .divide
.digit:
    pop ax
    add al, '0'
    push cx
    mov ah, 0x0e
    xor bx, bx
    int 0x10
    pop cx
    loop .digit
    ret

welcome db 13, 10, "========================================", 13, 10
        db "  L U M E N O S   0.1", 13, 10
        db "  Tiny BIOS-based educational operating system", 13, 10
        db "  Type 'help' to see available commands.", 13, 10
        db "========================================", 13, 10, 0
prompt_text db "lumen> ", 0
help_text db "Commands: help, about, version, memory, clear, reboot, halt, hello", 13, 10, 0
about_text db "LumenOS is a tiny standalone x86 real-mode OS demo.", 13, 10
           db "It boots from a BIOS El Torito CD and uses BIOS video/keyboard services.", 13, 10, 0
version_text db "LumenOS 0.1 (16-bit x86 real mode)", 13, 10, 0
memory_suffix db " KB conventional memory reported by BIOS.", 13, 10, 0
halt_text db "System halted. Reset the virtual machine to boot again.", 13, 10, 0
newline db 13, 10, 0
erase_character db 8, " ", 8, 0
command_help db "help", 0
command_about db "about", 0
command_version db "version", 0
command_memory db "memory", 0
command_clear db "clear", 0
command_reboot db "reboot", 0
command_halt db "halt", 0
buffer times 64 db 0
