;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@                 S y m b O S   -   S o u n d - D a e m o n                  @
;@                                                                            @
;@               (c) 2022 by Prodatron / SymbiosiS (Jörn Mika)                @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

;Todo
;- 



;==============================================================================
;### CODE AREA ################################################################
;==============================================================================


;### PRGPRZ -> Application process
winmai_id  db 0                     ;main window ID

prgprz  ld de,winmai
        ld a,(App_BnkNum)
        call SyDesktop_WINOPN       ;open game window
        jp c,prgend                 ;memory full -> quit process
        ld (wingam_id),a            ;window has been opened -> store ID
        ld a,64
        ld (winmendat_hid+2),a      ;hide progress-init bitmap
        jp menprc

prgprz0 rst #30

        ld ix,(App_PrcID)           ;check for messages (idle)
        db #dd:ld h,-1
        ld iy,App_MsgBuf
        rst #18
        db #dd:dec l
        jr nz,prgprz0
        ld a,(App_MsgBuf+0)
        or a
        jr z,prgend
        cp MSR_DSK_WCLICK
        jr nz,prgprz0
        ld a,(App_MsgBuf+2)
        cp DSK_ACT_KEY
        jr z,prgkey
        cp DSK_ACT_CLOSE
        jr z,prgend
        cp DSK_ACT_CONTENT
        jr nz,prgprz0
        ld hl,(App_MsgBuf+8)
        ld a,h
        or h
        jr z,prgprz0
        jp (hl)

;### PRGKEY -> key clicked
prgkey  ld a,(App_MsgBuf+4)
        call clcucs
        jr prgprz0

;### PRGEND -> End program
prgend  ld hl,cfgdatflg
        bit 0,(hl)
        call nz,cfgsav
        ld hl,(App_BegCode+prgpstnum)
        call SySystem_PRGEND
prgend0 rst #30
        jr prgend0

;### PRGINF -> open info window
prginf  ld a,(App_BnkNum)
        ld hl,prgmsginf
        ld b,8*2+1+64+128
        ld de,wingam
        call SySystem_SYSWRN
        jp menprc0

;### PRGHLP -> shows help
prghlp  call SySystem_HLPOPN
        jp menprc0



;==============================================================================
;### HANDLER MANAGEMENT #######################################################
;==============================================================================

hnddatuse   equ 0       ;flag, if this handler is used

hnddatlen   equ 1
hnddatmax   equ 16

handatmem   ds hnddatlen*hnddatmax


;==============================================================================
;### SOUND MANAGEMENT #########################################################
;==============================================================================

snddatuse   equ 0       ;flag, if this sound bank slot is used
snddathdn   equ 1       ;handler ID
snddattyp   equ 2       ;hardware type (0=psg, 1=opl3)
snddatadr   equ 3       ;address (psg -> 2B inside z80, opl3 -> 3B inside opl4 wavetable)
snddatsiz   equ 6       ;size (psg -> in 256b, opl4 -> in 1024b)
;...table with start/len for each sound

snddatlen   equ 16
snddatmax   equ 16

snddatmem   ds snddatlen*snddatmax


;==============================================================================
;### MUSIC MANAGEMENT #########################################################
;==============================================================================

musdatuse   equ 0       ;flag, if this music slot is used
musdathdn   equ 1       ;handler ID
musdattyp   equ 2       ;hardware type (0=psg, 1=opl3)
musdatbnk   equ 3       ;ram bank (0-15)
musdatadr   equ 4       ;address
musdatsiz   equ 6       ;length (including player)

musdatlen   equ 8
musdatmax   equ 16

musdatmem   ds musdatlen*musdatmax


;==============================================================================
;### SOUND MEMORY MANAGEMENT ##################################################
;==============================================================================

smmpsgtot   equ 16384
smmpsgunt   equ 256
smmpsgmap   ds smmpsgtot/smmpsgunt

smmop4tot   equ 2097152
smmop4unt   equ 1024
smmop4map   ds smmop4tot/smmop4unt

smmtyp  dw smmpsgmap
        db smmpsguni




