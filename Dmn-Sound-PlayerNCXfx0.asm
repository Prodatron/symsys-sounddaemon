;replaces PLY_SE_SENDPSGREGISTERS of the CPC version
;for the NC using channel A and B for the first two AY channels (experimental)

ld b,a
read"Dmn-Sound-VolEfx.asm"

        ld a,b          ;A=mixer (bit0,1,2=tone off)
PLY_SE_PSGREG01_INSTR
        ld hl,0
        ld c,l
        ld b,h
        add hl,hl
        add hl,hl
        add hl,de
        ex de,hl        ;de=channel A
PLY_SE_PSGREG23_INSTR
        ld hl,0
        ld c,l
        ld b,h
        add hl,hl
        add hl,hl
        add hl,de       ;hl=channel B
        rl d:rra:rr d   ;switch channel A
        rl h:rra:rr h   ;switch channel B
PLY_SE_PSGREG8 equ $+1
        ld a,0
        and #f
        cp NC_VOL_MIN
        jr nc,PLY_SE_PSGVOLA
        set 7,d         ;switch A off, if volume too low
PLY_SE_PSGVOLA

PLY_SE_PSGREG9 equ $+1
PLY_SE_PSGREG10 equ $+2
PLY_SE_PSGREG9_10_INSTR
        ld bc,0
        ld a,c
        and #f
        cp NC_VOL_MIN
        jr nc,PLY_SE_PSGVOLB
        set 7,h         ;switch B off, if volume too low
PLY_SE_PSGVOLB

        ld a,e:out (NC_CHANNEL_A+0),a
        ld a,d:out (NC_CHANNEL_A+1),a
        ld a,l:out (NC_CHANNEL_B+0),a
        ld a,h:out (NC_CHANNEL_B+1),a
        ret 

PLY_SE_PSGREG45_INSTR  equ $-1
        dw 0
PLY_SE_PSGREG6
        db 0
PLY_SE_PSGHARDWAREPERIOD_INSTR equ $-1
        dw 0
PLY_SE_PSGREG13_INSTR equ $-1
        db 0
PLY_SE_RETRIG equ $-1
        db 0
PLY_SE_PSGREG13_OLDVALUE equ $-1
        db 0
