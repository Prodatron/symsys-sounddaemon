;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@             S y m b O S   -   S o u n d - D a e m o n   TESTER             @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@



;==============================================================================
;### CODE AREA ################################################################
;==============================================================================

stawin_id   db 0    ;status window ID

rmtply  ld b,0
rmtply1 ld ix,0
rmtply2 ld iy,0
        call #ff03
        ret
        

;### PRGPRZ -> Application process
prgprz  call SySound_SNDINI         ;search and set Sound Daemon
        jp c,prgend
        ld hl,SySound_PrcID
        ld de,statxtdem0
        call clchex

        ld a,(App_BnkNum)
        ld de,stawindat
        call SyDesktop_WINOPN
        ld (stawin_id),a
        jp c,prgend

        ;call SySound_RMTACT
        ;ld (rmtply+1),a
        ;ld (rmtply1+2),hl
        ;ld (rmtply2+2),bc

prgprz0 
;rst #30
;call rmtply

        ld ix,(App_PrcID)           ;check for messages
        db #dd:ld h,-1
        ld iy,App_MsgBuf
        rst #08     ;#18
        db #dd:dec l
        jr nz,prgprz0
        ld a,(App_MsgBuf+0)
        or a
        jr z,prgend
        cp MSR_DSK_WCLICK
        jr nz,prgprz0
        ld a,(App_MsgBuf+2)
        cp DSK_ACT_CLOSE
        jr z,prgend
        cp DSK_ACT_MENU
        jr z,prgprz1
        cp DSK_ACT_CONTENT
        jr nz,prgprz0
prgprz1 ld hl,(App_MsgBuf+8)
        ld a,l
        or h
        jr z,prgprz0
        jp (hl)

;### PRGEND -> End program
prgend  
;call SySound_RMTDCT

        ld hl,(App_BegCode+prgpstnum)
        call SySystem_PRGEND
prgend0 rst #30
        jr prgend0

;### STATAB -> changes status window tab
statabadr   dw stawingrpa,stawingrpb
statabact   db 0
statab  ld a,(stactrtba0)
        ld hl,statabact
        ld bc,statabadr
        ld ix,stawindat0
        ld de,stawin_id
        call statab0
        jp prgprz0
statab0 cp (hl)
        ret z
        ld (hl),a
        add a
        ld l,a
        ld h,0
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (ix+0),l
        ld (ix+1),h
        ld a,(de)
        ld e,-1
        jp SyDesktop_WININH


;==============================================================================
;### SUB ROUTINES #############################################################
;==============================================================================

;### CLCHEX -> converts a number into a hex string
;### Input      (HL)=number, DE=string pointer
;### Output     DE=DE+1
;### Destroyed  AF
clchex  xor a
        rld
        call clchex1
        inc de
clchex1 push af
        daa
        add #f0
        adc #40
        ld (de),a
        pop af
        rld
        ret

;### CLCR16 -> Wandelt String in 16Bit Zahl um
;### Eingabe    IX=String, A=Terminator, BC=Untergrenze (>=0), DE=Obergrenze (<=65534)
;### Ausgabe    IX=String hinter Terminator, HL=Zahl, CF=1 -> Ungültiges Format (zu groß/klein, falsches Zeichen/Terminator)
;### Veraendert AF,DE,IYL
clcr16  ld hl,0
        db #fd:ld l,a
clcr161 ld a,(ix+0)
        inc ix
        db #fd:cp l
        jr z,clcr163
        sub "0"
        cp 10
        ccf
        ret c
        push bc
        add hl,hl:jr c,clcr162
        ld c,l
        ld b,h
        add hl,hl:jr c,clcr162
        add hl,hl:jr c,clcr162
        add hl,bc:jr c,clcr162
        ld c,a
        ld b,0
        add hl,bc:ret c
        pop bc
        jr clcr161
clcr162 pop bc
        ret
clcr163 sbc hl,bc
        ret c
        add hl,bc
        inc de
        sbc hl,de
        ccf
        ret c
        add hl,de
        or a
        ret

;### FILBRW -> browse file
;### Input      HL=path, D=music"M"/effect"X", A=type (0=psg, 1=opl4)
filbrw  dec a
        ld e,"P"
        jr z,filbrw1
        ld e,"W"
filbrw1 ld (cfgbrwpth+1),de
        push hl
        ld de,cfgbrwpth+4
        ld bc,128
        ldir
        ld hl,cfgbrwpth
        ld b,0
        call filbrw0
        pop de
        jp nz,prgprz0
        ld hl,cfgbrwpth+4
        ld bc,128
        ldir
        ld e,3
filbrw2 ld a,(stawin_id)
        call SyDesktop_WININH
        jp prgprz0
filbrw0 ld a,(App_BnkNum)
        add b
        ld c,8
        ld ix,100
        ld iy,5000
        ld de,stawindat
        call SySystem_SELOPN
        or a
        ret

filopn  ld a,(App_BnkNum)
        db #dd:ld h,a
        jp SyFile_FILOPN

filerr  ld a,(App_BnkNum)
        ld b,8*1+1
        ld de,stawindat
        jp SySystem_SYSWRN


;==============================================================================
;### TEST ROUTINES ############################################################
;==============================================================================

mushnd  db -1
efxhnd  db -1

musbrw  ld hl,cfgmusfil
        ld d,"M"
        ld a,(cfgmustyp)
        jr filbrw

efxbrw  ld hl,cfgefxfil
        ld d,"X"
        ld a,(cfgefxtyp)
        jr filbrw

;### MUSLOD -> loads music
muslod  ld a,(mushnd)
        inc a
        jr nz,muslod2
        ld hl,cfgmusfil
        call filopn
        push af
        ld hl,prgerrfil
        call c,filerr       ;error while opening
        pop af
        jp c,prgprz0
        ld de,(cfgmustyp-1)
        ld e,0
        push af
        call SySound_MUSLOD
        pop bc
        jr c,muslod1
        ld (mushnd),a
        ld a,b
        call SyFile_FILCLO
        ld hl,mushnd
        ld de,mustxthnd+1
        call clchex
muslod4 ld e,7
        jp filbrw2
muslod1 ld a,b              ;error while loading
        call SyFile_FILCLO
        ld hl,prgerrlod
        call filerr
        jp prgprz0
muslod2 ld hl,prgerrexi
muslod3 call filerr
        jp prgprz0

;### MUSFRE -> removes music
musfre  ld a,(mushnd)
        inc a
        ld hl,prgerremp
        jr z,muslod3
        dec a
        call SySound_MUSFRE
        ld a,-1
        ld (mushnd),a
        ld hl,"--"
        ld (mustxthnd+1),hl
        jr muslod4

;### EFXLOD -> loads effects
efxlod  ld a,(efxhnd)
        inc a
        jr nz,muslod2
        ld hl,cfgefxfil
        call filopn
        push af
        ld hl,prgerrfil
        call c,filerr       ;error while opening
        pop af
        jp c,prgprz0
        ld de,(cfgefxtyp-1)
        ld e,0
        push af
        call SySound_EFXLOD
        pop bc
        jr c,muslod1
        ld (efxhnd),a
        ld a,b
        call SyFile_FILCLO
        ld hl,efxhnd
        ld de,efxtxthnd+1
        call clchex
        jr muslod4

;### EFXFRE -> removes effects
efxfre  ld a,(efxhnd)
        inc a
        ld hl,prgerremp
        jr z,muslod3
        dec a
        call SySound_EFXFRE
        ld a,-1
        ld (efxhnd),a
        ld hl,"--"
        ld (efxtxthnd+1),hl
        jp muslod4

efxghn  ld a,(efxhnd)
        jr musghn1
musghn  ld a,(mushnd)
musghn1 cp -1
        scf:ccf
        ret nz
        ld hl,prgerremp
        call filerr
        scf
        ret

;### EFXTP1/2 -> change effect type to PSG/OPL4
efxtp1  ld hl,efxctrpri_rec1
        ld a,5
        jr efxtp0
efxtp2  ld hl,efxctrpri_rec2
        ld a,3
efxtp0  ld (efxctrpri+4),hl
        ld (efxctrpri+0),a
        xor a
        ld (efxctrpri+12),a
        ld e,22
        jp filbrw2

;### Music Control
musrst  ld ix,cfgmusnum
        xor a
        ld bc,0
        ld de,255
        call clcr16
        jp c,prgprz0
        call musghn
        call nc,SySound_MUSRST
        jp prgprz0
musstp  call musghn
        call nc,SySound_MUSSTP
        jp prgprz0
muscon  call musghn
        call nc,SySound_MUSCON
        jp prgprz0
musvol  ld ix,cfgmusvol
        xor a
        ld bc,0
        ld de,255
        call clcr16
        jp c,prgprz0
        ld h,l
        call musghn
        call nc,SySound_MUSVOL
        jp prgprz0

;### Effect Control
efxply  ld ix,cfgefxptc
        xor a
        ld bc,0
        ld de,907
        call clcr16
        jp c,prgprz0
        ld (efxply2+1),hl
        ld ix,cfgefxvol
        xor a
        ld bc,0
        ld de,255
        call clcr16
        jp c,prgprz0
        push hl
        ld ix,cfgefxnum
        xor a
        ld bc,0
        ld de,255
        call clcr16
        pop de
        jp c,prgprz0
        ld h,e
        ld a,(cfgefxtyp)
        dec a
        ld a,(cfgefxchn)
        jr z,efxply1        ;psg  -> use channel 0/1/2
        cp 1
        jr c,efxply1        ;opl4 -> use panning 0/128/255
        ld a,128
        jr z,efxply1
        ld a,255
efxply1 ld c,a
        ld a,(efxctrpri+12)
        inc a
        ld b,a
        call efxghn
efxply2 ld de,0
        call nc,SySound_EFXPLY
        jp prgprz0

efxstp  ld ix,cfgefxnum
        xor a
        ld bc,0
        ld de,255
        call clcr16
        jp c,prgprz0
        call efxghn
        call nc,SySound_EFXSTP
        jp prgprz0


;==============================================================================
;### DATA AREA ################################################################
;==============================================================================

App_BegData

prgerr0 db 0

prgerrfil1  db "Error while opening file",0
prgerremp1  db "Nothing loaded",0
prgerrexi1  db "Already loaded",0

prgerrlod1  db "Error while loading file:",0
prgerrlod2  db "Wrong format or device",0
prgerrlod3  db "or disc error",0

;### status text data
stamentxt1  db "File",0
stamentxt11 db "Quit",0

statxttit   db "TESTER for Sound Daemon",0

statxttba1  db "Music",0
statxttba2  db "Effects",0

mustxtffl   db "File",0
mustxtfpl   db "Control",0

statxtdem   db "Sound Daemon at process ID ":statxtdem0 db "##",0
mustxthnd   db "#-- ",0
efxtxthnd   db "#-- ",0

filtxtbrw   db "...",0
filtxtlod   db "Load",0
filtxtfre   db "Unload",0

mustxttp1   db "PSG",0
mustxttp2   db "OPL4",0

mustxtntx   db "Subsong",0
efxtxtntx   db "ID",0
efxtxtvtx   db "Volume",0
efxtxtptx   db "Pitch",0

mustxtvst   db "Set",0

efxtxtch1   db "left",0
efxtxtch2   db "middle",0
efxtxtch3   db "right",0

mustxtply   db "Play",0
mustxtstp   db "Stop",0
mustxtcon   db "Continue",0

efxtxtpp1   db "Play always on specified channel",0
efxtxtpp2   db "Play only, if free specified channel",0
efxtxtpp3   db "Play always on rotating channel",0
efxtxtpp4   db "Play only, if free rotating channel",0
efxtxtpp5   db "Play only, if no active effect",0

efxtxtpo1   db "Play",0
efxtxtpo2   db "Play, first stop same effects",0
efxtxtpo3   db "Play, first stop all effects",0


;==============================================================================
;### TRANSFER AREA ############################################################
;==============================================================================

App_BegTrns

;### PRGPRZS -> Stack for application process
        ds 128
prgstk  ds 6*2
        dw prgprz
App_PrcID  db 0
App_MsgBuf ds 14


prgerrfil  dw prgerrfil1,4*1+2,prgerr0,4*1+2,prgerr0,4*1+2
prgerremp  dw prgerremp1,4*1+2,prgerr0,4*1+2,prgerr0,4*1+2
prgerrexi  dw prgerrexi1,4*1+2,prgerr0,4*1+2,prgerr0,4*1+2
prgerrlod  dw prgerrlod1,4*1+2,prgerrlod2,4*1+2,prgerrlod3,4*1+2


;### status window data
stawindat   dw #3501,0,56,26,172,133,0,0,172,133,172,133,172,133,prgicnsml,statxttit,0,stamendat
stawindat0  dw stawingrpa,0,0:ds 136+14
stawingrpa  db 20,0:dw stawindata,0,0,4*256+3,0,0,2
stawingrpb  db 23,0:dw stawindatb,0,0,4*256+3,0,0,2

stamendat   dw 1, 1+4,stamentxt1,stamendat1,0
stamendat1  dw 1, 1,stamentxt11,prgend,0

stawindata                                                              ;*** MUSIC
; onclick         type   property   xpos   ypos   xlen   ylen
dw      0,  255*256+ 0,         2,     0,     0, 10000, 10000, 0    ;00 background
dw statab,  255*256+20, stactrtba,     0,     2,   205,    11, 0    ;01 tab
dw      0,  255*256+ 3, musctrffl,     0,    18,   172,    44, 0    ;02 file frame
dw      0,  255*256+32, musctrinp,     8,    29,   134,    12, 0    ;03 file input
dw musbrw,  255*256+16, filtxtbrw,   144,    29,    20,    12, 0    ;04 file browse
dw muslod,  255*256+16, filtxtlod,    70,    43,    34,    12, 0    ;05 file load
dw musfre,  255*256+16, filtxtfre,   106,    43,    34,    12, 0    ;06 file free
dw      0,  255*256+ 1, musctrhnd,   146,    45,    18,     8, 0    ;07 handler id
dw      0,  255*256+18, musctrtp1,     8,    45,    36,     8, 0    ;08 type psg
dw      0,  255*256+18, musctrtp2,    36,    45,    36,     8, 0    ;09 type opl4
dw      0,  255*256+ 3, musctrfpl,     0,    62,   172,    46, 0    ;10 play frame
dw musrst,  255*256+16, mustxtply,     8,    73,    49,    12, 0    ;11 play play
dw musstp,  255*256+16, mustxtstp,    61,    73,    49,    12, 0    ;12 play stop
dw muscon,  255*256+16, mustxtcon,   114,    73,    49,    12, 0    ;13 play continue
dw      0,  255*256+ 1, musctrntx,     8,    91,    40,     8, 0    ;14 subsong text
dw      0,  255*256+32, musctrnum,    45,    89,    25,    12, 0    ;15 subsong input
dw      0,  255*256+ 1, efxctrvtx,    83,    91,    40,     8, 0    ;16 volume text
dw      0,  255*256+32, musctrvin,   116,    89,    25,    12, 0    ;17 volume input
dw musvol,  255*256+16, mustxtvst,   143,    89,    20,    12, 0    ;18 volume set
dw      0,  255*256+ 1, stactrdem,     4,   120,   172,     8, 0    ;19 daemon id

stawindatb                                                              ;*** EFFECTS
; onclick         type   property   xpos   ypos   xlen   ylen
dw      0,  255*256+ 0,         2,     0,     0, 10000, 10000, 0    ;00 background
dw statab,  255*256+20, stactrtba,     0,     2,   205,    11, 0    ;01 tab
dw      0,  255*256+ 3, musctrffl,     0,    18,   172,    44, 0    ;02 file frame
dw      0,  255*256+32, efxctrinp,     8,    29,   134,    12, 0    ;03 file input
dw efxbrw,  255*256+16, filtxtbrw,   144,    29,    20,    12, 0    ;04 file browse
dw efxlod,  255*256+16, filtxtlod,    70,    43,    34,    12, 0    ;05 file load
dw efxfre,  255*256+16, filtxtfre,   106,    43,    34,    12, 0    ;06 file free
dw      0,  255*256+ 1, efxctrhnd,   146,    45,    18,     8, 0    ;07 handler id
dw efxtp1,  255*256+18, efxctrtp1,     8,    45,    36,     8, 0    ;08 type psg
dw efxtp2,  255*256+18, efxctrtp2,    36,    45,    36,     8, 0    ;09 type opl4
dw      0,  255*256+ 3, musctrfpl,     0,    62,   172,    71, 0    ;10 play frame
dw efxply,  255*256+16, mustxtply,     8,    73,    49,    12, 0    ;11 play play
dw efxstp,  255*256+16, mustxtstp,    61,    73,    49,    12, 0    ;12 play stop
dw      0,  255*256+ 1, efxctrntx,     8,    91,     9,     8, 0    ;13 effect text
dw      0,  255*256+32, efxctrnum,    17,    89,    25,    12, 0    ;14 effect input
dw      0,  255*256+ 1, efxctrvtx,    48,    91,    40,     8, 0    ;15 volume text
dw      0,  255*256+32, efxctrvin,    80,    89,    25,    12, 0    ;16 volume input
dw      0,  255*256+ 1, efxctrptx,   113,    91,    40,     8, 0    ;17 pitch text
dw      0,  255*256+32, efxctrpin,   136,    89,    25,    12, 0    ;18 pitch input
dw      0,  255*256+18, efxctrch1,     8,   103,    36,     8, 0    ;19 psg channel 1
dw      0,  255*256+18, efxctrch2,    39,   103,    36,     8, 0    ;20 psg channel 2
dw      0,  255*256+18, efxctrch3,    82,   103,    36,     8, 0    ;21 psg channel 3
dw      0,  255*256+42, efxctrpri,     8,   115,   156,    10, 0    ;22 sound dropdown


