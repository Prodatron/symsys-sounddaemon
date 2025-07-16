;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@                 S y m b O S   -   S o u n d - D a e m o n                  @
;@                                                                            @
;@             (c) 2023-2025 by Prodatron / SymbiosiS (Jörn Mika)             @
;@                      device-specific initializations                       @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

dvcini

if PLATFORM_TYPE=PLATFORM_SVM
        ld a,D_PSGCCPC+D_PSGSABC
        out (P_PSG1CTRL),a
        ld a,D_PSGOFF
        out (P_PSG2CTRL),a
        ret
elseif PLATFORM_TYPE=PLATFORM_ISA

port_io_bank0   equ #F0
port_io_bank1   equ #F1
port_io_bank2   equ #F2
port_io_bank3   equ #F3

v_sound         equ #64
CH_BASE         equ #0500

if 0
        LD A,#21    ; channel number

        LD BC,#0C00 ; address of it's 1kB buffer   7-6-2025 now at 0c00 
        call psg_ch_init
        ; 28-5-2025 add more channels
        LD A,#29    ; channel number

        LD BC,#1000 ; address of it's 1kB buffer   7-6-2025 buffer now at 1000 

        call psg_ch_init 
        LD A,#31    ; channel number
        LD BC,#1400 ; address of it's 1kB buffer 

        call psg_ch_init
        LD A,#39    ; channel number (noise channel)
        LD BC,#1800 ; address of it's 1kB buffer 

        call psg_ch_init 


        ; now clear buffer. 
        LD HL,#0C00
        LD DE,#0C01
        LD BC,#1010 ; clear 4 buffers of 1kB, and the overflow area

        xor a
