section .multiboot_header
header_start:
    ; multiboot2 id number
    dd 0xe85250d6
    ; architecture - i386 protected
    dd 0
    ; header length
    dd header_end - header_start
    ; checksum
    dd 0x100000000 - ( 0xe85250d6 + 0 + (header_start - header_end))

    ; end tag
    dw 0 ; type
    dw 0 ; flags
    dd 8 ; size
header_end: