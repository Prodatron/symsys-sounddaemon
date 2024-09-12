PLY_SE_USESTOPSOUNDS equ $+1
PLY_SE_OFFSET1B equ $+1
;RASM_VERSION equ $+2
PLY_SE_OFFSET2B equ $+2
PLY_SE_SOUNDEFFECTDATA_OFFSETINVERTEDVOLUME equ $+2
PLY_SE_INITSOUNDEFFECTS ld (PLY_SE_PTSOUNDEFFECTTABLE+1),hl
PLY_SE_SOUNDEFFECTDATA_OFFSETSPEED equ $+1
PLY_SE_SOUNDEFFECTDATA_OFFSETCURRENTSTEP ld hl,0
PLY_SE_CHANNEL_SOUNDEFFECTDATASIZE equ $+2
    ld (PLY_SE_CHANNEL1_SOUNDEFFECTDATA),hl
    ld (PLY_SE_CHANNEL2_SOUNDEFFECTDATA),hl
    ld (PLY_SE_CHANNEL3_SOUNDEFFECTDATA),hl
    ret 
PLY_SE_PLAYSOUNDEFFECT dec a
PLY_SE_PTSOUNDEFFECTTABLE ld hl,0
    ld e,a
    ld d,0
    add hl,de
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld a,(de)
    inc de
    ex af,af'
    ld a,b
    ld hl,PLY_SE_CHANNEL1_SOUNDEFFECTDATA
    ld b,0
    sla c
    sla c
    sla c
    add hl,bc
    ld (hl),e
    inc hl
    ld (hl),d
    inc hl
    ld (hl),a
    inc hl
    ld (hl),0
    inc hl
    ex af,af'
    ld (hl),a
    ret 
PLY_SE_STOPSOUNDEFFECTFROMCHANNEL ld c,a
    add a,a
    add a,a
    add a,a
    ld e,a
    ld d,0
    ld hl,PLY_SE_CHANNEL1_SOUNDEFFECTDATA
    add hl,de
    ld (hl),d
    inc hl
    ld (hl),d
    ld hl,PLY_SE_PSGREG8
    ld a,c
    or a
    jr z,PLY_SE_STOPSOUNDEFFECTFROMCHANNEL_FOUNDCHANNEL
    ld hl,PLY_SE_PSGREG9
    dec a
    jr z,PLY_SE_STOPSOUNDEFFECTFROMCHANNEL_FOUNDCHANNEL
    ld hl,PLY_SE_PSGREG10
    dec a
PLY_SE_STOPSOUNDEFFECTFROMCHANNEL_FOUNDCHANNEL ld (hl),a
    ret 
PLY_SE_PLAYSOUNDEFFECTSSTREAM ld ix,PLY_SE_CHANNEL1_SOUNDEFFECTDATA
    ld iy,PLY_SE_PSGREG8
    ld hl,PLY_SE_PSGREG01_INSTR+1
    exx
    ld c,252
    call PLY_SE_PSES_PLAY
    ld ix,PLY_SE_CHANNEL2_SOUNDEFFECTDATA
    ld iy,PLY_SE_PSGREG9
    exx
    ld hl,PLY_SE_PSGREG23_INSTR+1
    exx
    srl c
    call PLY_SE_PSES_PLAY
    ld ix,PLY_SE_CHANNEL3_SOUNDEFFECTDATA
    ld iy,PLY_SE_PSGREG10
    exx
    ld hl,PLY_SE_PSGREG45_INSTR+1
    exx
    scf
    rr c
    call PLY_SE_PSES_PLAY
    ld a,c
PLY_SE_SENDPSGREGISTERS

ld b,a
read"Dmn-Sound-VolEfx.asm"

;    ld b,a
    ld a,7
    out (160),a
    ld a,b
    out (161),a
PLY_SE_PSGREG01_INSTR ld hl,0
    xor a
    out (160),a
    ld a,l
    out (161),a
    ld a,1
    out (160),a
    ld a,h
    out (161),a
PLY_SE_PSGREG23_INSTR ld hl,0
    ld a,2
    out (160),a
    ld a,l
    out (161),a
    ld a,3
    out (160),a
    ld a,h
    out (161),a
PLY_SE_PSGREG45_INSTR ld hl,0
    ld a,4
    out (160),a
    ld a,l
    out (161),a
    ld a,5
    out (160),a
    ld a,h
    out (161),a
PLY_SE_PSGREG6 equ $+1
PLY_SE_PSGREG8 equ $+2
PLY_SE_PSGREG6_8_INSTR ld hl,0
    ld a,6
    out (160),a
    ld a,l
    out (161),a
    ld a,8
    out (160),a
    ld a,h
    out (161),a
PLY_SE_PSGREG9 equ $+1
PLY_SE_PSGREG10 equ $+2
PLY_SE_PSGREG9_10_INSTR ld hl,0
    ld a,9
    out (160),a
    ld a,l
    out (161),a
    ld a,10
    out (160),a
    ld a,h
    out (161),a
PLY_SE_PSGHARDWAREPERIOD_INSTR ld hl,0
    ld a,11
    out (160),a
    ld a,l
    out (161),a
    ld a,12
    out (160),a
    ld a,h
    out (161),a
    ld a,13
    out (160),a
PLY_SE_PSGREG13_OLDVALUE ld a,255
PLY_SE_RETRIG or 0
PLY_SE_PSGREG13_INSTR ld l,0
    cp l
    ret z
    ld a,l
    ld (PLY_SE_PSGREG13_OLDVALUE+1),a
    out (161),a
    xor a
    ld (PLY_SE_RETRIG+1),a
    ret 
