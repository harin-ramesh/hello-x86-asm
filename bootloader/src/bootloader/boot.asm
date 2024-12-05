ORG 0x7C00
BITS 16

jmp short main
nop

bdb_oem: DB "MSWIN4.1"
bdb_byter_per_sector: DW 512
bdb_sectors_per_cluster: DB 1
bdb_reserved_sectors: DW 1
dbd_fat_count: DB 2
dbd_dir_entries_count: DW 0E0h
dbd_total_sectors: DW 2880
dbd_media_descriptor_types: DB 0F0h
dbd_sectors_per_fat: DW 9
dbd_sectors_per_track: DW 18
dbd_heads: DW 2
dbd_hidden_sectors: DD 0
dbd_large_sector_count: DD 0

ebr_drive_number: DB 0
                  DB 0
ebr_signature: DB 29h
ebr_volume_id: DB 12h,34h,56h,78h
ebr_volume_label: DB "MyOS       "
ebr_system_id: DB "FAT12   "

main:
    mov ax, 0
    mov dx, ax 
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    mov si, os_boot_message
    call print

    mov [ebr_drive_number] dl
    mov ax, 1
    mov cl, 1
    mov bx, 0x7E00
    call disk_read

    HLT

halt:
    JMP halt

; Input: lba index in ax
; Output: 
; cx [0-5] - Sector number
; cx [6-15] - Sector number
; dx - head
lba_chs:
    push ax
    push dx

    xor dx, dx
    div word [bdb_sectors_per_track]
    inc dx
    mov dx, cx

    xor dx, dx
    div word [bdb_heads]

    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah
    
    pop ax
    mov dl, al
    pop ax

    ret
    

disk_read:
    push ax
    push bx
    push cx
    push dx
    push di
    
    call lba_chs
    mov ah, 02h
    mov di, 3

retry:
    stc
    int 13h
    jnc done_read
    call disk_reset
    dec di
    test di, di
    jnz retry

failed_disk_read:
    mov si, read_failure
    call print
    hlt
    jmp halt

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc failed_disk_read
    popa
    ret

done_read:
    pop ax
    pop bx
    pop cx
    pop dx
    pop di

    ret


print:
    push si
    push ax
    push bx

print_loop:
    lodsb     ; load first byte pointed by si
    or al, al ; check whether we reached string terminator or not
    jz done_print

    mov ah, 0x0E
    mov bx, 0 ; page number
    int 0x10
    jmp print_loop

done_print:
    pop si
    pop ax
    pop bx
    ret

os_boot_message DB 'OS booted successfully', 0x0D, 0x0A, 0
read_failure DB 'Failed to read disk', 0x0D, 0x0A, 0

TIMES 510-($-$$) DB 0
DW 0AA55h
