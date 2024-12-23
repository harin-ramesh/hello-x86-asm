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

    ; Disk read example
    ; mov dl, [ebr_drive_number]
    ; mov ax, 1 ; LBA
    ; mov bx, 0x7E00 ; address to which to read
    ; call disk_read

    mov si, os_loading_message
    call print
 
    ; 4 Segments in FAT 12
    ; Reserved segement - 1 segment
    ; FAT - fat_count * sectors_per_fat sector, 2*9 = 18 sectors
    ; Root dir - 32 bytes each entry
    ; Data

    ; LBA calculation of root dir
    mov ax, [bdb_sectors_per_fat]
    mov bx, [bdb_fat_count]
    xor bh, bh
    mul bx
    add ax, [bdb_reserved_sectors] ; LBA of root dir
    push ax 

    ; Calculating number of sector occupied by root dir
    mov ax, [bdb_dir_entries_count]
    shl ax, 5 ; ax *= 32
    xor dx, dx
    div word [bdb_bytes_per_sector]

    test dx, dx
    jz root_dir_after
    inc ax

root_dir_after:
    mov cl, al ; number of sectors to read
    pop ax ; LBA
    mov dl, [ebr_drive_number]
    mov bx, buffer
    call disk_read

    xor bx, bx
    mov di, buffer

search_kernal:
    mov si, file_kernal_bin 
    mov cx, 11 ; size of the file name
    push di
    repe cmpsb 
    pop di
    je kernal_found

    add di, 32 ; Moving to next entry in root dir
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
    mov ax, [di+26] ; to load starting starting cluster of kernal to ax
    mov [kernal_cluster], ax

    ; Loading FAT into memeory
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov dl, [ebr_drive_number]
    call disk_read

    mov bx, kernal_load_segment
    mov es, bx
    mov bx, kernal_load_offset

load_kernal:
    mov ax, [kernal_cluster]
    add ax, 31
    mov dl, [ebr_drive_number]
    call disk_read
    add bx, [bdb_bytes_per_sector]

    mov ax, [kernal_cluster]  ; Get current memory address (or cluster) in AX
    mov cx, 3                 ; Set multiplier to 3
    mul cx                    ; Multiply AX by 3
    mov cx, 2                 ; Set divisor to 2
    div cx                    ; Divide by 2

    mov si, buffer           ; Load the address of the FAT table (buffer) into SI.
    add si, ax               ; Add the computed offset to SI.
    mov ax, [ds:si]          ; Load the 16 bits starting from that offset into AX.

    or dx, dx                ; Test if DX (from the previous division) is zero.
    jz even                  ; If zero, it's an "even" cluster; otherwise, it's "odd."

odd:
    shr ax, 4            ; Right-shift AX by 4 to isolate the high 12 bits of the 16-bit entry.
    jmp next_cluster_after

even:
    and ax, 0x0FFF       ; Mask the low 12 bits to isolate the desired cluster number.

next_cluster_after:
    ; In FAT file systems (specifically FAT12), cluster numbers 0x0FF8, 0x0FF9, 0x0FFA, 0x0FFB,
    ; 0x0FFC, and 0x0FFD are reserved as end-of-chain markers (EOC). When the ax value reaches
    ; or exceeds 0x0FF8, it indicates that the current cluster is the last one in the chain,
    ; meaning there's no further cluster to read.
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
; cl [0-5] - Sector number
; ch [6-15] - Cylinder number
; dh - head
; dl - drive number
;
; track, t = LBA / sector_per_track
; sector, s = (LBA % sector_per_track)+1
; head, h = (t % number_of_heads)
; cylinder, c = (t / number_of_heads)
;
lba_to_chs:
    ; Preserve AX and DX registers
    push ax
    push dx

    ; Calculate the cylinder and store it in CX
    xor dx, dx
    div word [bdb_sectors_per_track]
    inc dx
    mov cx, dx  ; Store cylinder in CX

    ; Calculate head and store in DH, and store the sector in CL
    xor dx, dx
    div word [bdb_heads]
    mov dh, dl  ; Store head in DH
    mov ch, al  ; Store track in CH
    shl ah, 6    ; Shift AH to set the upper part of the sector
    or cl, ah    ; Combine AH into CL for the sector

    ; Restore AX and DX registers
    pop ax
    mov dl, al
    pop ax

    ret

disk_read:
    ; Preserve registers
    push ax
    push bx
    push cx
    push dx
    push di

    ; Call lba_to_chs to convert LBA to CHS
    call lba_to_chs

    ; Prepare for disk read operation
    mov ah, 02h   ; Disk read function
    mov di, 3     ; Retry counter (3 attempts)

retry:
    stc            ; Set carry flag to initiate disk read
    int 13h        ; Call BIOS interrupt for disk read
    jnc done_read  ; If no error, continue

    ; If error, reset the disk and retry
    call disk_reset
    dec di
    test di, di
    jnz retry      ; Retry if the counter is not zero

failed_disk_read:
    ; If all retries fail, print failure message and halt
    mov si, disk_read_failure
    call print
    hlt

disk_reset:
    ; Reset the disk
    pusha
    mov ah, 0      ; Reset disk
    stc
    int 13h        ; Call BIOS interrupt for reset
    jc failed_disk_read ; If error, jump to failure
    popa
    ret

done_read:
    ; Restore registers
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
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

os_loading_message: DB 'Loading....', 0x0D, 0x0A, 0
disk_read_failure: DB 'Failed to read disk', 0x0D, 0x0A, 0
file_kernal_bin: DB 'KERNAL  BIN'
read_failure: DB 'Kernal not found', 0x0D, 0x0A, 0
kernal_cluster: DW 0

kernal_load_segment: EQU 0x2000
kernal_load_offset: EQU 0

TIMES 510-($-$$) DB 0
DW 0AA55h

buffer:
