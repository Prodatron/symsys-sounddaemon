;replaces PLY_AKG_SENDPSGREGISTERS of the CPC version
;for the Enterprise with Dave emulation

        ld (PLY_AKG_PSGREG7),a
read"Dmn-Sound-VolMus.asm"
        ld hl,PLY_AKG_PSGREG_ALL
        ld b,0
PLY_AKG_SENDPSGREGISTERS_LOOP
        ld c,(hl)
        inc hl
        ld a,b
        call ayRegisterWrite
        inc b
        ld a,b
        cp 13
        jr nz,PLY_AKG_SENDPSGREGISTERS_LOOP
PLY_AKG_PSGREG13_OLDVALUE
        ld a,255
PLY_AKG_RETRIG
        or 0
PLY_AKG_PSGREG13_INSTR
        ld l,0
        cp l
        jr z,PLY_AKG_PSGREG13_END
        ld a,l
        ld (PLY_AKG_PSGREG13_OLDVALUE+1),a
        ld c,a
        ld a,13
        call ayRegisterWrite
        xor a
        ld (PLY_AKG_RETRIG+1),a

PLY_AKG_PSGREG13_END
PLY_AKG_SAVESP ld sp,0
    ret 

PLY_AKG_PSGREG_ALL
PLY_AKG_PSGREG01_INSTR          equ $-1:dw 0
PLY_AKG_PSGREG23_INSTR          equ $-1:dw 0
PLY_AKG_PSGREG45_INSTR          equ $-1:dw 0
PLY_AKG_PSGREG6                         db 0
PLY_AKG_PSGREG7                         db 0
PLY_AKG_PSGREG8                         db 0
PLY_AKG_PSGREG9                         db 0
PLY_AKG_PSGREG10                        db 0
PLY_AKG_PSGHARDWAREPERIOD_INSTR equ $-1:dw 0