psg_clr1
        out (port_io_bank1),a  
        inc hl
        bit 5,h ; check if #2000 was reached
        jr z,psg_clr1

        ; put the v_sound instruction in the frame, at 3 positions
        ld a,v_sound
        ld hl,#049c ; decimal 412 from start
        out (port_io_bank1),a 
        ld l,#D1  ; #04D1, dec 465 from start
        out (port_io_bank1),a 
        ld l,#F4  ; #04F4, dec 500 from start
        out (port_io_bank1),a  

        ; init volume table, 1-6-2025
        ld hl,#500 ; destination
        ld de,vol_table
        ld b,16
        vol_loop: 
        ld a,(de)
        out (port_io_bank2),a   ; place in volume table
        inc hl
        inc de
        djnz vol_loop
        
        xor A
        out (#40),A  ; activate the PSG !!!
         
        ret

vol_table
        db 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15 ; for now, linear table


; initialize a channel. 
; inputs channel number in ACC. For ch 1, this is #21
; input -> buffer area in BC. For ch 1 this is #1000

psg_ch_init:
 
        and #FE  ; make it #20
        ld hl,CH_BASE
        ld l,A  
        ; base addr of channel is in HL
        inc hl
        inc hl  ; now point to CH_BUF #22
        
        ld a,b
        out (port_io_bank0),a  ; set msb of buffer area, ch_buf_msb
        
        inc hl
        out (port_io_bank2),a  ; ch_buf_pch  should point to buffer
        ld a,#20
        out (port_io_bank1),a  ; 1-6-2025 set tone=1, vol=0 in volume word
        dec hl
        ld a,4
        out (port_io_bank2),a  ; ch_buf_pcl  added 25-5-2025
        
        ld a,l ; #22
        add a,2 ; #24 positive wave data area
        out (port_io_bank1),a ; write to ch_buf_pol
        
        inc hl
        inc hl
 
; now point to positive wave data #24

        ld a,#04
        out (port_io_bank1),a ; ch_volume
        
        ld a,l ; #24
        add a,2 ; #26 negative wave data area
        out (port_io_bank2),a ; ch_nextdpl
        
        ld a,#50  ; arbitrary ? No, must point to a psg_sq_x instruction
        out (port_io_bank0),a  ; period lsb
        
        inc hl
        xor a  ; msb init to 0. required for noise ch
        out (port_io_bank0),a  ; period msb 
        out (port_io_bank2),a  ; for noise, count_hi zero 
        inc hl
        
        ; now point to negative wave data #26
        
        ld a,#FC
        out (port_io_bank1),a ; ch_volume (negative number)
        
        ld a,l ; #26
        sub 2 ; #24 negative wave data area
        out (port_io_bank2),a ; ch_nextdpl
        
        ld a,#50  ; arbitrary ? No, must point to a psg_sq_x instruction
        out (port_io_bank0),a  ; period lsb
        
        inc hl
        ; ld a,#04  ; arbitrary
        xor a  ; msb init to 0. required for noise ch 
        out (port_io_bank0),a  ; period msb 
        out (port_io_bank2),a  ; for noise, count_hi zero 

        ret ; done channel init.

endif



psg_init: 
 LD A,#21    ; channel number
 ;LD BC,#1000 ; address of it's 1kB buffer  24-5-2025 buffer now at 1000
 LD BC,#0C00 ; address of it's 1kB buffer   7-6-2025 now at 0c00 
 call psg_ch_init
 ; 28-5-2025 add more channels
 LD A,#29    ; channel number
 ;LD BC,#0C00 ; address of it's 1kB buffer  24-5-2025 buffer now at 1000
 LD BC,#1000 ; address of it's 1kB buffer   7-6-2025 buffer now at 1000 
 ;LD BC,#1400 ; address of it's 1kB buffer  7-6-2025 buffer now at 1400 
 call psg_ch_init 
 LD A,#31    ; channel number
 LD BC,#1400 ; address of it's 1kB buffer 
 ;LD BC,#1800 ; address of it's 1kB buffer  
 call psg_ch_init
 LD A,#39    ; channel number (noise channel)
 LD BC,#1800 ; address of it's 1kB buffer 
 ;LD BC,#1C00 ; address of it's 1kB buffer  
 call psg_ch_init 
 
 ; for testing the problem source, also define channels at higher addresses:
 if 0
 LD A,#A1    ; channel number
 LD BC,#1000 ; address of it's 1kB buffer  24-5-2025 buffer now at 1000
 call psg_ch_init
 ; 28-5-2025 add more channels
 LD A,#A9    ; channel number
 LD BC,#0C00 ; address of it's 1kB buffer  24-5-2025 buffer now at 1000
 call psg_ch_init 
 LD A,#B1    ; channel number
 LD BC,#1400 ; address of it's 1kB buffer  24-5-2025 buffer now at 1000
 call psg_ch_init
 LD A,#B9    ; channel number (noise channel)
 LD BC,#1800 ; address of it's 1kB buffer  24-5-2025 buffer now at 1000
 call psg_ch_init  
 endif
 
 
 ; now clear buffer. 
 LD HL,#0C00
 LD DE,#0C01
 LD BC,#1010 ; clear 4 buffers of 1kB, and the overflow area
 ;LD (HL),0 
 ;LDIR  ; clear the sample buffer of this channel. But not in bank1 !
 xor a
psg_clr1: 
 out (port_io_bank1),a  
 inc hl
 bit 5,h ; check if #2000 was reached
 jr z,psg_clr1
 
 ;ret; test 23-5 don't start generator
 
 ; put the v_sound instruction in the frame, at 3 positions
 ld a,v_sound
 ld hl,#049c ; decimal 412 from start
 out (port_io_bank1),a 
 ld l,#D1  ; #04D1, dec 465 from start
 out (port_io_bank1),a 
 ld l,#F4  ; #04F4, dec 500 from start
 out (port_io_bank1),a  

; init volume table, 1-6-2025
 ld hl,#500 ; destination
 ld de,vol_table
 ld b,16
vol_loop: 
 ld a,(de)
 out (port_io_bank2),a   ; place in volume table
 inc hl
 inc de
 djnz vol_loop

 xor A
 out (#40),A  ; activate the PSG !!!
 
 ret

half equ 128

vol_table:
 ; db 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15 ; old linear table
 db 0
 db half
 db half
 db 1
 db 1 + half
 db 2
 db 3
 db 4
 db 5 + half
 db 7
 db 9
 db 11 + half
 db 14 + half
 db 18 + half
 db 24
 db 31


 ; end 
 


; initialize a channel. 
; inputs channel number in ACC. For ch 1, this is #21
; input  buffer area in BC. For ch 1 this is #1000

psg_ch_init:
 
 and #FE  ; make it #20
 ld hl,CH_BASE
 ld l,A  
 ; base addr of channel is in HL
 inc hl
 inc hl  ; now point to CH_BUF #22

 ld a,b
 out (port_io_bank0),a  ; set msb of buffer area, ch_buf_msb
 
 inc hl
 out (port_io_bank2),a  ; ch_buf_pch  should point to buffer
 ld a,#20
 out (port_io_bank1),a  ; 1-6-2025 set tone=1, vol=0 in volume word
 dec hl
 ld a,4
 out (port_io_bank2),a  ; ch_buf_pcl  added 25-5-2025
 
 ld a,l ; #22
 add a,2 ; #24 positive wave data area
 out (port_io_bank1),a ; write to ch_buf_pol

 inc hl
 inc hl
 
; now point to positive wave data #24

 ld a,#04
 out (port_io_bank1),a ; ch_volume

 ld a,l ; #24
 add a,2 ; #26 negative wave data area
 out (port_io_bank2),a ; ch_nextdpl

 ld a,#50  ; arbitrary ? No, must point to a psg_sq_x instruction
 out (port_io_bank0),a  ; period lsb

 inc hl
 xor a  ; msb init to 0. required for noise ch
 out (port_io_bank0),a  ; period msb 
 out (port_io_bank2),a  ; for noise, count_hi zero 
 inc hl

 ; now point to negative wave data #26

 ld a,#FC
 out (port_io_bank1),a ; ch_volume (negative number)

 ld a,l ; #26
 sub 2 ; #24 negative wave data area
 out (port_io_bank2),a ; ch_nextdpl

 ld a,#50  ; arbitrary ? No, must point to a psg_sq_x instruction
 out (port_io_bank0),a  ; period lsb

 inc hl
 ; ld a,#04  ; arbitrary
 xor a  ; msb init to 0. required for noise ch 
 out (port_io_bank0),a  ; period msb 
 out (port_io_bank2),a  ; for noise, count_hi zero 

 ret ; done channel init.


else
        ret
endif