stactrtba   db 2,2+4+48+64
stactrtba0  db 0:dw statxttba1:db -1:dw statxttba2:db -1

stactrdem   dw statxtdem,2+12
musctrhnd   dw mustxthnd,2+12
efxctrhnd   dw efxtxthnd,2+12

musctrffl   dw mustxtffl,2+4
musctrfpl   dw mustxtfpl,2+4

musctrntx   dw mustxtntx,2+4
efxctrntx   dw efxtxtntx,2+4
efxctrptx   dw efxtxtptx,2+4

musctrinp   dw cfgmusfil,0,0,0,0,127:db 0
efxctrinp   dw cfgefxfil,0,0,0,0,127:db 0

cfgmusfil   ds 128              ;music  file
cfgefxfil   ds 128              ;effect file
cfgmustyp   db 1                ;music  device
cfgefxtyp   db 1                ;effect device
cfgefxchn   db 1                ;effect channel/panning (0=left/0, 1=middle/128, 2=right/255)
cfgmusvol   db "255",0          ;music  volume
cfgefxvol   db "255",0          ;effect volume
cfgefxptc   db "0",0,0,0        ;effect pitch
cfgmusnum   db "0",0,0,0        ;music  subnum
cfgefxnum   db "0",0,0,0        ;effect subnum

cfgbrwpth   db "S??":db 0:ds 256

musctrtp1   dw cfgmustyp,mustxttp1,256*1+2+4,musctrtpc
musctrtp2   dw cfgmustyp,mustxttp2,256*2+2+4,musctrtpc
musctrtpc   dw -1,-1

efxctrtp1   dw cfgefxtyp,mustxttp1,256*1+2+4,efxctrtpc
efxctrtp2   dw cfgefxtyp,mustxttp2,256*2+2+4,efxctrtpc
efxctrtpc   dw -1,-1

efxctrvtx   dw efxtxtvtx,2+4

musctrnum   dw cfgmusnum,0,1,0,1,3:db 0
efxctrnum   dw cfgefxnum,0,1,0,1,3:db 0
musctrvin   dw cfgmusvol,0,3,0,3,3:db 0
efxctrvin   dw cfgefxvol,0,3,0,3,3:db 0
efxctrpin   dw cfgefxptc,0,3,0,3,3:db 0

efxctrch1   dw cfgefxchn,efxtxtch1,256*0+2+4,efxctrchc
efxctrch2   dw cfgefxchn,efxtxtch2,256*1+2+4,efxctrchc
efxctrch3   dw cfgefxchn,efxtxtch3,256*2+2+4,efxctrchc
efxctrchc   dw -1,-1

efxctrpri   dw 5,0,efxctrpri_rec1,0,1,efxctrpri_clm,0,1
efxctrpri_clm   dw 0,200,0,0
efxctrpri_rec1
dw  1,efxtxtpp1, 2,efxtxtpp2, 3,efxtxtpp3, 4,efxtxtpp4, 5,efxtxtpp5
efxctrpri_rec2
dw  1,efxtxtpo1, 2,efxtxtpo2, 3,efxtxtpo3



prgtrnend
