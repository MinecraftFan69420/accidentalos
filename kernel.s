; AccidentalOS - kernel
; made by me with a __little__ help from Microsoft Copilot
; so don't think Copilot created the whole thing
; just helped me with fixing bugs and adding a few code snippets
;
; it's called AccidentalOS cuz it started as an 
; 8086 VGA hello world i wrote cuz i was bored
;
; showed it to MS Copilot and then I somehow got motivated to add more
; and also realized this 8086 VGA hello world was technically an OS
;
; so yeah we accidentally created an operating system - hope u like it
; and if you do then star it

; usage instructions: see boot.s line 15
; i know the command might be long but its probably ok

BITS 16                          ; 16-bit real mode
ORG 0x0000                       ; loaded at 0x0000 by boot sector

stage2_start:
    CLI
    CLD

    ; flat view
    MOV ax, cs
    MOV ds, ax
    MOV es, ax

    MOV ax, STACK_SEG ; stack at 0x90000
    MOV ss, ax
    MOV sp, 0xFFFF ; top at 0x9FFFF

    MOV ax, ss
    CMP ax, STACK_SEG
    JNE error

    STI
    MOV si, kernel_boot_msg
.L2:
    LODSB ; MOV al, [ds:si], INC si
    TEST al, al                 
    JZ .L4

    CMP al, NEWLINE             ; newline
    JE .L3

    CALL print_char
    JMP .L2
.L3: ; newline
    CALL newline
    JMP .L2 ; continue on with the print loop
.L4:
    CALL newline
    JMP terminal_loop

terminal_loop:
    MOV BYTE [input_len], 0

    ; print prompt "> "
    MOV al, '>'
    CALL print_char
    MOV al, ' '
    CALL print_char
.L5:
    XOR ah, ah
    INT 0x16            ; wait for key
    ; AL = ASCII, AH = scan code

    ; if key input fails then error
    TEST al, al
    JNZ .L11
    TEST ah, ah
    JNZ .L11
    CALL error
.L11:
    ; enter
    CMP al, CR
    JE .L6

    ; backspace
    CMP al, BACKSPACE        ; Backspace?
    JE .L7
    CMP ah, 0x0E
    JE .L7

    ; fail on other unsupported characters
    CMP al, 0x20
    JB .L5

    ; normal
    XOR bh, bh
    MOV bl, [input_len]
    CMP bl, 16
    JAE .L5

    MOV BYTE [input_buffer + bx], al
    INC bl
    MOV [input_len], bl

    ; echo character
    CALL print_char ; al already set
    JMP .L5

.L6:
    MOV bl, [input_len]
    XOR bh, bh
    MOV BYTE [input_buffer + bx], 0

    CALL newline
    JMP terminal_loop
.L7:
    MOV bl, [input_len]
    CMP bl, 0
    JE .L5 ; nothing to delete

    MOV ax, di
    SUB ax, 4 ; subtract VGA memory pointer to go back a character
    JB error ; model/view mismatch
    JBE .L5

    DEC bl
    MOV BYTE [input_len], bl
    XOR bh, bh
    MOV BYTE [input_buffer + bx], 0
    CALL backspace
    JMP .L5

shutdown: ; done - shutdown
    CLI                         ; Clear interrupts so it stays paused
    HLT                         ; Halt CPU
    JMP $

; HELPERS

print_char: ; print a character in al
    PUSH es
    PUSH ax

    MOV ax, VGA_MEM_START
    MOV es, ax

    POP ax

    MOV ah, 0x0F
    MOV WORD [es:di], ax
    ADD di, 2

    POP es    

    PUSH ax
    ; update cursor
    MOV ax, di
    SHR ax, 1          ; byte offset -> character index
    ; div by 80
    XOR dx, dx
    MOV bx, 80
    DIV bx             ; AX = row, DX = column

    MOV ah, 0x02       ; request: set cursor
    MOV bh, 0
    MOV dh, al         ; row
    MOV dl, dl         ; column (DL = DX low byte)
    INT 0x10
    POP ax
    RET

newline: ; move to a new line (warning: destroy ax)
    MOV ax, di
    XOR dx, dx
    MOV cx, 160
    DIV cx              ; DX = column, AX = row

    SUB di, dx
    ADD di, 160

    CMP di, 160 * 25 ; past the screen?
    JAE .L13

    RET
.L13: ; if last line
    CALL scroll_up
    RET

carriage_return: ; move to the start of the line (warning: destroy ax)
    MOV ax, di
    XOR dx, dx
    MOV cx, 160
    DIV cx              ; DX = column, AX = row

    SUB di, dx

    RET

backspace:
    ; Check if we're at the start of video memory
    CMP di, 2
    JBE .L8     ; can't backspace past start

    PUSH es

    MOV ax, VGA_MEM_START
    MOV es, ax

    SUB di, 2
    MOV WORD [es:di], 0x0F20

    MOV ax, di
    SHR ax, 1          ; byte offset -> character index
    XOR dx, dx
    MOV bx, 80
    DIV bx             ; AX = row, DX = column

    MOV ah, 0x02       ; request: update cursor
    XOR bh, bh
    MOV dh, al         ; row
    ; dl contains the column
    INT 0x10
.L8:
    POP es
    RET

error:
    MOV si, error_msg
.L9:
    LODSB ; get next char
    TEST al, al ; finished?
    JZ .L10 ; crash

    CALL print_char
    JMP .L9
.L10: ; WOOHOOOOO 10 LOCAL LABELS!!
    CLI
.L12:
    HLT
    JMP .L12
scroll_up: ; scroll up when cursor reaches bottom line
    PUSH si

    MOV si, 160 ; line 2
    XOR di, di
    MOV cx, 80 * 24
    REP MOVSW

    MOV ax, 0x0F20 ; ' ' with white on black
    MOV cx, 80 ; do this 80 times
    REP STOSW

    MOV di, 160 * 24 ; start of last line

    POP si

    RET
strcmp: ; compare strings. inputs: si = ptr to string 1, di = ptr to string 2 in data.s
; return: ax = 1 if equal, ax = 0 if not
.L14:
    MOV al, [si]
    MOV bl, [di]

    CMP al, bl
    JNE .L15

    CMP al, 0
    JE .L16

    INC si
    INC di
    JMP .L14
.L15:
    MOV ax, 0
    RET
.L16:
    MOV ax, 1
    RET

kernel_boot_msg: db "Kernel load done - ready.", 10, 0
; test string with newline and carriage return
error_msg: db "Error, shutdown.", 0
test_file_name: db "test.bin", 0
input_buffer: times 17 db 0 ; 16 chars + end null
input_len: db 0

; constants
BACKSPACE: equ 0x08
NEWLINE: equ 0x0A
CR: equ 0x0D
STACK_SEG: equ 0x9000
VGA_MEM_START: equ 0xB800