;### SNDMGT -> reserves sound memory in limited Z80 (16K) or wavetable (512-2048K) space
;### Input      D=hardware type (0=psg, 1=opl4), BC=size in bytes
;### Output     CF=0 ok -> E,HL=address
;###            CF=1 memory full
;### Destroyed  ?
sndmgt  ;...
        ret

;### SNDMFR -> frees sound memory in limited Z80 (16K) or wavetable (512-2048K) space
;### Input      IX=memory structure, E,HL=address, BC=size in bytes
;### Destroyed  ?
sndmfr  ;...
        ret





;==============================================================================
;### DATA AREA ################################################################
;==============================================================================

App_BegData



prgicn16c db 12,24,24:dw $+7:dw $+4,12*24:db 5
db #17,#17,#17,#17,#17,#17,#17,#17,#17,#17,#17,#17,#71,#11,#11,#11,#11,#11,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#17,#71,#11,#11,#11,#11,#11,#71,#11,#11,#11,#11,#11
db #11,#A1,#A1,#11,#11,#1A,#AA,#11,#11,#11,#11,#17,#71,#AA,#A1,#11,#11,#AA,#81,#11,#11,#11,#11,#11,#11,#1A,#81,#11,#11,#18,#88,#11,#11,#11,#11,#17,#71,#18,#88,#11,#11,#18,#71,#11,#11,#11,#11,#11
db #11,#88,#71,#11,#11,#87,#71,#11,#11,#11,#11,#17,#71,#87,#71,#11,#11,#87,#71,#81,#11,#11,#11,#11,#11,#77,#77,#11,#11,#77,#18,#11,#11,#11,#11,#17,#78,#81,#18,#81,#11,#88,#11,#11,#11,#11,#11,#11
db #10,#00,#00,#00,#00,#01,#31,#14,#41,#14,#41,#13,#33,#33,#33,#33,#33,#30,#34,#47,#44,#44,#44,#43,#33,#33,#33,#33,#33,#33,#34,#44,#44,#44,#44,#43,#33,#22,#23,#22,#23,#32,#34,#44,#44,#74,#44,#43
db #33,#22,#32,#32,#23,#33,#34,#44,#44,#44,#47,#43,#33,#23,#22,#23,#23,#32,#34,#47,#44,#44,#44,#43,#33,#32,#22,#22,#33,#33,#34,#44,#44,#44,#44,#43,#33,#23,#22,#23,#23,#32,#34,#44,#44,#74,#44,#43
db #33,#22,#32,#32,#23,#33,#34,#44,#44,#44,#47,#43,#33,#22,#23,#22,#23,#32,#34,#47,#44,#44,#44,#43,#33,#33,#33,#33,#33,#33,#33,#44,#44,#44,#44,#33,#13,#33,#33,#33,#33,#31,#33,#33,#33,#33,#33,#33

wintittxt  db "Lymings",0

;### info
prgmsginf1 db "SymbOS Sound Daemon",0
prgmsginf2 db " Version 0.1 (Build "
read "..\..\..\..\SVN-Main\trunk\build.asm"
           db "pdt)",0
prgmsginf3 db " Copyright <c> 2022 SymbiosiS",0



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

;### COMPUTER TYPE ############################################################

cfghrdtyp   db 0    ;bit[0-4] Computer type     0=464, 1=664, 2=6128, 3=464Plus, 4=6128Plus,
                    ;                               5=*reserved*
                    ;                           6=Enterprise 64/128,
                    ;                           7=MSX1, 8=MSX2, 9=MSX2+, 10=MSX TurboR,
                    ;                               11=*reserved*
                    ;                           12=PCW8xxx, 13=PCW9xxx
                    ;                           14=PcW16
                    ;                           15=NC100, 16=NC150, 17=NC200
                    ;                               18-31=*reserved*
                    ;bit[5-6] BackGrGfxSize     0=320x200x4, 1=512x212x4/16, 2=256x192x2, 3=specific
                    ;bit[7]   BitmapEncoding    0=CPC type (CPC,PCW,EP), 1=MSX type (MSX)

;### INFO-FENSTER #############################################################

prgmsginf  dw prgmsginf1,4*1+2,prgmsginf2,4*1+2,prgmsginf3,4*1+2,prgicnbig




prgtrnend
