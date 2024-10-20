;replaces PLY_SE_SENDPSGREGISTERS of the CPC version
;for the PCW with dktronics AY

ld b,a
read"Dmn-Sound-VolEfx.asm"

;    ld b,a
    ld a,7
    out (PCW_AY_INDEX),a
    ld a,b
    out (PCW_AY_WRITE),a
PLY_SE_PSGREG01_INSTR ld hl,0
    xor a
    out (PCW_AY_INDEX),a
    ld a,l
    out (PCW_AY_WRITE),a
    ld a,1
    out (PCW_AY_INDEX),a
    ld a,h
    out (PCW_AY_WRITE),a
PLY_SE_PSGREG23_INSTR ld hl,0
    ld a,2
    out (PCW_AY_INDEX),a
    ld a,l
    out (PCW_AY_WRITE),a
    ld a,3
    out (PCW_AY_INDEX),a
    ld a,h
    out (PCW_AY_WRITE),a
PLY_SE_PSGREG45_INSTR ld hl,0
    ld a,4
    out (PCW_AY_INDEX),a
    ld a,l
    out (PCW_AY_WRITE),a
    ld a,5
    out (PCW_AY_INDEX),a
    ld a,h
    out (PCW_AY_WRITE),a
PLY_SE_PSGREG6 equ $+1
PLY_SE_PSGREG8 equ $+2
PLY_SE_PSGREG6_8_INSTR ld hl,0
    ld a,6
    out (PCW_AY_INDEX),a
    ld a,l
    out (PCW_AY_WRITE),a
    ld a,8
    out (PCW_AY_INDEX),a
    ld a,h
    out (PCW_AY_WRITE),a
PLY_SE_PSGREG9 equ $+1
PLY_SE_PSGREG10 equ $+2
PLY_SE_PSGREG9_10_INSTR ld hl,0
    ld a,9
    out (PCW_AY_INDEX),a
    ld a,l
    out (PCW_AY_WRITE),a
    ld a,10
    out (PCW_AY_INDEX),a
    ld a,h
    out (PCW_AY_WRITE),a
PLY_SE_PSGHARDWAREPERIOD_INSTR ld hl,0
    ld a,11
    out (PCW_AY_INDEX),a
    ld a,l
    out (PCW_AY_WRITE),a
    ld a,12
    out (PCW_AY_INDEX),a
    ld a,h
    out (PCW_AY_WRITE),a
PLY_SE_PSGREG13_OLDVALUE ld a,255
PLY_SE_RETRIG or 0
PLY_SE_PSGREG13_INSTR ld l,0
    cp l
    ret z
    ld a,13
    out (PCW_AY_INDEX),a
    ld a,l
    ld (PLY_SE_PSGREG13_OLDVALUE+1),a
    out (PCW_AY_WRITE),a
    xor a
    ld (PLY_SE_RETRIG+1),a
    ret 
