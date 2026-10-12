bits 16
org 0x7c00

    jmp 0x0000:start
    nop
start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti
    mov [boot_drive], dl

    mov si, loading
    call print

    xor ax, ax
    mov es, ax
    mov bx, 0x7e00
    mov ah, 0x02
    mov al, 17
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    jmp 0x0000:0x7e00

disk_error:
    mov si, error
    call print
    xor ah, ah
    int 0x16
    int 0x19

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

loading db "Starting LumenOS...", 13, 10, 0
error db "Disk read failed. Press a key to reboot.", 13, 10, 0
boot_drive db 0

times 510-($-$$) db 0
dw 0xaa55
