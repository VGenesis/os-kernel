global start
extern long_mode_start

section .text
bits 32

start:
    ; initialize stack pointer
    mov esp, stack_top

    ; check multiboot, extended processor info and x64 capabilities
    call check_multiboot
    call check_cpuid
    call check_long_mode

    ; implement paging
    call setup_page_tables
    call enable_paging

    lgdt [gdt64.pointer]
    jmp gdt64.code_segment:long_mode_start

    hlt

check_multiboot:
    cmp eax, 0x36d76289
    jne .no_multiboot
    ret
.no_multiboot:
    mov al, "M"
    jmp error

; Checks if cpu can run in 64-bit mode(nicknamed 'long' mode)
check_cpuid:
    pushfd              ; push flag data to stack
    pop eax             
    mov ecx, eax        ; copy eax to ecx to preserve original flag data 
    xor eax, 1 << 21    ; flip 'long' flag bit in eax
    push eax            
    popfd               ; try setting flag data register to long mode
    pop eax              
    push ecx            
    popfd               ; reset flag register to original
    cmp eax, ecx        ; check if the two flags are identical
    je .no_cpuid:  

    ret     

.no_cpuid:
    mov al, "C"
    jmp error;

check_long_mode:
    ; check if the cpuid supports extended processor info 
    mov eax, 0x80000000 
    cpuid               
    cmp eax, 0x80000001
    jb .no_long_mode

    ; check extended processor info to see if long mode is available
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29
    jz .no_long_mode

    ret

.no_long_mode:
    mov al, "L"
    jmp error

setup_page_tables:
    ; identity-map the first 1G of pages
    mov eax, page_table_l3
    or eax, 0b11        ; set present & writable flags
    mov [page_table_l4], eax

    mov eax, page_table_l2
    or eax, 0b11        ; set present & writable flags
    mov [page_table_l3], eax

    ; fill l1 page table entries
    mov ecx, 0          ; set counter
    
.loop:
    mov eax, 0x200000   ; 2MB
    mul ecx
    or eax, 0b10000011  ; set huge-page, present & writable flags
    mov [page_table_l2 + ecx * 8], eax

    inc ecx             ; increment counter
    cmp ecx, 512        ; check if the whole table is mapped
    jne .loop

    ret

enable_paging:
    ; pass page table location to cpu
    mov eax, page_table_l4
    mov cr3, eax

    ; enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; enable long mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; enable paging
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ret

error:
    mov dword [0xb8000], 0x4f524f45
    mov dword [0xb8004], 0x4f3a4f52
    mov dword [0xb8008], 0x4f204f20
    mov byte  [0xb800a], al
    hlt

section .bss
align 4096

; reserve page tables
page_table_l4:
    resb 4096
page_table_l3:
    resb 4096
page_table_l2:
    resb 4096

; reserve stack
stack_bottom:
    resb 4096 & 4
stack_top:

; global descriptor table
section .rodata
gdt64:
    dq 0            ; zero entry
.code_segment: equ $ - gdt64
    dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53)
.pointer:
    dw $ - gdt64 - 1
    dq gdt64