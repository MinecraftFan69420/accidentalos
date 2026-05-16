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

stage2_start: ; entry point for stage 2, jumped to by the boot
    CLI
    CLD

    ; flat view
    MOV ax, cs
    MOV ds, ax
    MOV es, ax

    ; stack setup
    MOV ax, STACK_SEG ; stack at 0x90000
    MOV ss, ax
    MOV sp, 0xFFFF ; top at 0x9FFFF

    MOV ax, ss
    CMP ax, STACK_SEG
    JNE error

    STI
    ; set si pointer to the boot message
    MOV si, kernel_boot_msg
.L2: ; print before moving on to the terminal
    LODSB ; load a byte from the message (pointed to by si) into al, then increment si
    TEST al, al ; check if it's null
    JZ .L4

    CMP al, NEWLINE             ; newline
    JE .L3

    CALL print_char
    JMP .L2
.L3: ; newline
    CALL newline
    JMP .L2 ; continue on with the print loop
.L4: ; null terminator, move on to terminal
    CALL newline
    JMP terminal_loop

terminal_loop: ; main terminal loop
    MOV BYTE [input_len], 0 ; reset input length

    ; print prompt "> "
    MOV al, '>'
    CALL print_char
    MOV al, ' '
    CALL print_char
.L5: ; keyboard input loop
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
    ; enter key
    CMP al, CR
    JE .L6

    ; backspace
    CMP al, BACKSPACE        ; Backspace?
    JE .L7
    CMP ah, 0x0E
    JE .L7

    ; fallback on other control chars - ignore
    CMP al, 0x20
    JB .L5

    ; compare input length to 16 - if too long ignore
    XOR bh, bh
    MOV bl, [input_len]
    CMP bl, 16
    JAE .L5

    ; set the input buffer and increment length
    MOV BYTE [input_buffer + bx], al
    INC bl
    MOV [input_len], bl

    ; echo character
    CALL print_char ; al already set
    JMP .L5

.L6: ; input finished
    ; reset length and buffer
    MOV bl, [input_len]
    XOR bh, bh
    MOV BYTE [input_buffer + bx], 0

    ; command processing later

    ; restart the loop
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

    ; decrement input length
    DEC bl
    MOV BYTE [input_len], bl
    ; set null in buffer
    XOR bh, bh
    MOV BYTE [input_buffer + bx], 0
    CALL backspace
    JMP .L5

shutdown: ; done - shutdown
    CLI                         ; Clear interrupts so it stays paused
    HLT                         ; Halt CPU
    JMP $

; HELPERS

print_char: ; print a character
    ; inputs: al
    ; outputs: none
    ; clobber: none
    PUSH es
    PUSH ax

    ; set es to VGA memory
    MOV ax, VGA_MEM_START
    MOV es, ax

    POP ax

    ; write character to VGA mem with white on black
    MOV ah, 0x0F
    MOV WORD [es:di], ax
    ; increment cursor
    ADD di, 2

    ; set es back
    POP es    

    PUSH ax

    ; calculate row and column
    MOV ax, di
    SHR ax, 1          ; byte offset -> character index
    ; div by 80
    XOR dx, dx
    MOV bx, 80
    DIV bx             ; AX = row, DX = column

    ; update cursor
    MOV ah, 0x02       ; cursor update request
    MOV bh, 0
    MOV dh, al         ; row
    MOV dl, dl         ; column (DL = DX low byte)
    INT 0x10
    POP ax
    RET

newline: ; move to a new line
    ; input: none
    ; output: none
    ; clobber: ax, dx, cx, di

    ; calculate row and column
    MOV ax, di
    XOR dx, dx
    MOV cx, 160
    DIV cx              ; DX = column, AX = row

    ; set column to zero
    SUB di, dx
    ADD di, 160

    CMP di, 160 * 25 ; past the screen?
    JAE .L13

    RET
.L13: ; if last line
    CALL scroll_up
    RET

carriage_return: ; move to the start of the line
    ; input: none
    ; output: none
    ; clobber: ax, di

    ; calculate row/column
    MOV ax, di
    XOR dx, dx
    MOV cx, 160
    DIV cx              ; DX = column, AX = row

    SUB di, dx

    RET

