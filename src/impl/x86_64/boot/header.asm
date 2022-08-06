section .multiboot_header
header_start:
    ; multiboot2 id integer
    dd 0xe85250d6
    ; architecture - i386 protected
    dd 0
    ; header length
    dd header_end - header_start
    ; checksum
    dd 0x100000000 - ( 0xe85250d6 + 0 + (header_start - header_end))

    ; end tag
    dw 0
    dw 0
    dd 8
header_end: