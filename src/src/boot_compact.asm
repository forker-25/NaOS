[org 0x7c00]
[bits 16]

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    
    mov ax, 1
    mov cx, 1
    mov bx, 0x8000
    call read_sector
    
    mov si, msg
    call print

main:
    mov si, prompt
    call print
    call input
    
    cmp byte [buf], 0
    je main
    
    cmp byte [buf], 't'
    jne .not_tab
    cmp byte [buf+1], 'a'
    jne .not_tab
    cmp byte [buf+2], 'b'
    jne .not_tab
    cmp byte [buf+3], 0
    je list_files
    
.not_tab:
    call find_file
    jmp main

list_files:
    mov si, files_msg
    call print
    
    mov si, 0x8000
    mov cx, 16
.loop:
    cmp byte [si], 0
    jz .next
    call print
    call newline
.next:
    add si, 32
    loop .loop
    jmp main

find_file:
    call search_file
    test ax, ax
    jnz .run
    
    call add_bin_ext
    call search_file
    test ax, ax
    jnz .run
    
    mov si, not_found_msg
    call print
    ret

.run:
    mov ax, [si + 12]
    mov cx, [si + 14]
    mov bx, 0x1000
    call read_sector
    
    mov ax, 0x0003
    int 0x10
    
    call 0x1000
    ret

search_file:
    mov si, 0x8000
    mov cx, 16
.loop:
    cmp byte [si], 0
    jz .not_found
    
    push si
    push cx
    mov di, buf
    call strcmp
    pop cx
    pop si
    
    test ax, ax
    jnz .found
    
    add si, 32
    loop .loop

.not_found:
    xor ax, ax
    ret

.found:
    mov ax, 1
    ret

add_bin_ext:
    mov si, buf
    call strlen
    cmp ax, 4
    jl .add
    
    mov di, buf
    add di, ax
    sub di, 4
    mov si, bin_ext
    call strcmp
    test ax, ax
    jnz .done
    
.add:
    mov si, buf
    call strlen
    mov di, buf
    add di, ax
    mov word [di], '.b'
    mov word [di+2], 'in'
    mov byte [di+4], 0
    
.done:
    ret

strlen:
    push si
    xor ax, ax
.loop:
    cmp byte [si], 0
    jz .done
    inc ax
    inc si
    jmp .loop
.done:
    pop si
    ret

strcmp:
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .ne
    test al, al
    jz .eq
    inc si
    inc di
    jmp .loop
.ne:
    xor ax, ax
    ret
.eq:
    mov ax, 1
    ret

read_sector:
    pusha
.loop:
    push ax
    push cx
    
    xor dx, dx
    div word [18]
    inc dx
    mov cl, dl
    xor dx, dx
    div word [2]
    mov dh, dl
    mov ch, al
    mov dl, 0x80
    
    mov ah, 2
    mov al, 1
    int 0x13
    jc error
    
    pop cx
    pop ax
    inc ax
    add bx, 512
    loop .loop
    
    popa
    ret

input:
    mov di, buf
    xor cx, cx
.loop:
    mov ah, 0
    int 0x16
    cmp al, 13
    je .done
    cmp al, 8
    je .bs
    cmp cx, 15
    jae .loop
    
    mov [di], al
    inc di
    inc cx
    mov ah, 0x0e
    int 0x10
    jmp .loop

.bs:
    test cx, cx
    jz .loop
    dec di
    dec cx
    mov byte [di], 0
    mov ah, 0x0e
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .loop

.done:
    mov byte [di], 0
    call newline
    ret

print:
    pusha
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp .loop
.done:
    popa
    ret

newline:
    mov ah, 0x0e
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    ret



error:
    mov si, error_msg
    call print
    cli
    hlt

msg:            db 'Welcome!', 13, 10, 0
prompt:         db '> ', 0
files_msg:      db 'Files:', 13, 10, 0
not_found_msg:  db 'Not found!', 13, 10, 0
error_msg:      db 'Error!', 13, 10, 0
bin_ext:        db '.bin', 0

buf:            times 20 db 0

times 510-($-$$) db 0
dw 0xaa55