PLY_SE_PSES_PLAY ld l,(ix+0)
    ld h,(ix+1)
    ld a,l
    or h
    ret z
PLY_SE_PSES_READFIRSTBYTE ld a,(hl)
    inc hl
    ld b,a
    rra 
    jr c,PLY_SE_PSES_SOFTWAREORSOFTWAREANDHARDWARE
    rra 
    jr c,PLY_SE_PSES_HARDWAREONLY
    rra 
    jr c,PLY_SE_PSES_S_ENDORLOOP
    call PLY_SE_PSES_MANAGEVOLUMEFROMA_FILTER4BITS
    rl b
    call PLY_SE_PSES_READNOISEIFNEEDEDANDOPENORCLOSENOISECHANNEL
    set 2,c
    jr PLY_SE_PSES_SAVEPOINTERANDEXIT
PLY_SE_PSES_S_ENDORLOOP rra 
    jr c,PLY_SE_PSES_S_LOOP
    xor a
    ld (ix+0),a
    ld (ix+1),a
    ld (iy+0),a
    ret 
PLY_SE_PSES_S_LOOP ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    jr PLY_SE_PSES_READFIRSTBYTE
PLY_SE_PSES_SAVEPOINTERANDEXIT ld a,(ix+3)
    cp (ix+4)
    jr c,PLY_SE_PSES_NOTREACHED
    ld (ix+3),0
    db 221
    db 117
    db 0
    db 221
    db 116
    db 1
    ret 
PLY_SE_PSES_NOTREACHED inc (ix+3)
    ret 
PLY_SE_PSES_HARDWAREONLY call PLY_SE_PSES_SHARED_READRETRIGHARDWAREENVPERIODNOISE
    set 2,c
    jr PLY_SE_PSES_SAVEPOINTERANDEXIT
PLY_SE_PSES_SOFTWAREORSOFTWAREANDHARDWARE rra 
    jr c,PLY_SE_PSES_SOFTWAREANDHARDWARE
    call PLY_SE_PSES_MANAGEVOLUMEFROMA_FILTER4BITS
    rl b
    call PLY_SE_PSES_READNOISEIFNEEDEDANDOPENORCLOSENOISECHANNEL
    res 2,c
    call PLY_SE_PSES_READSOFTWAREPERIOD
    jr PLY_SE_PSES_SAVEPOINTERANDEXIT
PLY_SE_PSES_SOFTWAREANDHARDWARE call PLY_SE_PSES_SHARED_READRETRIGHARDWAREENVPERIODNOISE
    call PLY_SE_PSES_READSOFTWAREPERIOD
    res 2,c
    jr PLY_SE_PSES_SAVEPOINTERANDEXIT
PLY_SE_PSES_SHARED_READRETRIGHARDWAREENVPERIODNOISE rra 
    jr nc,PLY_SE_PSES_H_AFTERRETRIG
    ld d,a
    ld a,255
    ld (PLY_SE_PSGREG13_OLDVALUE+1),a
    ld a,d
PLY_SE_PSES_H_AFTERRETRIG and 7
    add a,8
    ld (PLY_SE_PSGREG13_INSTR+1),a
    rl b
    call PLY_SE_PSES_READNOISEIFNEEDEDANDOPENORCLOSENOISECHANNEL
    call PLY_SE_PSES_READHARDWAREPERIOD
    ld a,16
ld (iy+0),a
ret
;    jp PLY_SE_PSES_MANAGEVOLUMEFROMA_HARD
PLY_SE_PSES_READNOISEIFNEEDEDANDOPENORCLOSENOISECHANNEL jr c,PLY_SE_PSES_READNOISEANDOPENNOISECHANNEL_OPENNOISE
    set 5,c
    ret 
PLY_SE_PSES_READNOISEANDOPENNOISECHANNEL_OPENNOISE ld a,(hl)
    ld (PLY_SE_PSGREG6),a
    inc hl
    res 5,c
    ret 
PLY_SE_PSES_READHARDWAREPERIOD ld a,(hl)
    ld (PLY_SE_PSGHARDWAREPERIOD_INSTR+1),a
    inc hl
    ld a,(hl)
    ld (PLY_SE_PSGHARDWAREPERIOD_INSTR+2),a
    inc hl
    ret 
PLY_SE_PSES_READSOFTWAREPERIOD ld a,(hl)
    inc hl
    exx
    ld (hl),a
    inc hl
    exx
    ld a,(hl)
    inc hl
    exx
    ld (hl),a
    exx
    ret 
PLY_SE_PSES_MANAGEVOLUMEFROMA_FILTER4BITS and 15
PLY_SE_PSES_MANAGEVOLUMEFROMA_HARD sub (ix+2)
    jr nc,PLY_SE_PSES_MVFA_NOOVERFLOW
    xor a
PLY_SE_PSES_MVFA_NOOVERFLOW ld (iy+0),a
    ret 
PLY_SE_CHANNEL1_SOUNDEFFECTDATA dw 0
PLY_SE_CHANNEL1_SOUNDEFFECTINVERTEDVOLUME db 0
PLY_SE_CHANNEL1_SOUNDEFFECTCURRENTSTEP db 0
PLY_SE_CHANNEL1_SOUNDEFFECTSPEED db 0
    db 0
    db 0
    db 0
PLY_SE_CHANNEL2_SOUNDEFFECTDATA db 0
    db 0
    db 0
    db 0
    db 0
    db 0
    db 0
    db 0
PLY_SE_CHANNEL3_SOUNDEFFECTDATA db 0
    db 0
    db 0
    db 0
    db 0
    db 0
    db 0
    db 0
