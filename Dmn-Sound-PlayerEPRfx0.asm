;replaces PLY_SE_SENDPSGREGISTERS of the CPC version
;for the Enterprise with Dave emulation

        ld (PLY_SE_PSGREG7),a
read"Dmn-Sound-VolEfx.asm"
        ld hl,PLY_SE_PSGREG_ALL
        ld b,0
PLY_SE_SENDPSGREGISTERS_LOOP
        ld c,(hl)
        inc hl
        ld a,b
        call ayRegisterWrite
        inc b
        ld a,b
        cp 13
        jr nz,PLY_SE_SENDPSGREGISTERS_LOOP
PLY_SE_PSGREG13_OLDVALUE
        ld a,255
PLY_SE_RETRIG
        or 0
PLY_SE_PSGREG13_INSTR
        ld l,0
        cp l
        ret z
        ld a,l
        ld (PLY_SE_PSGREG13_OLDVALUE+1),a
        ld c,a
        ld a,13
        call ayRegisterWrite
        xor a
        ld (PLY_SE_RETRIG+1),a
        ret 

PLY_SE_PSGREG_ALL
PLY_SE_PSGREG01_INSTR           equ $-1:dw 0
PLY_SE_PSGREG23_INSTR           equ $-1:dw 0
PLY_SE_PSGREG45_INSTR           equ $-1:dw 0
PLY_SE_PSGREG6                          db 0
PLY_SE_PSGREG7                          db 0
PLY_SE_PSGREG8                          db 0
PLY_SE_PSGREG9                          db 0
PLY_SE_PSGREG10                         db 0
PLY_SE_PSGHARDWAREPERIOD_INSTR  equ $-1:dw 0
