ORG 0x7C00
BITS 16

jmp short main
nop

bdb_oem: DB "MSWIN4.1"
bdb_bytes_per_sector: DW 512
bdb_sectors_per_cluster: DB 1
bdb_reserved_sectors: DW 1
bdb_fat_count: DB 2
bdb_dir_entries_count: DW 0E0h
bdb_total_sectors: DW 2880
bdb_media_descriptor_types: DB 0F0h
bdb_sectors_per_fat: DW 9
bdb_sectors_per_track: DW 18
bdb_heads: DW 2
bdb_hidden_sectors: DD 0
bdb_large_sector_count: DD 0

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

    mov [ebr_drive_number], dl
    mov ax, 1
    mov cl, 1
    mov bx, 0x7E00
    call disk_read

    mov si, os_boot_message
    call print
    
    ; 4 Segments in FAT 12
    ; Reserved segement - 1 segment
    ; FAT - fat_count * sectors_per_fat sector, 2*9 = 18 sectors
    ; Root dir - 32 bytes each entry
    ; Data

    ; LBA of root dir calculation
    mov ax, [bdb_sectors_per_fat]
    mov bx, [bdb_fat_count]
    xor bh, bh
    mul bx
    add ax, [bdb_reserved_sectors] ; LBA of root dir
    push ax 

    mov ax, [bdb_dir_entries_count]
    shl ax, 5 ; ax *= 32
    xor dx, dx
    div word [bdb_bytes_per_sector]

    test dx, dx
    jz root_dir_after
    inc ax

root_dir_after:
    mov cl, al
    pop ax
    mov dl, [ebr_drive_number]
    mov bx, buffer
    call disk_read

    xor bx, bx
    mov di, buffer

search_kernal:
    mov si, file_kernal_bin 
    mov cx, 11
    push di
    repe cmpsb 
    pop di
    je kernal_found

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl search_kernal

    jmp kernal_not_found

kernal_not_found:
    mov si, read_failure 
    call print
    hlt
    jmp halt

kernal_found:
    mov ax, [di+26]
    mov [kernal_cluster], ax
    
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    mov bx, kernal_load_segment
    mov es, bx
    mov bx, kernal_load_offset

load_kernal:
    mov ax, [kernal_cluster]
    add ax, 31
    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read
    add bx, [bdb_bytes_per_sector]

    mov ax, [kernal_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx

    mov si, buffer
    add si, ax
    mov ax, [ds:si]

    or dx, dx
    jz even

odd:
    shr ax, 4
    jmp next_cluster_after

even:
    and ax, 0x0FFF

next_cluster_after:
    cmp ax, 0x0FF8
    jae read_finish

    mov [kernal_cluster], ax
    jmp load_kernal

read_finish:
    mov dl, [ebr_drive_number]
    mov ax, kernal_load_segment
    mov ds, ax
    mov es, ax
    
    jmp kernal_load_segment:kernal_load_offset
    hlt 
halt:
    jmp halt

; Input: lba index in ax
; Output: 
; cx [0-5] - Sector number
; cx [6-15] - Sector number
; dx - head
lba_to_chs:
    push ax
    push dx

    xor dx, dx
    div word [bdb_sectors_per_track]
    inc dx
    mov cx, dx

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
    
    call lba_to_chs
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
    mov si, disk_read_failure
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

os_boot_message: DB 'Loading....', 0x0D, 0x0A, 0
disk_read_failure: DB 'Failed to read disk', 0x0D, 0x0A, 0
file_kernal_bin: DB 'KERNAL  BIN'
read_failure: DB 'Kernal not found', 0x0D, 0x0A, 0
kernal_cluster: DW 0

kernal_load_segment: EQU 0x2000
kernal_load_offset: EQU 0

TIMES 510-($-$$) DB 0
DW 0AA55h

buffer:
