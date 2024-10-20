;replaces PLY_AKG_SENDPSGREGISTERS of the CPC version
;for the NC using channel A and B for the first two AY channels (experimental)

NC_CHANNEL_A    equ #50
NC_CHANNEL_B    equ #52
NC_VOL_MIN      equ 5

ld (PLY_AKG_REST_A+1),a
read"Dmn-Sound-VolMus.asm"
PLY_AKG_REST_A
        ld a,0          ;A=mixer (bit0,1,2=tone off)
PLY_AKG_PSGREG01_INSTR
        ld hl,0
        ld c,l
        ld b,h
        add hl,hl
        add hl,hl
        add hl,bc
        ex de,hl        ;de=channel A
PLY_AKG_PSGREG23_INSTR
        ld hl,0
        ld c,l
        ld b,h
        add hl,hl
        add hl,hl
        add hl,bc       ;hl=channel B
        rl d:rra:rr d   ;switch channel A
        rl h:rra:rr h   ;switch channel B
PLY_AKG_PSGREG8 equ $+1
        ld a,0
        and #f
        cp NC_VOL_MIN
        jr nc,PLY_AKG_PSGVOLA
        set 7,d         ;switch A off, if volume too low
PLY_AKG_PSGVOLA

PLY_AKG_PSGREG9 equ $+1
PLY_AKG_PSGREG10 equ $+2
PLY_AKG_PSGREG9_10_INSTR
        ld bc,0
        ld a,c
        and #f
        cp NC_VOL_MIN
        jr nc,PLY_AKG_PSGVOLB
        set 7,h         ;switch B off, if volume too low
PLY_AKG_PSGVOLB

        ld a,e:out (NC_CHANNEL_A+0),a
        ld a,d:out (NC_CHANNEL_A+1),a
        ld a,l:out (NC_CHANNEL_B+0),a
        ld a,h:out (NC_CHANNEL_B+1),a
PLY_AKG_PSGREG13_END
PLY_AKG_SAVESP ld sp,0
        ret 

PLY_AKG_PSGREG45_INSTR  equ $-1
        dw 0
PLY_AKG_PSGREG6
        db 0
PLY_AKG_PSGHARDWAREPERIOD_INSTR equ $-1
        dw 0
PLY_AKG_PSGREG13_INSTR equ $-1
        db 0
PLY_AKG_RETRIG equ $-1
        db 0
PLY_AKG_PSGREG13_OLDVALUE equ $-1
        db 0