backspace: ; move the cursor back
    ; inputs: none
    ; outputs: none
    ; clobbers: di

    ; check if we're at the start of video memory
    CMP di, 2
    JBE .L8     ; can't backspace past start

    PUSH es

    ; set es to memory
    MOV ax, VGA_MEM_START
    MOV es, ax

    ; write a space to the VGA buffer
    SUB di, 2
    MOV WORD [es:di], 0x0F20

    ; calculate row/column
    MOV ax, di
    SHR ax, 1          ; byte offset -> character index
    XOR dx, dx
    MOV bx, 80
    DIV bx             ; AX = row, DX = column
    ; update cursor
    MOV ah, 0x02       ; request: update cursor
    XOR bh, bh
    MOV dh, al         ; row
    ; dl contains the column
    INT 0x10
.L8:
    POP es
    RET

error: ; error
    ; input: none
    ; output: none
    ; clobbers: si
    MOV si, error_msg
.L9:
    LODSB ; get next char
    TEST al, al ; finished?
    JZ .L10 ; crash

    CALL print_char
    JMP .L9
.L10:
    CLI
.L12:
    HLT
    JMP .L12
scroll_up: ; scroll up when cursor reaches bottom line
    ; input: none
    ; output: none
    ; clobber: di

    ; preservation
    PUSH si
    PUSH ds
    PUSH es

    MOV ax, VGA_MEM_START
    MOV ds, ax
    MOV es, ax

    ; move lines 2-25 to 1-24
    MOV si, 160 ; line 2
    XOR di, di
    MOV cx, 80 * 24
    REP MOVSW

    ; clear last line
    MOV ax, 0x0F20 ; ' ' with white on black
    MOV cx, 80 ; do this 80 times
    REP STOSW

    ; move cursor to start of last line
    MOV di, 160 * 24 ; start of last line

    POP es
    POP ds
    POP si

    RET
strcmp: ; compare strings. 
    ; inputs: si = ptr to string 1, di = ptr to string 2 in data.s
    ; outputs: ax = 1 if equal, ax = 0 if not
    ; clobbers: si, di
.L14:
    ; set al & bl to characters @ si & di
    MOV al, [si]
    MOV bl, [di]

    ; check if equal
    CMP al, bl
    JNE .L15

    ; if finished, then al would be null
    CMP al, 0
    JE .L16

    ; increment si, di and try again
    INC si
    INC di
    JMP .L14
.L15: ; unequal
    ; set unequal result
    MOV ax, 0
    RET
.L16: ; equal
    ; set equal result
    MOV ax, 1
    RET

load_file: ; load file and store in the range of 0x80000-0x8FFFF
    ; inputs: si = ptr to filename
    ; outputs: ax = 0 if fail, ax = 1 if success
    ; clobbers: ax, bx, cx, dx, di

    PUSH es ; preserve es
    PUSH di
    PUSH si
    PUSH ds

    ; STEP 1: load the file table into kernel data segment (0x1000-0x7BFF)
    MOV ax, 0x0100
    MOV es, ax
    XOR bx, bx

    ; set up registers for INT 0x13
    MOV ah, 2 ; request: read sectors
    MOV al, 15 ; 15 sectors to read
    XOR dl, dl ; from the floppy
    ; load from sector 2 - C0H0S3 in CHS
    XOR ch, ch ; cylinder
    XOR dh, dh ; head
    MOV cl, 3 ; sector

    INT 0x13

    JC error ; if carry flag set, then error

    MOV cx, 240 ; 240 file entries ((15 * 512) / 32)
    XOR di, di ; di = offset in file table
.L17: 
    ; STEP 2: check if file exists
    ; compare filename to entry

    PUSH si
    PUSH di

    ; MOV si, si - si already points to filename, so no need to set
    ; MOV di, di - di contains offset of file table already
    
    CALL strcmp

    POP di
    POP si

    CMP ax, 1
    JE .L18 ; if strings equal load the file

    ADD di, 32 ; move to next file entry
    LOOP .L17
.L18: ; if file name & target are equal
    ; STEP 3: load file into memory

    MOV bx, di
    MOV ax, [bx + 21] ; starting sector
    ; get sector count (offset 23)
    MOV dl, BYTE [bx + 23] ; low byte only

    ; set destination buffer
    XOR bx, bx
    MOV cx, ax

    MOV ax, 0x8000 
    MOV es, ax

    ; prepare for INT 0x13
    MOV ah, 2 ; request: read sectors
    MOV al, [di + 0x17] ; offset of sectors to read is 23
    XOR dl, dl ; from the floppy

    ; TEMP: calculate CHS from offset 21 (an LBA value), will do later

    INT 0x13
    JC error

    MOV ax, 1
.L19: ; finished
    POP ds
    POP si
    POP di
    POP es
    RET

; data
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