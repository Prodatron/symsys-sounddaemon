;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@                 S y m b O S   -   S o u n d - D a e m o n                  @
;@                                                                            @
;@             (c) 2023-2024 by Prodatron / SymbiosiS (Jörn Mika)             @
;@     PSG-based Arkos Tracker music/effect player (c) by Targhan / Arkos     @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

;Todo

;low
;- sound daemon GUI is loosing events/gets them too late (e.g. alert window) -> desktop/system library ignores them -> patch it
;- screen saver open/close window?
;- sound buffer config


;### ERROR CODES
snderruse   equ 1       ;music player is already in use
snderrdvc   equ 2       ;required device is not available
snderrfil   equ 3       ;error while reading from file
snderrmem   equ 4       ;cpu memory full
snderrme4   equ 5       ;OPL4 memory full
snderrdat   equ 7       ;wrong sound data in file

snderrunk   equ 255     ;*unknown*


;==============================================================================
;### CODE AREA ################################################################
;==============================================================================

stawin_id   db 0    ;status window ID
stawinvis   db 0    ;0=not visible, -1=visible


;### PRGPRZ -> Application process
prgprz  call prgdbl                 ;check, if already running
        call prgver

        call dvcdet
        call cfglod
        call cfgini

        ld de,vollupmus
        ld l,d
        ld h,d
        inc h
        ld (PLY_AKG_VOLLOOKUP+1),hl
        ld a,h
        ld (PLY_SE_VOLLOOKUP+1),a

        call rmtdct                 ;Timer hinzufügen

        call welbeg                 ;start welcome music
        call dskonl                 ;activate desktop sound effects

        call SySystem_HLPINI        ;init help
        ld a,(App_BnkNum)
        ld de,prgicnsml
        ld l,-1
        call SyDesktop_STIADD       ;add systray icon
        jr c,prgprz3
        ld (prgtryn),a
prgprz3 ;...

        ld a,(cfgflghid)
        or a
        call z,prgtry1              ;open main window
        jp c,prgend1

prgprz0 ld ix,(App_PrcID)           ;check for messages
        db #dd:ld h,-1
        ld iy,App_MsgBuf
        rst #08
        db #dd:dec l
        jr nz,prgprz0
        ld a,(App_MsgBuf+0)
        or a
        jp z,prgend
        db #dd:ld a,h
        cp PRC_ID_DESKTOP
        jr z,prgprz2
        cp PRC_ID_SYSTEM
        ;...
        ld (sndprcnum),a        ;*** message from applications
prgprz4 call msgcmd
        jr prgprz0
prgprz2 ld a,(App_MsgBuf+0)     ;*** message from desktop manager
        cp FNC_SND_EFXEVT
        jr z,prgprz4
        ;...
        cp MSR_DSK_EVTCLK
        jp z,prgtry
        cp MSR_DSK_WCLICK
        jr nz,prgprz0
        ld a,(App_MsgBuf+2)
        cp DSK_ACT_KEY
        jr z,prgkey
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

;### PRGKEY -> key clicked
prgkey  ld a,(App_MsgBuf+4)
        call clcucs
        ;...
        jr prgprz0

;### PRGEND -> End program
prgend
prgend1 call dskoff
        call psgstp
        ld a,(prgtryn)
        or a
        call nz,SyDesktop_STIREM
        ld hl,(App_BegCode+prgpstnum)
        call SySystem_PRGEND
prgend0 rst #30
        jr prgend0

;### PRGDBL -> Check,if program is already running
prgdbln db "Sound Daemon"
prgdbl  xor a
        ld (App_BegCode+prgdatnam),a
        ld e,0
        ld hl,prgdbln
        ld a,(App_BnkNum)
        call SySystem_PRGSRV
        or a
        jr z,prgend1
        ld a,"S"
        ld (App_BegCode+prgdatnam),a
        ret

;### PRGVER -> Plattform-Check
prgver  ld hl,jmp_sysinf            ;*** Computer-Typ holen
        ld de,256*1+5
        ld ix,cfghrdtyp
        ld iy,66+2+6+8
        rst #28
        ld a,(cfghrdtyp)
        and #1f
if     PLATFORM_TYPE=PLATFORM_CPC   ;CPC -> 0-4 OK
        cp 4+1
elseif PLATFORM_TYPE=PLATFORM_MSX   ;MSX -> 7-10 OK
        cp 7
        jr c,prgver1
        cp 10+1
elseif PLATFORM_TYPE=PLATFORM_PCW   ;PCW -> 12-13 OK
        cp 12
        jr c,prgver1
        cp 13+1
elseif PLATFORM_TYPE=PLATFORM_EPR   ;EP  -> 6 OK
        cp 6
        jr c,prgver1
        cp 6+1
elseif PLATFORM_TYPE=PLATFORM_SVM   ;SVM -> 18 OK
        cp 18
        jr c,prgver1
        cp 18+1
elseif PLATFORM_TYPE=PLATFORM_NCX   ;NC  -> 15-17 OK
        cp 15
        jr c,prgver1
        cp 17+1
elseif PLATFORM_TYPE=PLATFORM_ZNX   ;ZNX -> 20 OK
        cp 20
        jr c,prgver1
        cp 20+1
endif
        ret c
prgver1 ld b,8*1+1
        ld hl,prgmsgwpf
        call prginf0
        jr prgend

;### PRGINF -> open info window
prginf  ld b,8*2+1+64+128
        ld hl,prgmsginf
        call prginf0
        jp prgprz0
prginf0 ld a,(App_BnkNum)
        ld de,stawindat
        jp SySystem_SYSWRN

;### PRGHLP -> shows help
prghlp  call SySystem_HLPOPN
        jp prgprz0

;### PRGTRY -> tray icon clicked
prgtryn db 0

prgtry  ld a,(stawinvis)
        or a
        ld a,(stawin_id)
        jr nz,prytry2
        call prgtry1
        jp prgprz0
prgtry1 ld a,(App_BnkNum)
        ld de,stawindat
        call SyDesktop_WINOPN
        ret c
        ld (stawin_id),a
        ld a,-1
        ld (stawinvis),a
        ret
prytry2 call SyDesktop_WINTOP
        jp prgprz0

;### PRGTIM -> Program timer, calls player routine
prgtim  call psgfrm
        call op4frm
        rst #30
prgtim0 jr prgtim
        ld hl,(welcnt)
        dec hl
        ld (welcnt),hl
        ld a,l
        or h
        jr nz,prgtim
        call welend
        jr prgtim

;### STAAPL -> save config
staapl  call cfgsav
        jp prgprz0

;### STAHID -> hide status window
stahid  xor a
        ld (stawinvis),a
        ld a,(stawin_id)
        call SyDesktop_WINCLS
        jp prgprz0

;### STATAB -> changes status window tab
statabadr   dw stawingrpa,stawingrpb,stawingrpc,stawingrpd
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
;### WELCOME MUSIC ############################################################
;==============================================================================

welcnt  dw 50*5

welmus equ $+4
incbin"Dmn-Sound-Startup.spm"       ;startup music
welmus0
welext  db "w.swx",0


;### WELBEG -> starts welcome music
welbegh db 0,0  ;handler ID, type (0=psg, 1=opl4)

welbeg  ld a,(cfgflgwel)
        or a
        ret z
        ld a,(cfgdvcprf)
        ld (welbegh+1),a
        or a
        jr nz,welbeg1

        ld de,256*1+1           ;*** psg music
        ld a,(App_BnkNum)
        ld hl,welmus
        ld bc,welmus0-welmus
        call muslod0
        ret c
        ld (welbegh),a
        ld l,0                  ;start music
        call musrst
        ld hl,50*5
        jr welbeg2

welbeg1 ld hl,0                 ;*** opl4 effect
        ld de,-6
        add hl,de
        ex de,hl
        push de
        ld hl,welext
        ld bc,6
        ldir                    ;modify temp config path
        ld hl,cfgpthstr
        ld a,(App_BnkNum)
        db #dd:ld h,a
        call SyFile_FILOPN      ;open file
        pop de
        ld hl,cfgpthfil1
        ld bc,6
        ldir                    ;restore config path
        ret c
        ld de,256*2+0
        push af
        call efxlod0
        ld (welbegh),a
        pop bc
        ld a,b
        jp c,SyFile_FILCLO
        call SyFile_FILCLO
        ld a,(welbegh)
        ld hl,256*255+0
        ld bc,256*1+128
        ld de,0
        call efxply
        ld hl,50*5

welbeg2 ld (welcnt),hl          ;activate timer counter
        ld hl,(prgtim0)
        ld (welend1+1),hl
        di
        ld hl,0
        ld (prgtim0),hl
        ei
        ret

;### WELEND -> ends and removes welcome music
welend  ld hl,(welbegh)         ;stop music
        ld a,l
        dec h
        push af
        call nz,musfre
        pop af
        call z,efxfrex
welend1 ld hl,0                 ;stop timer counter
        ld (prgtim0),hl
        ret


;==============================================================================
;### DESKTOP MANAGER COMMUNICATION ############################################
;==============================================================================

;### DSKONL -> set sound daemon online for desktop manager
dskonl  ld a,(App_PrcID)
        ld d,a
        ld e,1
        jp SyDesktop_SNDDEM

;### DSKOFF -> set sound daemon offline for desktop manager
dskoff  ld e,0
        jp SyDesktop_SNDDEM


;==============================================================================
;### DEVICE DETECTION #########################################################
;==============================================================================

dvcsta  db 0    ;+1=PSG available, +2=OPL4 available

;### DVCDET -> detects available sound devices
;### Output     (dvcsta) set
dvcdet  call op4det
        ld a,1
        jr c,dvcdet1
        ld hl,(op4_64kbnk-1)
        ld e,64
        call clcmu8
        push hl:pop ix
        ld iy,gentxtd02a
        ld e,4
        call clcnum
        ld (iy+1),"K"
        ld (iy+2),")"
        ld (iy+3),0
        ld a,3
dvcdet1 ld (dvcsta),a
        ret

;### DVCEXS -> checks, if required device is available
;### Input      D=device (1=PSG, 2=OPL4)
;### Output     ZF=0 -> device not available, CF=1, A=errorcode
;### Destroyed  AF
dvcexs  ld a,(dvcsta)
        and d
        cp d
        scf
        ld a,snderrdvc
        ret


;==============================================================================
;### DEVICE DRIVER ROUTINES (PSG) #############################################
;==============================================================================

psgply  db 0    ;flag, if PSG music is playing


;### PSGMIN -> resets PSG music to the beginning
;### Input      A=subsong (0-255)
;### Destroyed  AF,BC,DE,HL,IX,IY
psgmin  ld hl,snddatmem+4
        jp PLY_AKG_INIT

;### PSGMPL -> starts playing PSG music
;### Destroyed  AF,BC,DE,HL
psgmpl  di
        ld hl,PLY_AKG_CHANNEL1_SOUNDEFFECTDATA:ld (psgfrm0+1),hl
        ld hl,PLY_AKG_CHANNEL2_SOUNDEFFECTDATA:ld (psgfrm1+1),hl
        ld hl,PLY_AKG_CHANNEL3_SOUNDEFFECTDATA:ld (psgfrm2+1),hl
        xor a
        call PLY_AKG_STOPSOUNDEFFECTFROMCHANNEL
        ld a,1
        ld (psgply),a
        call PLY_AKG_STOPSOUNDEFFECTFROMCHANNEL
        ld a,2
        call PLY_AKG_STOPSOUNDEFFECTFROMCHANNEL
        ei
        ret

;### PSGSTP -> pauses the music and mutes the PSG
;### Destroyed  AF,BC,DE,HL
psgstp  di
        ld hl,PLY_SE_CHANNEL1_SOUNDEFFECTDATA:ld (psgfrm0+1),hl
        ld hl,PLY_SE_CHANNEL2_SOUNDEFFECTDATA:ld (psgfrm1+1),hl
        ld hl,PLY_SE_CHANNEL3_SOUNDEFFECTDATA:ld (psgfrm2+1),hl
        xor a:ld (psgply),a
               call PLY_AKG_STOPSOUNDEFFECTFROMCHANNEL
        ld a,1:call PLY_AKG_STOPSOUNDEFFECTFROMCHANNEL
        ld a,2:call PLY_AKG_STOPSOUNDEFFECTFROMCHANNEL
        exx
        ex af,af'
        push af
        push bc
        push de
        push hl
        call PLY_AKG_STOP
        pop hl
        pop de
        pop bc
        pop af
        ex af,af'
        exx
        ei
        ret

;### PSGXIN -> inits PSG sound effect collection
;### Input      HL=sound effect data (relocateable)
;### Destroyed  AF,BC,DE,HL,IX
psgxin  jp psgrel

;### PSGXPL -> starts a PSG sound effect
;### Input      HL=sound effect data, A=sound effect number (0-255), B=volume (0=loud, 16=silent), C=channel (0-2)
;### Destroyed  AF,BC,DE,HL
psgxpl  ex de,hl
        ld l,a
        ld a,(cfgefxvol)            ;don't play effects, if mute
        or a
        ret z
        ld a,c
        sub 1
        ld a,l
        ld hl,PLY_AKG_VOLTYP_A
        jr c,psgxpl2
        ld hl,PLY_AKG_VOLTYP_B
        jr z,psgxpl2
        ld hl,PLY_AKG_VOLTYP_C
psgxpl2 ld (hl),#50 ;ld d,b
        ex de,hl

        ld de,4
        add hl,de
        ld e,a
        ld a,(psgply)
        or a
        jr nz,psgxpl1
        di
        ex af,af'
        push af
        call PLY_SE_PLAYSOUNDEFFECT+7   ;** on playerchange check this! **
        pop af
        ex af,af'
        ei
        ret
psgxpl1 di
        ex af,af'
        push af
        call PLY_AKG_PLAYSOUNDEFFECT+7  ;** on playerchange check this! **
        pop af
        ex af,af'
        ei
        ret

;### PSGFRM -> plays one PSG music frame
;### Destroyed  AF,BC,DE,HL,IX,IY
psgfrm
psgfrm0 ld hl,(PLY_SE_CHANNEL1_SOUNDEFFECTDATA)
        ld a,l:or h
        jr nz,psgfrm1
        ld hl,psgchnmem+0
        cp (hl)                                 ;no effect -> was already off?
        jr z,psgfrm1
        ld (hl),a                               ;no -> turn off
        db #3e:ld d,c:ld (PLY_AKG_VOLTYP_A),a   ;      set volume lookup back to music
        xor a
psgfrm1 ld hl,(PLY_SE_CHANNEL2_SOUNDEFFECTDATA)
        ld c,a
        ld a,l:or h
        jr nz,psgfrm2
        ld hl,psgchnmem+2
        cp (hl)                                 ;no effect -> was already off?
        jr z,psgfrm2
        ld (hl),a                               ;no -> turn off
        db #3e:ld d,c:ld (PLY_AKG_VOLTYP_B),a   ;      set volume lookup back to music
        xor a
psgfrm2 ld hl,(PLY_SE_CHANNEL3_SOUNDEFFECTDATA)
        or c:ld c,a
        ld a,l:or h
        jr nz,psgfrm3
        ld hl,psgchnmem+4
        cp (hl)                                 ;no effect -> was already off?
        jr z,psgfrm3
        ld (hl),a                               ;no -> turn off
        db #3e:ld d,c:ld (PLY_AKG_VOLTYP_C),a   ;      set volume lookup back to music
        xor a
psgfrm3 or c:ld c,a
        ld a,(psgply)
        or a
        jr z,psgfrm4
        di                  ;* play music and optional effects
        exx
        ex af,af'
        push af
        push bc
        push de
        push hl
        call PLY_AKG_PLAY
if PLATFORM_TYPE=PLATFORM_EPR
        call envelopeInterrupt
endif
        pop hl
        pop de
        pop bc
        pop af
        ex af,af'
        exx
        ei
        ret
psgfrm4 inc c:dec c
        ret z               ;* no music and no effects
        di                  ;* play effects only
        exx
        ex af,af'
        push af
        push bc
        push de
        push hl
        call PLY_SE_PLAYSOUNDEFFECTSSTREAM
if PLATFORM_TYPE=PLATFORM_EPR
        call envelopeInterrupt
endif
        pop hl
        pop de
        pop bc
        pop af
        ex af,af'
        exx
        ei
        ret


;==============================================================================
;### MUSIC HANDLING ###########################################################
;==============================================================================

;### MUSCHK -> check, if correct handle is used
;### Input      A=handle
;### Output     CF=1 error (wrong handle or no music loaded)
;###            CF=0 -> Z=PSG, NZ=OPL4
;### Destroyed  AF,HL
muschk  ld hl,mushnd
        cp (hl)
        scf
        ret nz
muschk0 ld a,(mussta)
        sub 1
        ret


;==============================================================================
;### VARIABLES ################################################################
;==============================================================================

sndprcnum   db 0    ;client process ID

mussta      db 0    ;0=no music loaded, 1=PSG music loaded, 2=OPL4 music loaded
mushnd      db 0    ;current music handle
efxdatusd   dw 0    ;current used effect data memory
musdatusd   dw 0    ;current used music  data memory

;### PSG channel usage
psgchnhnd   equ 0   ;effect handle+1 (0=free)
psgchnxid   equ 1   ;effect ID
psgchnlen   equ 2
psgchnmax   equ 3
psgchnmem   ds psgchnmax*psgchnlen

;### OPL4 channel usage
op4chncur   db 1
op4chnmem   ds 20*2,-1 ;handle, ID
op4pantab   db 09,10,11,12,13,14,15,00,00,01,02,03,04,05,06,07

;### Effect handles
efxhnddvc   equ 0   ;0=unused, 1=psg, 2=opl4
efxhndnum   equ 1   ;*res*
efxhndadr   equ 2   ;high-adr in efx memory (low=0)
efxhndsiz   equ 3   ;high-size of efx data  (low=0)
efxhndlen   equ 4
efxhndmax   equ 8
efxhndmem   ds efxhndmax*efxhndlen

;### OPL4 sample data
smpop4adr   equ 0   ;sample address in OPL4 memory (bit 8-21)
smpop4siz   equ 2   ;sample size
smpop4rep   equ 4   ;sample repeat offset
smpop4vol   equ 6   ;swm -> volume (0-64)       | swx -> opl4 ID
smpop4fin   equ 7   ;swm -> finetune (-8 -> +7) | swx -> note (0-35; 12=default)
smpop4len   equ 8

;### OPL4 pointers
op4smpadr   dw 0    ;sample record start
op4patadr   dw 0    ;pattern data start
op4lstadr   dw 0    ;song list start
op4lstsng   dw 0    ;song list start (for subsong)
op4lstlen   db 0    ;song list length (for subsong)

SWM_NUMSMP  equ 0
SWM_NUMPAT  equ 1
SWM_NUMCHN  equ 2
SWM_SNGLST  equ 16


;### EFXHND -> get handle data record and type
;### Input      A=handle
;### Output     HL=data record, 
;###            CF=1 -> unknown handle
;###            CF=0 -> ZF=1 -> PSG, ZF=0 -> OPL4
;### Destroyed  AF,DE
efxhnd  add a:add a
        ld e,a
        ld d,0
        ld hl,efxhndmem
        add hl,de
        ld a,(hl)
        sub 1
        ret


;==============================================================================
;### SERVICE ROUTINES #########################################################
;==============================================================================

;### SNDINF -> returns information about available and preferred sound hardware
;### Sends      A=hardware flags (+1=psg  available, +2=opl4 available),
;###            L=preferred hardware (0=no hardware available, 1=psg, 2=opl4),
sndinf  ld a,(dvcsta)
        ld l,a
        or a
        jp z,msgsnd
        ld hl,(genctrdls+12)
        inc l
        jp msgsnd

;### MUSLOD -> Loads and inits a music collection
;### Input      D=Device (1=PSG, 2=OPL4),
;###            E=Source type (0=file, 1=memory [for PSG only])
;###            - if E is 0
;###            A=File handle
;###            - if E is 1
;###            A=Bank (1-15), HL=Address, BC=Length
;### Sends      CF=Error state (0=ok, 1=error; A=error code)
;###            - if CF is 0
;###            A=handle
muslod  push af
        ld a,(cfgmusoff)
        or a
        jr z,muslod8
        pop af
        ld a,snderruse
        scf
        jp msgsnd0              ;error -> no music allowed
muslod8 pop af
        call muslod0
        jp msgsnd0              ;send result message to process

muslod0 inc e:dec e
        jr nz,musloda
        ld b,"M"
        call filchk
        ret c
musloda ;...check length ##!!##
        ld ixl,a
        call muschk0
        ccf
        ld a,snderruse
        ret c                   ;error -> music already in use
        call dvcexs
        ret nz                  ;error -> required device is not available
        ld (muslod7+1),bc
        dec d
        jr nz,muslod3

        dec e                       ;*** PSG
        jr nz,muslod1
        ld a,(App_BnkNum)           ;*** PSG from memory
        add a:add a:add a:add a
        add ixl
        ld de,snddatmem
        rst #20
        dw jmp_bnkcop           ;copy from memory
        jr muslod2
muslod1 ld a,(App_BnkNum)           ;*** PSG from file
        ld e,a
        ld a,ixl
        ld hl,snddatmem
        rlc b:srl b
        call SyFile_FILCPR      ;load from file
        ld a,snderrfil
        ret c
muslod2 ld hl,snddatmem
        call psgrel             ;relocate PSG music
        xor a
        call psgmin             ;init PSG music (restart subsong 0)
        ld a,1
muslod7 ld hl,0                 ;store music cpu memory length
        res 7,h
        ld (musdatusd),hl
        ld (mussta),a           ;music loaded
        ld a,255
        call musvol0            ;reset volume to max
        ld a,r
        add 1       ;255 -> cf=1
        sbc 1       ;cf=1, 0 -> 254 -> a will never be -1
        ld (mushnd),a           ;set music handle
        push af
        call memupd
        pop af
        or a
        ret

muslod3 ld a,(App_BnkNum)           ;*** OPL4
        ld e,a
        ld a,ixl
        ld hl,snddatmem
        push af
        rlc b:srl b
        call SyFile_FILCPR      ;load from file
        pop bc
        ld a,snderrfil
        ret c
        push bc
        ld de,0                 ;** calculate pointers
        ld hl,snddatmem
        ld bc,SWM_SNGLST
        add hl,bc
        ld a,32
muslod4 ld c,(hl)
        inc hl
        ex de,hl
        add hl,bc
        ex de,hl
        dec a
        jr nz,muslod4           ;de=global songlist length
        ld bc,snddatmem
        ld hl,48
        add hl,bc
        ld (op4lstadr),hl       ;hl=global songlist adr
        add hl,de
        ld (op4smpadr),hl       ;hl=sample record adr
        ex de,hl
        ld a,(snddatmem+SWM_NUMSMP)
        add a:add a
        ld l,a
        ld h,0
        add hl,hl               ;hl=number of samples * 8
        add hl,de
        ld (op4patadr),hl       ;hl=pattern data adr
        ld ix,(snddatmem+SWM_NUMPAT)    ;ixl=numpat, ixh=numchn
        ld bc,snddatmem         ;update channel adr in pattern data
        ld c,b
muslod5 ld b,ixh
muslod6 inc hl
        ld a,(hl)
        add c
        ld (hl),a
        inc hl
        djnz muslod6
        dec ixl
        jr nz,muslod5
        pop af
        call smpall             ;load all samples
        xor a
        call op4min             ;init OPL4 music (restart subsong 0)
        ld a,2
        jp muslod7

;### MUSFRE -> Removes a music collection
;### Input     A=handle
musfre  call muschk
        ret c
        ld a,0
        ld (mussta),a
        ld l,a
        ld h,a
        ld (musdatusd),hl
        jr nz,musfre1
        call psgstp
        jp memupd
musfre1 call op4stp
        call smprem
        jp memupd

;### MUSRST -> Starts playing music from the beginning
;### Input     A=handle, L=subsong ID
musrst  ld e,l
        call muschk
        ret c
        ld a,e
        jr nz,musrst1
        call psgmin         ;** PSG
        jp psgmpl
musrst1 call op4min         ;** OPL4
        jp op4mpl

;### MUSCON -> Continues playing the current music
;### Input     A=handle
muscon  call muschk
        ret c
        jp z,psgmpl         ;** PSG
        jp op4mpl           ;** OPL4

;### MUSSTP -> Pauses and mutes music
;### Input     A=handle
musstp  call muschk
        ret c
        jp z,psgstp         ;** PSG
        jp op4stp           ;** OPL4

;### MUSVOL -> sets music volume
;### Input      A=handle, H=volume (0-255)
musvols dw 255

musvol  ex de,hl
        call muschk
        ret c
        ld a,d
musvol0 ld (musvols),a
        ld c,0
        ld a,(cfgmusvol)
        jp cfgvol


;### EFXLOD -> Loads and inits an effect collection
;### Input      D=Device (1=PSG, 2=OPL4),
;###            E=source type (0=file, 1=memory [for PSG only])
;###            - if E is 0
;###            A=File handle
;###            - if E is 1
;###            A=Bank (1-15), HL=Address, BC=Length
;### Sends      CF=Error state (0=ok, 1=error; A=error code)
;###            - if CF is 0
;###            A=handle
efxlod  call efxlod0
        jp msgsnd0              ;send result message to process

efxlod0 inc e:dec e
        jr nz,efxloda
        ld b,"X"
        call filchk
        ret c
efxloda ld ixl,a
        call dvcexs
        ret nz                  ;error -> required device is not available
        push hl
        push bc
        ld hl,(efxdatusd)       ;check, if enough data free
        res 7,b
        add hl,bc
        ld bc,efxdatsiz
        sbc hl,bc
        jr c,efxlod1
        jr nz,efxlod3           ;error -> no free data, cpu memory full
efxlod1 ld iy,efxhndmem         ;find free handle
        ld bc,efxhndlen
        ld ixh,efxhndmax
efxlod2 ld a,(iy+efxhnddvc)
        or a
        jr z,efxlod4
        add iy,bc
        dec ixh
        jr nz,efxlod2
efxlod3 ld a,snderrmem          ;error -> no free handle, cpu memory full
        pop bc
        pop hl
        scf
        ret
efxlod4 ld a,efxhndmax          ;free handle found
        sub ixh
        ld (efxlod8+1),a        ;remember handle
        ld hl,(efxdatusd)
        ld bc,snddatmem
        add hl,bc
        ld bc,musdatsiz
        add hl,bc
        ld (iy+efxhndadr),h     ;store address and length
        pop hl
        push hl
        res 7,h
        inc l:dec l             ;round up size to 256
        jr z,efxlod9
        ld l,0
        inc h
efxlod9 ld (iy+efxhndsiz),h
        ld (efxlod7+1),hl       ;remember round up size
        pop bc
        pop hl 
        dec d
        jr nz,efxlodb
        push iy                     ;*** PSG
        dec e
        jr nz,efxlod5
        ld a,(App_BnkNum)           ;*** PSG from memory
        add a:add a:add a:add a
        add ixl
        ld e,0
        ld d,(iy+efxhndadr)
        push de
        rst #20
        dw jmp_bnkcop   ;copy from memory
        or a
        jr efxlod6
efxlod5 ld a,(App_BnkNum)           ;*** PSG from file
        ld e,a
        ld a,ixl
        ld l,0
        ld h,(iy+efxhndadr)
        push hl
        rlc b:srl b
        call SyFile_FILCPR      ;load from file
        ld a,snderrfil
efxlod6 pop de
        pop hl
        ret c
        ld (hl),1               ;effect handle in use for PSG
        ex de,hl
        call psgrel             ;relocate PSG effects
efxlod7 ld bc,0
        ld hl,(efxdatusd)
        add hl,bc
        ld (efxdatusd),hl       ;update used efx data
        call memupd
efxlod8 ld a,0                  ;return handle
        or a
        ret
efxlodb ld a,(App_BnkNum)           ;*** OPL4 from file
        ld e,a
        ld a,ixl
        ld l,0
        ld h,(iy+efxhndadr)
        push iy
        push hl
        push af
        rlc b:srl b
        call SyFile_FILCPR      ;load from file
        pop bc
        pop de
        pop hl
        ld a,snderrfil
        ret c
        push hl
        ex de,hl
        ld a,b
        call smpefx             ;load samples
        pop hl
        ret c
        ld (hl),2               ;effect handle in use for OPL4
        jr efxlod7

;### EFXFRE -> Removes an effect collection
;### Input     A=handle
efxfre  or a
        ret z                   ;don't remove system sounds
efxfrex push af
        ;stop all effects
        pop af
        call efxhnd
        ret c
        ld (hl),0
        push hl:pop ix
        jr z,efxfre0
        ld h,(ix+efxhndadr)
        ld l,0
        push ix
        call smpefr             ;remove opl4 samples
        pop ix
efxfre0 ld hl,(efxdatusd)       ;** calculate following data
        ld b,(ix+efxhndsiz)
        xor a
        ld c,a
        ld a,h                  ;a=used
        sbc hl,bc
        ld (efxdatusd),hl
        sub b                   ;a=used-len
        sub (ix+efxhndadr)      ;a=used-len-adr
        add musdatsiz/256
        ld hl,snddatmem
        add h                   ;a=used-len-adr+start
        jp z,memupd
        ld b,a                  ;** move following data
        ld a,(ix+efxhndadr)
        ld d,a
        ld e,c
        add (ix+efxhndsiz)
        ld h,a
        ld l,c
        ldir
        ld b,efxhndmax          ;** relocate following data
        ld c,(ix+efxhndadr)
        ld a,(ix+efxhndsiz)
        neg
        ld ixh,a                ;ixh=dif=-len
        ld iy,efxhndmem
efxfre1 ld a,(iy+efxhnddvc)
        dec a
        jr nz,efxfre2           ;handle not PSG -> skip
        ld a,(iy+efxhndadr)
        cp c
        jr c,efxfre2            ;data below address -> skip
        add ixh
        ld (iy+efxhndadr),a
        push bc
        ld h,a
        ld l,0
        call psgrel0            ;relocate effect data
        pop bc
efxfre2 ld de,efxhndlen
        add iy,de
        djnz efxfre1
        jp memupd

;### EFXEVT -> Starts playing an event
;### Input      (App_MsgBuf+01)=Event ID (0-31)
efxevt  ld a,(App_MsgBuf+01)
        add a
        ld c,a
        ld b,0
        ld hl,cfgsndevt
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
efxevt0 sub 1
        ret c
        ld l,a
        ld a,(efxhnddvc+efxhndmem)
        dec a
        ld bc,256*4+1
        jr z,efxevt1
        ld bc,256*1+128
efxevt1 xor a
        ld de,0
;### EFXPLY -> Starts playing an effect
;### Input     A=handle, L=Effect ID, H=Volume (0-255 [0=quiet, 255=loud])
;###
;###           - if device is PSG:
;###           B=Priority type
;###             1 -> play always on specified channel
;###             2 -> play only, if specified channel is free
;###             3 -> play always on rotating channel
;###             4 -> play only, if one rotating channel is free
;###             5 -> play only, if no other active effect at all
;###           - if device is PSG and priority type is 1, 2 or 5:
;###           C=Channel (0-2)
;###
;###           - if device is OPL4:
;###           B=Priority type
;###             1 -> play
;###             2 -> play, first stop same effects of same handle
;###             3 -> play, first stop all other effects of same handle
;###           C=Panning (0-255 [0=left, 255=right])
;###           DE=Pitch (0=use standard)
efxply  ld ixl,a
        ld (efxplyc+1),de
        push hl
        call efxhnd
        jr c,efxply8
        jr nz,efxply9
        push hl                 ;*** PSG
        ld a,b
        cp 5
        jr z,efxply5        ;prio 5 -> only play on preferred channel, if no active effect
        ld a,(cfgpsgxfc)
        or a
        jr z,efxply3        ;user forced channel -> use preferred channel
        ld a,b
        sub 3
        ld a,c
        jr c,efxply4        ;player forced channel -> use channel in A
        ld a,(cfgpsgxpc)
        call efxply2        ;a=preferred channel, hl=channel record
        ld c,3
efxply1 inc (hl):dec (hl)   ;check, if channel is free
        jr z,efxply4        ;yes, use channel in A
        dec c
        jr z,efxply3        ;no more channels -> use preferred channel
        inc a
        inc hl:inc hl       ;try next channel
        cp 3
        jr c,efxply1
        xor a               ;3 -> restart at 0
        ld hl,psgchnmem
        jr efxply1
efxply2 ld l,a              ;a=channel -> hl=record
        ld h,0
        add hl,hl
        ld de,psgchnmem
        add hl,de
        ret
efxply3 ld a,(cfgpsgxpc)    ;use preferred channel
efxply4 call efxply2        ;use channel in A
        bit 0,b
        jr nz,efxply6       ;prio 1,3 -> play always
        inc (hl):dec (hl)
        jr z,efxply6
        pop hl              ;prio 2,4 -> don't play, if active effect on this channel
efxply8 pop hl
        ret
efxply5 ld a,(psgchnmem+0)  ;prio 5 -> don't play, if active effect on any channel
        ld hl,psgchnmem+2
        or (hl)
        ld hl,psgchnmem+4
        or (hl)
        jr z,efxply7
        pop hl
        pop hl
        ret
efxply7 ld a,(cfgpsgxpc)
        call efxply2

efxply6 pop de              ;a=channel, hl=channel record, ixl=handle, de=effect handle record
        pop bc              ;c=effect ID, b=volume
        ld ixh,a
        ld a,ixl
        inc a
        ld (hl),a           ;store handle+1 and effect ID in channel record
        inc hl
        ld (hl),c
        ex de,hl            ;hl=effect handle record
        inc hl:inc hl
        ld h,(hl)
        ld l,0          ;hl=sound effect data
        ld a,b              ;a=volume (0-255)
        cpl                 ;a=255 - 0
        and #f0             ;a=15*16 - 0
        rrca:rrca:rrca:rrca ;a=15-0
        ld b,a          ;b=at2 volume
        ld a,c          ;a=effect ID
        ld c,ixh        ;c=channel
        jp psgxpl

;hl=handle data record (sp)=id/volume, bc=prio,panning, ixl=handle
efxply9 dec b                       ;*** OPL4
        jr z,efxplyf

        pop de              ;e=effect ID
        push de
        push bc
        push hl
        dec b
        jr z,efxplyg
        ld e,-1             ;all effects -> id=-1
efxplyg ld b,e              ;b=id
        ld c,ixl            ;c=handle
        call efxstp3
        pop hl
        pop bc

efxplyf inc hl:inc hl
        ld d,(hl)
        ld e,1+smpop4vol    ;de=opl4 effect data offset
        pop hl
        ld a,l
        ld ixh,a            ;ixh=effect ID
        ld a,h              ;a=volume
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld e,(hl)           ;e=opl4 sample ID
        inc a
        jr nz,efxplyb
        ld a,64
        jr efxplye
efxplyb srl a:srl a
efxplye ld d,a              ;d=volume (0-64)
        inc hl
        ld a,(hl)
        or a
        jr nz,efxplyj
        ld a,107
efxplyj ld (efxplyh+1),a    ;e=default pitch/4

        ld a,c              ;a=panning (0-255)
        rrca:rrca:rrca:rrca
        and #0f
        ld c,a
        ld b,0
        ld hl,op4pantab
        add hl,bc
        ld c,e              ;c=opl4 sample ID
        ld e,(hl)           ;e=panning
        ld hl,op4chncur
        dec (hl)
        jr nz,efxplyd
        ld (hl),20
efxplyd ld a,(hl)

        ld l,a
        dec l               ;l=channel (0-19)
        ld h,0
        add hl,hl
        push bc
        ld bc,op4chnmem
        add hl,bc           ;hl=channel table
        ld c,ixl
        ld (hl),c           ;store handle
        inc hl
        ld c,ixh
        ld (hl),c           ;store ID
        pop bc

        add 3
        ld b,a              ;b=channel (4-23)
efxplyc ld hl,0             ;hl=pitch/0
        ld a,l
        or h
        jr nz,efxplyi
efxplyh ld hl,0             ;no pitch -> use sample default
        add hl,hl
        add hl,hl
efxplyi ld a,b
        jp op4xpl           ;C=opl4 sample ID (64-255), HL=amiga pitch (108-), A=channel (4-23), D=volume (0=silent, 64=loud), E=panning (0-15)

;### EFXSTP -> Stops all effects with a specified ID
;### Input     A=handle, L=Effect ID (-1=all effects)
efxstp  ld c,a
        ld b,l
        call efxhnd
        ret c
        jr nz,efxstp3

        ld e,3              ;*** PSG
        ld hl,psgchnmem
        inc c
efxstp1 push bc
        ld a,(hl)
        inc hl
        cp c
        jr nz,efxstp2
        inc b
        jr z,efxstp0
        dec b
        ld a,(hl)
        cp b
        jr nz,efxstp2
efxstp0 dec hl      ;*could be removed
        ld (hl),0   ;*
        inc hl      ;*
        push de
        push hl
        ld a,3
        sub e
        call PLY_AKG_STOPSOUNDEFFECTFROMCHANNEL
        pop hl
        pop de
efxstp2 pop bc
        inc hl
        dec e
        jr nz,efxstp1
        ret

efxstp3 ld hl,op4chnmem     ;*** OPL4
        ld e,b          ;e=effect id, c=handle
        inc b
        ld b,20
        jr z,efxstp6
efxstp4 ld a,(hl)       ;stop effect id
        inc hl
        cp c
        jr nz,efxstp5
        ld a,(hl)
        cp e
        jr nz,efxstp5
        dec hl
        call efxstp7
efxstp5 inc hl
        djnz efxstp4
        ret
efxstp6 ld a,(hl)       ;stop all
        cp c
        call z,efxstp7
        inc hl
        djnz efxstp6
        ret
efxstp7 ld (hl),-1      ;mute channel
        ld a,24
        sub b
        ld (channel),a
        push bc
        push de
        push hl
        call op4kof
        pop hl
        pop de
        pop bc
        inc hl
        ret


;### RMTACT -> activate remote playing
;### Input      -
;### Sends      A=Bank (1-15), HL=routine address, BC=stack
rmtact  ld a,(prgprztab+0)      ;removes timer
        call SyKernel_MTDELT
        ld a,(App_BnkNum)
        ld hl,rmtply
        ld bc,prgtims
        or a
        jp msgsnd2              ;return routine information

;### RMTDCT -> deactivates remote playing
rmtdct  ld hl,prgtims           ;starts timer again
        ld a,(App_BnkNum)
        call SyKernel_MTADDT
        jp c,prgend1
        ld (prgprztab+0),a
        ret

;### RMTPLY -> plays one remote frame
rmtply  call psgfrm
        jp jmp_bnkret


;==============================================================================
;### MESSAGE HANDLING #########################################################
;==============================================================================

;### MSGCMD -> execute sound command
;### Input      (sndprcnum)=process ID, (App_MsgBuf)=data
;### Output     [process receives answer]
;### Destroyed  AF,BC,DE,HL,IX,IY
msgcmdtab
dw 000000,sndinf,000000,000000,000000,000000,rmtact,rmtdct  ;general (00-07)
dw muslod,musfre,musrst,muscon,musstp,musvol,000000,000000  ;music   (08-15)
dw efxlod,efxfre,efxply,efxstp,000000,000000,000000         ;effects (16-22, 23=efxevt)

msgcmd  ld a,(App_MsgBuf+00)
        cp 23
        jp z,efxevt
        ret nc
        add 128
        ret c
        ld (msgsnd1+1),a
        add a
        ld l,a
        ld h,0
        ld bc,msgcmdtab
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        or h
        ret z
        ld (msgcmd1+1),hl
        ld hl,(App_MsgBuf+02)
        push hl
        pop af
        ld bc,(App_MsgBuf+04)
        ld de,(App_MsgBuf+06)
        ld hl,(App_MsgBuf+08)
msgcmd1 jp 0

;### MSGSND -> send reply to process
;### Input      (sndprcnum)=process ID
;###            AF[,HL]=registers
;### Destroyed  AF,BC,DE,HL,IX,IY
msgsnd2 ld (App_MsgBuf+04),bc
msgsnd  ld (App_MsgBuf+08),hl
msgsnd0 push af
        pop hl
        ld (App_MsgBuf+02),hl
msgsnd1 ld a,0
        ld (App_MsgBuf+00),a
        ld iy,App_MsgBuf
        ld a,(App_PrcID)
        db #dd:ld l,a
        ld a,(sndprcnum)
        db #dd:ld h,a
        rst #10
        ret


;==============================================================================
;### SETTINGS #################################################################
;==============================================================================

;### Device selected
setdvc  ld a,(genctrdls+12)
        ld (cfgdvcprf),a
        call setdvc0
        jp prgprz0
setdvc0 ld ix,stawindatc1
        ld de,16
        ld b,3
        dec a
        ld hl,256*64+0
        jr nz,setdvc1
        ld hl,256*0+64
setdvc1 ld a,(ix+02):and 63:or l:ld (ix+02),a
        ld a,(ix+50):and 63:or h:ld (ix+50),a
        add ix,de
        djnz setdvc1
        ret

;### Effect mute
setxmt  ld ix,genctrsfx
        ld hl,cfgefxvol
        ld c,1
        ld e,10
setxmt1 ld a,(ix+8)
        sub 1
        sbc a
        ld (hl),a
        scf
        call cfgvol
        cpl
        ld (ix+2),a
        jr setxvl2

;### Music mute
setmmt  ld ix,genctrsms
        ld hl,cfgmusvol
        ld c,0
        ld e,15
        jr setxmt1

;### Effect volume
setxvl  ld ix,genctrsfx
        ld hl,cfgefxvol
        ld c,1
        ld e,9
setxvl1 ld a,(ix+2)
        cpl
        ld (hl),a
        scf
        call cfgvol
        sub 1   ;mute -> cf=1
        sbc a   ;mute -> a=255
        neg     ;mute -> a=1
        ld (ix+8),a
setxvl2 ld a,(stawin_id)
        call SyDesktop_WININH
        jp prgprz0

;### Music volume
setmvl  ld ix,genctrsms
        ld hl,cfgmusvol
        ld c,0
        ld e,14
        jr setxvl1

;### Event selected
setevt  ld hl,(sysctrevt+12)
        add hl,hl
        add hl,hl
        ld bc,sysctrevt_rec
        add hl,bc
        ld l,(hl)
        ld h,0
        add hl,hl
        ld bc,cfgsndevt
        add hl,bc
        ld a,(hl)
        ld (sysctrsnd+12),a
        ld e,6
        jr setxvl2

;### Sound selected
setsnd  ld a,(sysctrsnd+12)
        ld hl,(sysctrevt+12)
        add hl,hl
        add hl,hl
        ld bc,sysctrevt_rec
        add hl,bc
        ld l,(hl)
        ld h,0
        add hl,hl
        ld bc,cfgsndevt
        add hl,bc
        ld (hl),a
        jp prgprz0

;### Sound test
settst  ld a,(sysctrsnd+12)
        ld hl,(sysctrevt+12)
        add hl,hl
        add hl,hl
        ld bc,sysctrevt_rec
        add hl,bc
        ld l,(hl)
        ld h,0
        add hl,hl
        ld bc,cfgsndevt+1
        add hl,bc
        ld h,(hl)
        call efxevt0
        jp prgprz0

;### Sound Volume
setsvl  ld hl,(sysctrevt+12)
        add hl,hl
        add hl,hl
        ld bc,sysctrevt_rec
        add hl,bc
        ld l,(hl)
        ld h,0
        add hl,hl
        ld bc,cfgsndevt+1
        add hl,bc
        push hl
        ld a,(hl)
        ld ix,volmendat+2+8
        ld de,8
        ld b,e
setsvl1 res 1,(ix+0)
        cp (ix+4)
        jr nz,setsvl2
        set 1,(ix+0)
setsvl2 add ix,de
        djnz setsvl1
        ld a,(App_Bnknum)
        ld de,volmendat
        ld hl,-1
        call SyDesktop_MENCTX
        ld a,l
        pop hl
        jp c,prgprz0
        ld (hl),a
        jp prgprz0

;### Scheme load
setshl  ld b,0
        ld hl,setshmpth
        call setfpb0
        jp nz,prgprz0
        ld hl,setshmpth+4
        ld bc,64
        ld de,cfgsndevt
        call cfglod1
        jp setevt

;### Scheme save
setshs  ld b,64
        ld hl,setshmpth
        call setfpb0
        jp nz,prgprz0
        ld hl,setshmpth+4
        ld bc,64
        ld de,cfgsndevt
        call cfgsav1
        jp prgprz0

;### Scheme default
setshdd
db 05,128,07,128,06,128,13,128,13,128,11,128,11,128,12,128
db 18,128,11,128,03,128,04,128,03,128,04,128,09,128,04,128
db 15,128   
db        00,128,00,128,00,128,00,128,00,128,00,128,00,128
db 00,128,00,128,00,128,00,128,00,128,00,128,00,128,00,128

setshd  ld a,(App_BnkNum)
        ld hl,prgmsgshm
        ld b,8*3+2+64
        ld de,stawindat
        call SySystem_SYSWRN
        cp 3
        jp nz,prgprz0
        ld hl,setshdd
        ld de,cfgsndevt
        ld bc,64
        ldir
        jp setevt

;### PSG browse file
setfpb  ld hl,cfgfilpsg
        ld de,"P"*256+9
        ld bc,setctrsip
setfpb1 push bc
        push de
        push hl
        ld a,d
        ld (cfgbrwpth+1),a
        ld de,cfgbrwpth+4
        ld bc,128
        ldir
        ld hl,cfgbrwpth
        ld b,0
        call setfpb0
        pop de
        pop hl
        pop ix
        jp nz,prgprz0
        ld a,l
        ld hl,cfgbrwpth+4
        ld bc,128
        ldir
        ld e,a
        push de
        call strinp
        pop de
        jp setxvl2
setfpb0 ld a,(App_BnkNum)
        add b
        ld c,8
        ld ix,100
        ld iy,5000
        ld de,stawindat
        call SySystem_SELOPN
        or a
        ret

;### OPL4 browse file
setfob  ld hl,cfgfilwav
        ld de,"W"*256+12
        ld bc,setctrsio
        jr setfpb1


;### MEMMUS -> clean-up loaded music
memmus  ld a,(mussta)
        or a
        jp z,prgprz0
        ld a,(App_BnkNum)
        ld hl,prgmsgmmu
        ld b,8*3+2+64
        ld de,stawindat
        call SySystem_SYSWRN
        cp 3
        jp nz,prgprz0
        ld a,(mushnd)
        call musfre
        jp prgprz0

;### MEMEFX -> clean-up all loaded effects
memefx  ld a,(App_BnkNum)
        ld hl,prgmsgmfx
        ld b,8*3+2+64
        ld de,stawindat
        call SySystem_SYSWRN
        cp 3
        jp nz,prgprz0
        ld hl,efxhndmem+efxhndlen
        ld b,efxhndmax-1
memefx1 ld a,(hl)
        or a
        jr z,memefx2
        push bc
        push hl
        ld a,efxhndmax
        sub b
        call efxfre
        pop hl
        pop bc
memefx2 ld de,efxhndlen
        add hl,de
        djnz memefx1
        jp prgprz0


;==============================================================================
;### CONFIG WINDOW ############################################################
;==============================================================================

cfgpthfil   db "sound"
cfgpthfil1  db "d.ini",0
cfgpthfil0
cfgpthfxp   db "spx",0
cfgpthfxw   db "soundd.swx",0

cfgpthstr   ds 256

;### CFGPTH -> Generates config pathes
cfgpth  ld de,cfgfilpsg     ;generate swx at psg path
        ld hl,cfgpthfxw
        call cfgpth0
        ld hl,cfgfilpsg     ;copy psg path to opl4 path
        ld de,cfgfilwav
        ld bc,128
        ldir
        ld hl,(welbeg1+1)
        ld bc,-4
        add hl,bc
        ex de,hl
        ld hl,cfgpthfxp     ;copy spx to psg path
        ld bc,3
        ldir

        ld de,cfgpthstr
        ld hl,cfgpthfil
cfgpth0 push hl
        ld hl,(App_BegCode)
        ld bc,App_BegCode
        dec h
        add hl,bc           ;HL = CodeEnd = path
        ld bc,256
        ldir
        dec d
        ld l,e
        ld h,d
        ld b,255
cfgpth1 ld a,(hl)           ;search end of path
        or a
        jr z,cfgpth2
        inc hl
        djnz cfgpth1
        jr cfgpth4
        ld a,255
        sub b
        jr z,cfgpth4
        ld b,a
cfgpth2 ld (hl),0
        dec hl              ;search start of filename
        call cfgpth5
        jr z,cfgpth3
        djnz cfgpth2
        jr cfgpth4
cfgpth3 inc hl
        ex de,hl
cfgpth4 pop hl              ;replace application filename with config filename
        ld bc,cfgpthfil0-cfgpthfil
        ldir
        ld (welbeg1+1),de
        ret
cfgpth5 ld a,(hl)
        cp "/"
        ret z
        cp "\"
        ret z
        cp ":"
        ret

;### CFGLOD -> load config data
cfglod  call cfgpth
        ld hl,cfgpthstr
        ld de,cfg_beg
        ld bc,cfg_end-cfg_beg
cfglod1 push bc
        push de
        ld a,(App_BnkNum)
        db #dd:ld h,a
        call SyFile_FILOPN          ;open file
        pop hl
        pop bc
        ret c
        ld de,(App_BnkNum)
        push af
        call SyFile_FILINP          ;load configdata
        pop af
        jp SyFile_FILCLO            ;close file

;### CFGSAV -> save config data
cfgsav  ld hl,cfgpthstr
        ld de,cfg_beg
        ld bc,cfg_end-cfg_beg
cfgsav1 push bc
        push de
        ld a,(App_BnkNum)
        db #dd:ld h,a
        xor a
        call SyFile_FILNEW          ;open file
        pop hl
        pop bc
        ret c
        ld de,(App_BnkNum)
        push af
        call SyFile_FILOUT          ;save configdata
        pop af
        jp SyFile_FILCLO            ;close file

;### CFGINI -> prepare config settings
cfgini  ld a,(cfgflghid)            ;hide on startup
        add a
        inc a
        ld (stamendat1a),a
        ld a,(cfgdvcprf)            ;preferred device
        ld (genctrdls+12),a
        call setdvc0
        ld a,(cfgefxvol)            ;volume/mute
        cpl
        ld (genctrsfx+2),a
        add 1
        sbc a
        neg
        ld (genctrsfx+8),a
        ld a,(cfgmusvol)
        cpl
        ld (genctrsms+2),a
        add 1
        sbc a
        neg
        ld (genctrsms+8),a
        ld a,(cfgmusvol)            ;volume lookup
        ld c,0
        or a
        call cfgvol
        ld a,(cfgefxvol)
        ld c,1
        or a
        call cfgvol
        ld a,(cfgsndevt+0)          ;sound scheme
        ld (sysctrsnd+12),a
        ld ix,setctrsip             ;sound file
        call strinp
        ld ix,setctrsio
        call strinp
        ld a,(dvcsta)
        bit 1,a
        jr nz,cfgini1
        xor a                       ;no opl4 available -> overwrite settings
        ld (genctrdls+12),a
        ld (cfgdvcprf),a
        call setdvc0
        ld a,1
        ld (genctrdls+0),a
cfgini1 ld hl,snddatmem
        ld bc,musdatsiz-1024-16
        add hl,bc
        ld (patadr2+1),hl
        ld bc,16
        add hl,bc
        ld (patadr6+1),hl
;### CFGSND -> load system sound effects
cfgsnd  ld a,(cfgdvcprf)
        or a
        ld hl,cfgfilpsg
        jr z,cfgsnd1
        ld hl,cfgfilwav
cfgsnd1 ld a,(App_BnkNum)
        db #dd:ld h,a
        call SyFile_FILOPN          ;open file
        jr c,cfgsnd3
        ld de,(cfgdvcprf-1)
        inc d
        ld e,0
        push af
        call efxlod0                ;handle is always 0
        pop bc
        ld a,b
        jp nc,SyFile_FILCLO
cfgsnd2 call SyFile_FILCLO
cfgsnd3 ld de,256*1+1               ;file not found -> use default psg sounds
        ld a,(App_BnkNum)
        ld hl,defsysefx
        ld bc,defsysefx0-defsysefx
        jp efxlod0

;### CFGREL -> reloads system sounds
cfgrel  xor a
        call efxfrex
        call cfgsnd
        jp prgprz0

;### CFGHID -> hide on start up on/off
cfghid  ld hl,stamendat1a
        ld a,(hl)
        xor 2
        ld (hl),a
        srl a
        ld (cfgflghid),a
        jp prgprz0

;### CFGVOL -> calculates volume lookup table
;### Input      A=volume (0-255), C=type (0=music, 1=effect), CF=1 -> play test beep, if effect table
;### Destroyed  BC,HL,IY
cfgvol  push af
        push bc
        push de
        push ix

        dec c
        jr nz,cfgvol6
        push af             ;** effects
        call op4vfx     ;set opl4 effect master
        pop af
        ld bc,vollupefx
        jr cfgvol4

cfgvol6 ld de,(musvols)     ;** music
        inc e:dec e     ;music volume -> combine master with music setting
        jr z,cfgvol5
        inc de          ;de=0 (mute) or 2-256
cfgvol5 call clcm16     ;h=master (0-255) * musvol(0-256) / 256 = 0-255
        ld a,h
        push af
        call op4vmu     ;set opl4 music master
        pop af
        ld bc,vollupmus

cfgvol4 or a
        jr nz,cfgvol0

        ld l,c          ;** mute
        ld h,b
        ld e,c
        ld d,b
        inc e
        ld b,c
        dec c
        ld (hl),a
        ldir
        jr cfgvol3

cfgvol0 push bc         ;** volume
        ld l,a
        ld h,0
        inc hl
        ld (cfgvol1+1),hl
        ld ixl,16       ;generate first 16 values
cfgvol1 ld de,0         ;de=1-256
        ld a,16
        sub ixl         ;a=0-15
        call clcm16
        ld a,h          ;a=value*volume/256
        ld (bc),a
        inc bc
        dec ixl
        jr nz,cfgvol1
        pop hl
        push hl
        ld de,16*256+16 ;set bit 4 for values 16-31
cfgvol2 ld a,(hl)
        add e
        ld (bc),a
        inc hl
        inc bc
        dec d
        jr nz,cfgvol2
        ld e,c          ;duplicate into all remaining values
        ld d,b
        pop hl
        ld bc,256-32
        ldir

cfgvol3 pop ix
        pop de
        pop bc
        pop af
        ret nc
        dec c
        ret nz
        push af
        push de
        push ix
        ld a,(efxhnddvc+efxhndmem)
        dec a
        ld b,4
        jr z,cfgvol7
        ld bc,256*1+128
        xor a
        ld e,a
        ld d,a
cfgvol7 ld l,SND_SYS_BEEP1
        ld h,255
        ld b,4
        call efxply
        pop ix
        pop de
        pop af
        ret


;==============================================================================
;### SUB ROUTINES #############################################################
;==============================================================================

statxtnot   db "N/A",0

;### MEMUPD -> updates memory values
memupd  ld a,(dvcsta)
        bit 1,a
        jr nz,memupd1
        ld hl,statxtnot             ;*** OPL4
        ld de,statxtmot     ;not available
        ld bc,4
        ldir
        ld hl,statxtmot
        ld de,statxtmom
        ld c,3*8
        ldir
        jr memupd4
memupd1 ld a,(op4_64kbnk)   ;opl4 total memory
        push af
        ld e,a
        ld d,0
        ld ix,0
        ld iy,statxtmot
        call clcn32
        pop hl
        ld l,0              ;opl4 free
        ld de,(smppag)
        or a
        sbc hl,de
        ld e,l
        ld ixh,e
        ld e,h
        ld d,0
        ld ixl,d
        ld iy,statxtmof
        call clcn32
        ld a,(mussta)       ;opl4 used for music
        cp 2
        ld a,(snddatmem+SWM_NUMSMP)
        ld hl,(op4smpadr)
        ld de,0
        ld ix,0
        call z,memsmp
        ld iy,statxtmom
        call clcn32
        ld hl,efxhndmem     ;opl4 used for effects
        ld iyl,efxhndmax
        ld de,0
memupd2 ld a,(hl)
        cp 2
        jr nz,memupd3
        push hl
        inc hl:inc hl
        ld h,(hl)
        ld l,0
        ld a,(hl)
        inc hl
        push de
        call memsmp0
        pop hl
        add hl,de
        ex de,hl
        pop hl
memupd3 ld bc,efxhndlen
        add hl,bc
        dec iyl
        jr nz,memupd2
        call memsmp2
        ld iy,statxtmox
        call clcn32

memupd4 ld ix,musdatsiz+efxdatsiz   ;*** CPU
        push ix
        ld iy,statxtmct     ;total
        ld e,5
        call clcnum
        ld ix,(musdatusd)
        push ix
        ld iy,statxtmcm     ;music
        ld e,5
        call clcnum
        ld ix,(efxdatusd)
        push ix
        ld iy,statxtmcx     ;effects
        ld e,5
        call clcnum
        pop de
        pop bc
        pop hl
        or a
        sbc hl,bc
        sbc hl,de
        push hl:pop ix
        ld iy,statxtmcf     ;free
        ld e,5
        call clcnum

        ld a,(stawinvis)            ;*** redraw
        or a
        ret z
        ld a,(stactrtba0)
        cp 3
        ret nz
        ld a,(stawin_id)
        ld de,256*11+256-6
        jp SyDesktop_WINDIN

;### MEMSMP -> calculate total sample length
;### Input      A=number of samples, HL=sample records
;### Output     DE,IX=total length in bytes
;### Destroyed  AF,BC,HL
memsmp  call memsmp0
memsmp2 ld ixh,e
        ld e,d
        ld d,0
        ld ixl,d            ;de,ix=total sample bytes
        ret
memsmp0 inc hl:inc hl
        ld de,0
memsmp1 ld c,(hl)
        inc hl
        ld b,(hl)
        call smpbtl
        ld c,ixl
        ld b,0
        ex de,hl
        add hl,bc
        ex de,hl
        ld c,smpop4len-1
        add hl,bc
        dec a
        jr nz,memsmp1       ;de=number of pages
        ret


;### PSGREL -> relocates psg data (Arkos Tracker II AKG/AKX with attached relocator table)
;### Input      HL=data (must be at #xx00)
;### Destroyed  AF,BC,DE,HL,IX

;1xxxxxxx                    skip x bytes and relocate 1 word
;0xxxxxxx yyyyyyyy           skip x bytes and relocate y words
;00000000 00000000           EOF

psgrel  ld a,h
        ld ixh,a
psgrel0 ld e,(hl)       ;ixh=highbyte-dif
        inc hl
        ld d,(hl)
        inc hl
        inc hl
        inc hl
        ex de,hl
        add hl,de
psgrel1 ld a,(hl)
        inc hl
        sub 128
        jr c,psgrel5
        ld c,a
        ld ixl,1
psgrel2 ld b,0
        ex de,hl
        add hl,bc
        ex de,hl
        inc ixl
        jr psgrel4
psgrel3 inc de
        ld a,(de)
        add ixh
        ld (de),a
        inc de
psgrel4 dec ixl
        jr nz,psgrel3
        jr psgrel1
psgrel5 add 128
        ld c,a
        ld a,(hl)
        inc hl
        ld ixl,a
        or c
        jr nz,psgrel2
        ret

;### FILCHK -> check, if correct file data and get length
;### Input      A=file handle, B=type byte ("X"=effects, "M"=music), D=device (1=PSG, 2=OPL4)
;### Output     CF=0 -> ok, BC=length
;###            CF=1 -> error, A=error code
;### Destroyed  HL,IX,IY
filchkb ds 4
filchk  push de
        or a
        push af
        dec d
        ld c,"P"
        jr z,filchk1
        ld c,"W"                ;BC=full identifier
filchk1 push bc
        ld hl,filchkb
        ld bc,4
        ld de,(App_BnkNum)
        call SyFile_FILINP      ;load header
        pop bc
        ld a,snderrfil
        jr c,filchk2            ;file error -> quit
        ld hl,(filchkb)
        sbc hl,bc
        ld a,snderrdat
        scf
        jr nz,filchk2           ;wrong identifier -> quit
        ld bc,(filchkb+2)       ;get length
        pop af
        pop de
        ret
filchk2 pop de
        pop de
        ret

;### CLCUCS -> Change letters to uppercase
;### Input      A=char
;### Output     A=ucase(char)
;### Destroyed  F
clcucs  cp "a"
        ret c
        cp "z"+1
        ret nc
        add "A"-"a"
        ret

;### STRINP -> inits textinput (set length, cursor)
;### Input      IX=Control
;### Output     HL=Stringend (0), BC=length (max 255)
;### Destroyed  AF
strinp  ld l,(ix+0)
        ld h,(ix+1)
        call strlen
        ld (ix+8),c
        ld (ix+4),c
        xor a
        ld (ix+2),a
        ld (ix+6),a
        ret

;### STRLEN -> Ermittelt Länge eines Strings
;### Eingabe    HL=String (0-terminiert)
;### Ausgabe    HL=Stringende (0), BC=Länge (maximal 255, ohne Terminator)
;### Verändert  -
strlen  push af
        xor a
        ld bc,255
        cpir
        ld a,254
        sub c
        ld c,a
        dec hl
        pop af
        ret

;### CLCM16 -> Multipliziert zwei Werte (16bit)
;### Eingabe    A=Wert1, DE=Wert2
;### Ausgabe    HL=Wert1*Wert2 (16bit)
;### Veraendert AF,DE
clcm16  ld hl,0         ;3
clcm161 or a            ;1
        ret z           ;2 (4)
        rra             ;1
        jr nc,clcm162   ;3/2
        add hl,de       ;0/3
clcm162 sla e           ;2
        rl d            ;2
        jr clcm161      ;3 -> 15 pro durchlauf

;### CLCMUL -> Multipliziert zwei Werte (24bit)
;### Eingabe    BC=Wert1 (möglichst kleinerer), DE=Wert2 (möglichst größerer)
;### Ausgabe    A,HL=Wert1*Wert2 (24bit)
;### Veraendert F,BC,DE,IX
clcmul  ld ix,0
        ld hl,0
clcmul1 ld a,c          ;1
        or b            ;1
        jr z,clcmul3    ;2/3
        srl b           ;2
        rr c            ;2
        jr nc,clcmul2   ;2/3 -> 11
        add ix,de       ;5
        ld a,h          ;1
        adc l           ;1
        ld h,a          ;1 -> 18 -> 14,5
clcmul2 sla e           ;2
        rl d            ;2
        rl l            ;2
        jr clcmul1      ;3 -> 9 -> 23,5
clcmul3 ld a,h
        db #dd:ld e,l
        db #dd:ld d,h
        ex de,hl
        ret

;### CLCMU8 -> multiplication 8bit unsigned
;### Output     HL=H*E
;### Destroyed  A,D,B
clcmu8  ld d,0      ;combining the overhead and optimised first iteration
        sla h
        sbc a
        and e
        ld l,a
        ld b,7
clcmu81 add hl,hl
        jr nc,clcmu82
        add hl,de
clcmu82 djnz clcmu81
        ret

;### CLCD68 -> division 16/8 unsigned
;### Output     HL=HL/C, A=remainer
;### Destroyed  F,B
clcd68  xor a
        ld b,16
clcd681 add hl,hl
        rla
        jr c,clcd682
        cp c
        jr c,clcd683
clcd682 sub c
        inc l
clcd683 djnz clcd681
        ret

;### CLCCMP -> compare 16bit values
;### Output     HL<DE -> CF=1, HL=DE -> ZF=1
;### Destroyed  AF
clccmp  ld a,h
        sub d
        ret nz
        ld a,l
        sub e
        ret

;### CLCN32 -> Wandelt 32Bit-Zahl in ASCII-String um (mit 0 abgeschlossen)
;### Eingabe    DE,IX=Wert, IY=Adresse
;### Ausgabe    IY=Adresse letztes Zeichen
;### Veraendert AF,BC,DE,HL,IX,IY
clcn32  push ix:pop hl
        ld ix,256*9+0
        call clcn321
        dw #ca00,#3b9a, #e100,#5f5, #9680,#98, #4240,#f, #86a0,1
        dw 10000,0,     1000,0,     100,0,     10,0,     1,0
clcn321 pop bc                      ;3
        ld a,(bc):inc bc:ld (clcn322+1),a   ;8
        ld a,(bc):inc bc:ld (clcn322+2),a   ;8
        ld a,(bc):inc bc:ld (clcn323+1),a   ;8
        ld a,(bc):inc bc:ld (clcn323+2),a   ;8
        push bc                     ;4
        ld a,"0"-1
        or a
clcn322 ld bc,0                     ;3
        sbc hl,bc                   ;4
        ex de,hl                    ;1
clcn323 ld bc,0                     ;3
        sbc hl,bc                   ;4
        ex de,hl                    ;1 -> 16
        inc a
        inc ixl
        jr nc,clcn322
        ld bc,(clcn322+1)           ;6
        add hl,bc                   ;3
        ex de,hl                    ;1
        ld bc,(clcn323+1)           ;6
        adc hl,bc                   ;4
        ex de,hl                    ;1 -> 21 -> 64
        dec ixl
        jr z,clcn324
        ld (iy+0),a
        inc iy
clcn324 dec ixh
        jr nz,clcn321
        pop bc
        ld a,l
        add "0"
        ld (iy+0),a
        ld (iy+1),0
        ret

;### CLCNUM -> Converts 16bit number into ASCII string (0-terminated)
;### Input      IX=value, IY=address, E=max digits
;### Output     (IY)=last digit
;### Destroyed  AF,BC,DE,HL,IX,IY
clcnumt dw -1,-10,-100,-1000,-10000
clcnum  ld d,0          ;2
        ld b,e          ;1
        push ix         ;5
        pop hl          ;3
        sla e           ;2
        ld ix,clcnumt-2 ;4
        add ix,de       ;4
        dec b           ;1
        jr z,clcnum4    ;3/2
        xor a           ;1
clcnum1 ld e,(ix+0)     ;5
        ld d,(ix+1)     ;5
        dec ix          ;3
        dec ix          ;3
        ld c,"0"-1      ;2
clcnum2 add hl,de       ;3
        inc c           ;1
        inc a           ;1
        jr c,clcnum2    ;3
        sbc hl,de       ;4
        dec a           ;1
        jr z,clcnum3    ;3/2
        ld (iy+0),c     ;5
        inc iy          ;3
clcnum3 djnz clcnum1    ;4/3
clcnum4 ld a,"0"        ;2
        add l           ;1
        ld (iy+0),a     ;5
        ld (iy+1),0     ;5
        ret


defsysefx equ $+4
incbin"Dmn-Sound-SysEfx.spx"        ;default system sounds
defsysefx0

align 256
vollupmus
db #00,#01,#02,#03,#04,#05,#06,#07,#08,#09,#0a,#0b,#0c,#0d,#0e,#0f
db #10,#11,#12,#13,#14,#15,#16,#17,#18,#19,#1a,#1b,#1c,#1d,#1e,#1f
db #20,#21,#22,#23,#24,#25,#26,#27,#28,#29,#2a,#2b,#2c,#2d,#2e,#2f
db #30,#31,#32,#33,#34,#35,#36,#37,#38,#39,#3a,#3b,#3c,#3d,#3e,#3f
db #40,#41,#42,#43,#44,#45,#46,#47,#48,#49,#4a,#4b,#4c,#4d,#4e,#4f
db #50,#51,#52,#53,#54,#55,#56,#57,#58,#59,#5a,#5b,#5c,#5d,#5e,#5f
db #60,#61,#62,#63,#64,#65,#66,#67,#68,#69,#6a,#6b,#6c,#6d,#6e,#6f
db #70,#71,#72,#73,#74,#75,#76,#77,#78,#79,#7a,#7b,#7c,#7d,#7e,#7f
db #80,#81,#82,#83,#84,#85,#86,#87,#88,#89,#8a,#8b,#8c,#8d,#8e,#8f
db #90,#91,#92,#93,#94,#95,#96,#97,#98,#99,#9a,#9b,#9c,#9d,#9e,#9f
db #a0,#a1,#a2,#a3,#a4,#a5,#a6,#a7,#a8,#a9,#aa,#ab,#ac,#ad,#ae,#af
db #b0,#b1,#b2,#b3,#b4,#b5,#b6,#b7,#b8,#b9,#ba,#bb,#bc,#bd,#be,#bf
db #c0,#c1,#c2,#c3,#c4,#c5,#c6,#c7,#c8,#c9,#ca,#cb,#cc,#cd,#ce,#cf
db #d0,#d1,#d2,#d3,#d4,#d5,#d6,#d7,#d8,#d9,#da,#db,#dc,#dd,#de,#df
db #e0,#e1,#e2,#e3,#e4,#e5,#e6,#e7,#e8,#e9,#ea,#eb,#ec,#ed,#ee,#ef
db #f0,#f1,#f2,#f3,#f4,#f5,#f6,#f7,#f8,#f9,#fa,#fb,#fc,#fd,#fe,#ff

vollupefx
db #00,#01,#02,#03,#04,#05,#06,#07,#08,#09,#0a,#0b,#0c,#0d,#0e,#0f
db #10,#11,#12,#13,#14,#15,#16,#17,#18,#19,#1a,#1b,#1c,#1d,#1e,#1f
db #20,#21,#22,#23,#24,#25,#26,#27,#28,#29,#2a,#2b,#2c,#2d,#2e,#2f
db #30,#31,#32,#33,#34,#35,#36,#37,#38,#39,#3a,#3b,#3c,#3d,#3e,#3f
db #40,#41,#42,#43,#44,#45,#46,#47,#48,#49,#4a,#4b,#4c,#4d,#4e,#4f
db #50,#51,#52,#53,#54,#55,#56,#57,#58,#59,#5a,#5b,#5c,#5d,#5e,#5f
db #60,#61,#62,#63,#64,#65,#66,#67,#68,#69,#6a,#6b,#6c,#6d,#6e,#6f
db #70,#71,#72,#73,#74,#75,#76,#77,#78,#79,#7a,#7b,#7c,#7d,#7e,#7f
db #80,#81,#82,#83,#84,#85,#86,#87,#88,#89,#8a,#8b,#8c,#8d,#8e,#8f
db #90,#91,#92,#93,#94,#95,#96,#97,#98,#99,#9a,#9b,#9c,#9d,#9e,#9f
db #a0,#a1,#a2,#a3,#a4,#a5,#a6,#a7,#a8,#a9,#aa,#ab,#ac,#ad,#ae,#af
db #b0,#b1,#b2,#b3,#b4,#b5,#b6,#b7,#b8,#b9,#ba,#bb,#bc,#bd,#be,#bf
db #c0,#c1,#c2,#c3,#c4,#c5,#c6,#c7,#c8,#c9,#ca,#cb,#cc,#cd,#ce,#cf
db #d0,#d1,#d2,#d3,#d4,#d5,#d6,#d7,#d8,#d9,#da,#db,#dc,#dd,#de,#df
db #e0,#e1,#e2,#e3,#e4,#e5,#e6,#e7,#e8,#e9,#ea,#eb,#ec,#ed,#ee,#ef
db #f0,#f1,#f2,#f3,#f4,#f5,#f6,#f7,#f8,#f9,#fa,#fb,#fc,#fd,#fe,#ff

snddatmem   ;memory for music and effects
ds 5        ;**LAST IN CODE AREA**

musdatsiz   equ 16384
efxdatsiz   equ  8192


;==============================================================================
;### DATA AREA ################################################################
;==============================================================================

App_BegData

prgicn16c db 12,24,24:dw $+7:dw $+4,12*24:db 5
db #77,#77,#77,#77,#77,#77,#77,#77,#78,#88,#88,#88,#78,#88,#88,#88,#88,#88,#88,#88,#18,#88,#88,#88,#78,#66,#66,#66,#66,#66,#66,#67,#18,#88,#88,#88,#78,#66,#66,#66,#66,#66,#66,#67,#18,#31,#18,#88
db #78,#66,#66,#61,#11,#66,#66,#67,#13,#01,#e3,#88,#78,#67,#76,#61,#78,#66,#77,#67,#30,#31,#e3,#88,#78,#68,#87,#77,#77,#77,#88,#63,#02,#1e,#88,#38,#78,#66,#67,#86,#66,#61,#66,#30,#28,#1e,#88,#38
db #78,#66,#67,#11,#11,#11,#63,#02,#82,#1e,#88,#38,#78,#67,#76,#61,#78,#66,#30,#28,#21,#ee,#88,#83,#78,#68,#86,#61,#13,#33,#22,#82,#81,#3e,#88,#83,#78,#66,#66,#61,#38,#23,#88,#88,#81,#13,#88,#83
db #78,#66,#66,#61,#38,#83,#82,#82,#81,#83,#18,#83,#78,#67,#76,#61,#38,#23,#28,#28,#81,#e3,#18,#83,#78,#68,#86,#61,#38,#03,#02,#02,#01,#33,#18,#83,#78,#66,#66,#61,#38,#23,#20,#20,#21,#11,#e8,#83
db #78,#66,#66,#61,#13,#33,#32,#02,#01,#33,#e8,#83,#78,#67,#76,#61,#78,#11,#10,#20,#21,#3e,#88,#83,#78,#68,#86,#61,#78,#66,#81,#32,#01,#3e,#88,#38,#78,#66,#66,#68,#88,#66,#66,#13,#33,#1e,#88,#38
db #78,#66,#66,#66,#66,#66,#66,#61,#33,#1e,#88,#38,#78,#66,#66,#66,#66,#66,#66,#67,#13,#31,#e3,#88,#78,#77,#77,#77,#77,#77,#77,#77,#11,#31,#e3,#88,#71,#11,#11,#11,#11,#11,#11,#11,#18,#11,#18,#88

gfxsnd db 8,16,16:dw $+7,$+4,16*16:db 5 ;sound symbol (speaker)
db #66,#66,#66,#66,#63,#11,#66,#66
db #66,#66,#66,#66,#30,#1e,#36,#66
db #66,#66,#66,#63,#03,#1e,#36,#66
db #66,#66,#66,#30,#21,#e8,#83,#66
db #66,#66,#63,#02,#81,#e8,#83,#66
db #61,#33,#30,#28,#21,#e8,#83,#66
db #13,#82,#32,#82,#11,#38,#88,#36
db #13,#88,#38,#88,#18,#31,#88,#36
db #13,#82,#30,#20,#1e,#31,#88,#36
db #13,#80,#32,#02,#13,#31,#88,#36
db #13,#82,#33,#20,#11,#18,#83,#66
db #61,#33,#31,#33,#31,#e8,#83,#66
db #66,#66,#66,#13,#31,#e8,#83,#66
db #66,#66,#66,#61,#33,#1e,#36,#66
db #66,#66,#66,#66,#13,#1e,#36,#66
db #66,#66,#66,#66,#61,#11,#66,#66

gfxmus db 8,16,16:dw $+7,$+4,16*16:db 5 ;music symbol (notes)
db #66,#66,#61,#11,#16,#66,#66,#66
db #66,#66,#61,#11,#11,#16,#66,#66
db #66,#66,#61,#11,#11,#11,#16,#66
db #66,#66,#61,#61,#11,#11,#11,#66
db #66,#66,#61,#66,#61,#11,#11,#66
db #66,#66,#61,#66,#66,#61,#11,#66
db #66,#66,#61,#66,#66,#66,#61,#66
db #66,#66,#61,#66,#66,#66,#61,#66
db #66,#11,#11,#66,#66,#66,#61,#66
db #61,#8e,#11,#66,#66,#66,#61,#66
db #61,#ee,#11,#66,#66,#66,#61,#66
db #61,#11,#11,#66,#66,#11,#11,#66
db #66,#11,#16,#66,#61,#8e,#11,#66
db #66,#66,#66,#66,#61,#ee,#11,#66
db #66,#66,#66,#66,#61,#11,#11,#66
db #66,#66,#66,#66,#66,#11,#16,#66

gfxvol db 30,60,5:dw $+7,$+4,30*5:db 5  ;volume bar
db #11,#11,#11,#77,#77,#77,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66
db #11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66
db #11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66,#66
db #11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77,#66,#66,#66,#66,#66,#66
db #11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77

gfxply db 8,13,12:dw $+7,$+4,16*12:db 5 ;play
db #67,#77,#77,#77,#77,#77,#68,#88
db #76,#66,#66,#66,#66,#66,#18,#88
db #76,#69,#96,#66,#66,#66,#18,#88
db #76,#69,#a9,#96,#66,#66,#18,#88
db #76,#69,#aa,#a9,#96,#66,#18,#88
db #76,#69,#aa,#aa,#a9,#66,#18,#88
db #76,#69,#aa,#aa,#a9,#66,#18,#88
db #76,#69,#aa,#a9,#96,#66,#18,#88
db #76,#69,#a9,#96,#66,#66,#18,#88
db #76,#69,#96,#66,#66,#66,#18,#88
db #76,#66,#66,#66,#66,#66,#18,#88
db #61,#11,#11,#11,#11,#11,#68,#88

gfxvbt db 8,13,12:dw $+7,$+4,16*12:db 5 ;volume button
db #67,#77,#77,#77,#77,#77,#68,#88
db #76,#66,#66,#66,#66,#66,#18,#88
db #76,#66,#66,#66,#66,#66,#18,#88
db #76,#66,#66,#66,#66,#f6,#18,#88
db #76,#66,#66,#66,#f2,#f6,#18,#88
db #76,#66,#66,#f2,#f2,#f6,#18,#88
db #76,#66,#f2,#f2,#f2,#f6,#18,#88
db #76,#f2,#f2,#f2,#f2,#f6,#18,#88
db #76,#f2,#f2,#f2,#f2,#f6,#18,#88
db #76,#66,#66,#66,#66,#66,#18,#88
db #76,#66,#66,#66,#66,#66,#18,#88
db #61,#11,#11,#11,#11,#11,#68,#88

gfxrel db 8,13,12:dw $+7,$+4,16*12:db 5 ;reload
db #67,#77,#77,#77,#77,#77,#68,#88
db #76,#66,#66,#66,#66,#66,#18,#88
db #76,#66,#71,#11,#76,#16,#18,#88
db #76,#61,#16,#67,#11,#16,#18,#88
db #76,#16,#66,#66,#71,#16,#18,#88
db #76,#66,#66,#61,#11,#16,#18,#88
db #76,#11,#11,#66,#66,#66,#18,#88
db #76,#11,#76,#66,#66,#16,#18,#88
db #76,#17,#17,#66,#11,#66,#18,#88
db #76,#16,#71,#11,#76,#66,#18,#88
db #76,#66,#66,#66,#66,#66,#18,#88
db #61,#11,#11,#11,#11,#11,#68,#88


;### info
prgmsginf1  db "SymbOS Sound Daemon",0
prgmsginf2  db " Version 1.0 (Build "
read "..\..\..\SRC-Main\build.asm"
            db "pdt)",0
prgmsginf3  db " <c> 2024 SymbiosiS/Arkos/NOP",0

prgmsgwpf1 db "Wrong platform! This Sound Daemon",0
prgmsgwpf2 db "is for the "
if     PLATFORM_TYPE=PLATFORM_CPC
                       db "AMSTRAD CPC.",0
elseif PLATFORM_TYPE=PLATFORM_MSX
                       db "MSX1/2(+)/TURBOR.",0
elseif PLATFORM_TYPE=PLATFORM_PCW
                       db "AMSTRAD PCW JOYCE.",0
elseif PLATFORM_TYPE=PLATFORM_EPR
                       db "ENTERPRISE 64/128.",0
elseif PLATFORM_TYPE=PLATFORM_SVM
                       db "SYMBOS VM.",0
elseif PLATFORM_TYPE=PLATFORM_NCX
                       db "AMSTRAD NC1x0/200.",0
elseif PLATFORM_TYPE=PLATFORM_ZNX
                       db "ZX SPECTRUM NEXT.",0
endif
prgmsgwpf3 db "Please replace SOUNDD.EXE .",0

prgmsgshm1  db "Are you sure you want to",0
prgmsgshm2  db "reset the current sound",0
prgmsgshm3  db "scheme?",0

prgmsgmmu2  db "clean-up all loaded",0
prgmsgmmu3  db "music?",0

prgmsgmfx3  db "effects?",0

;### status text data
stamentxt1  db "File",0
stamentxt2  db "?",0
stamentxt11 db "Save settings",0
stamentxt12 db "Hide on startup",0
stamentxt13 db "Quit",0
stamentxt21 db "Index",0
stamentxt22 db "About",0

statxttit   db "Sound daemon",0
statxtbta   db "Hide",0
statxtbtb   db "Save",0

statxttba1  db "Mixer",0
statxttba2  db "System sounds",0
statxttba3  db "Settings",0
statxttba4  db "Stats",0

;### general
gentxtvct   db "Volume control",0
gentxtmut   db "Mute",0

gentxttfx   db "Effects",0
gentxttms   db "Music",0

gentxtdpr   db "Preferred output device",0

gentxtd01
if     PLATFORM_TYPE=PLATFORM_PCW
db "External AY (dk'tronics)",0
elseif PLATFORM_TYPE=PLATFORM_EPR
db "Internal PSG (Dave)",0
elseif PLATFORM_TYPE=PLATFORM_NCX
db "Internal beepers",0
else
db "Internal PSG (AY)",0
endif

gentxtd02   db "OPL4 wavetable ("
gentxtd02a  db "2048K)",0

statxtdrv
if     PLATFORM_TYPE=PLATFORM_CPC
db "CPC driver 1.0",0
elseif PLATFORM_TYPE=PLATFORM_MSX
db "MSX driver 1.0",0
elseif PLATFORM_TYPE=PLATFORM_PCW
db "PCW driver 1.0",0
elseif PLATFORM_TYPE=PLATFORM_EPR
db "EPR driver 1.0",0
elseif PLATFORM_TYPE=PLATFORM_SVM
db "SVM driver 1.0",0
elseif PLATFORM_TYPE=PLATFORM_NCX
db "NCX driver 1.0",0
elseif PLATFORM_TYPE=PLATFORM_ZNX
db "ZNX driver 1.0",0
endif

;### system sounds
systxtevt   db "Events:",0
systxtsnd   db "Sound:",0
systxttst   db ">> Test",0
systxtsta   db "play SymbOS startup sound",0

systxtsht   db "Sound scheme",0
systxtshl   db "Load...",0
systxtshs   db "Save...",0
systxtshd   db "Default",0

systxte00   db "Notification - hint",0
systxte01   db "Notification - warning",0
systxte02   db "Notification - message",0

systxte03   db "Window - open",0
systxte08   db "Window - close",0
systxte04   db "Window - top",0
systxte05   db "Window - restore",0
systxte06   db "Window - maximize",0
systxte07   db "Window - minimize",0
systxte17   db "Window - move",0
systxte18   db "Window - resize",0

systxte09   db "Menu - open",0
systxte10   db "Menu - entry hover",0
systxte11   db "Menu - entry clicked",0

systxte12   db "Click - button/tab",0
systxte13   db "Click - bitmap",0
systxte14   db "Click - slider",0
systxte15   db "Click - list",0
systxte16   db "Click - text",0

systxts00   db "(None)",0
systxts01   db "Click 1",0
systxts02   db "Click 2",0
systxts03   db "Beep 1",0
systxts04   db "Beep 2",0
systxts05   db "Ring 1",0
systxts06   db "Ring 2",0
systxts07   db "Alert 1",0
systxts08   db "Alert 2",0
systxts09   db "Slide 1",0
systxts10   db "Slide 2",0
systxts11   db "Raise up",0
systxts12   db "Raise down",0
systxts13   db "Pop up",0
systxts14   db "Shrink",0
systxts15   db "Tic 1",0
systxts16   db "Tic 2",0
systxts17   db "Shoot",0
systxts18   db "Explosion",0
systxts19   db "Step",0
systxts20   db "Lose",0
systxts21   db "Win",0
;asterisk, message

;### settings
settxtchn   db "PSG effect channel",0
settxtch0   db "use all",0
settxtch1   db "left",0
settxtch2   db "middle",0
settxtch3   db "right",0

settxtssf   db "System sound file",0
settxtssp   db "PSG",0
settxtsso   db "OPL4",0
settxtssb   db "...",0

settxtsmo   db "Disable music",0

;### stats
statxtmfr   db "Memory usage",0

statxtmtc   db "CPU ram",0
statxtmto   db "OPL4 ram",0
statxtmtt   db "Total",0
statxtmtm   db "Music",0
statxtmtx   db "Effects",0
statxtmtf   db "Free",0

statxtmct   ds 8
statxtmcm   ds 8
statxtmcx   ds 8
statxtmcf   ds 8
statxtmot   ds 8
statxtmom   ds 8
statxtmox   ds 8
statxtmof   ds 8

statxtmmu   db "Clean-up music",0
statxtmfx   db "Clean-up effects",0


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

;### PRGTIMS -> Stack for application timer
        ds 128
prgtims ds 6*2
        dw prgtim
prgtimn db 0
timmsgb ds 14


cfghrdtyp   db 0

;### CONFIG ###################################################################
cfg_beg

cfgflghid   db 0    ;1=hide on startup
cfgflgwel   db 1    ;play startup sound
cfgpsgxfc   db 1    ;0=force preferred channel, 1=use all channels
cfgpsgxpc   db 1    ;psg preferred effect channel (0-2)
cfgfilpsg   ds 128
cfgfilwav   ds 128

cfgdvcprf   db 0    ;preferred output device (0=psg, 1=opl4)
cfgefxvol   db 255  ;effect volume (0-255)
cfgmusvol   db 255  ;music  volume (0-255)

cfgsndevt   ;sound ID (0=none), volume (0-255) for each event
db 05,128, 07,128, 06,128, 13,128, 13,128, 11,128, 11,128, 12,128
db 18,128, 11,128, 03,128, 04,128, 03,128, 04,128, 09,128, 04,128
db 15,128, 09,128, 10,128
db                         00,128, 00,128, 00,128, 00,128, 00,128
db 00,128, 00,128, 00,128, 00,128, 00,128, 00,128, 00,128, 00,128

cfgmusoff   db 0    ;1=no music allowed

cfg_end

cfgbrwpth   db "S?X":db 0:ds 256
setshmpth   db "SDS":db 0:ds 256

;### INFO-FENSTER #############################################################
prgmsginf  dw prgmsginf1,4*1+2,prgmsginf2,4*1+2,prgmsginf3,4*1+2,0,prgicnbig,prgicn16c
prgmsgshm  dw prgmsgshm1,4*1+2,prgmsgshm2,4*1+2,prgmsgshm3,4*1+2
prgmsgmmu  dw prgmsgshm1,4*1+2,prgmsgmmu2,4*1+2,prgmsgmmu3,4*1+2
prgmsgmfx  dw prgmsgshm1,4*1+2,prgmsgmmu2,4*1+2,prgmsgmfx3,4*1+2
prgmsgwpf  dw prgmsgwpf1,4*1+2,prgmsgwpf2,4*1+2,prgmsgwpf3,4*1+2


;### status window data
stawindat   dw #3501,0,56,26,172,126,0,0,172,126,172,126,172,126,prgicnsml,statxttit,0,stamendat
stawindat0  dw stawingrpa,0,0:ds 136+14
stawingrpa  db 19,0:dw stawindata,0,0,4*256+3,0,0,2
stawingrpb  db 16,0:dw stawindatb,0,0,4*256+3,0,0,2
stawingrpc  db 19,0:dw stawindatc,0,0,4*256+3,0,0,2
stawingrpd  db 21,0:dw stawindatd,0,0,4*256+3,0,0,2

stamendat   dw 2, 1+4,stamentxt1,stamendat1,0,     1+4,stamentxt2,stamendat2,0
stamendat1  dw 4, 1,stamentxt11,staapl,0
stamendat1a dw    1,stamentxt12,cfghid,0,   1+8,#0000,0,0, 1,stamentxt13,prgend,0    ;save settings/hide to systray/-/quit
stamendat2  dw 3, 1,stamentxt21,prghlp,0,   1+8,#0000,0,0, 1,stamentxt22,prginf,0    ;index/-/about

volmendat   dw 9, 0,volmentxtv,0,0, 1,volmentxt8,255,0, 1,volmentxt7,224,0, 1,volmentxt6,192,0, 1,volmentxt5,160,0, 1,volmentxt4,128,0, 1,volmentxt3,096,0, 1,volmentxt2,064,0, 1,volmentxt1,032,0

volmentxtv  db "Volume",0
volmentxt8  db "|||||||| max",0
volmentxt7  db "|||||||",0
volmentxt6  db "||||||",0
volmentxt5  db "|||||",0
volmentxt4  db "||||",0
volmentxt3  db "|||",0
volmentxt2  db "||",0
volmentxt1  db "|      min",0


stawindata                                                              ;*** GENERAL
; onclick         type   property   xpos   ypos   xlen   ylen
dw      0,  255*256+ 0,         2,     0,     0, 10000, 10000, 0    ;00=background
dw statab,  255*256+20, stactrtba,     0,     2,   172,    11, 0    ;01=tab
dw      0,  255*256+10, prgicn16c,     3,    18,    24,    24, 0    ;02=icon
dw      0,  255*256+ 1, genctrdpr,    40,    18,   112,     8, 0    ;03=device text
dw setdvc,  255*256+42, genctrdls,    40,    28,   112,    10, 0    ;04=device dropdown
dw      0,  255*256+ 3, genctrvct,     0,    49,   172,    61, 0    ;05=frame volume
dw      0,  255*256+10, gfxsnd   ,     8,    62,    16,    16, 0    ;06=effects icon
dw      0,  255*256+ 1, genctrtfx,    32,    61,    30,     8, 0    ;07=effects text
dw      0,  255*256+10, gfxvol   ,    68,    64,    60,     5, 0    ;08=effects volgfx
dw setxmt,  255*256+17, genctrcfx,   137,    61,    72,     8, 0    ;09=effects mute
dw setxvl,  255*256+24, genctrsfx,    32,    71,   132,     8, 0    ;10=effects slider
dw      0,  255*256+10, gfxmus   ,     8,    86,    16,    16, 0    ;11=music icon
dw      0,  255*256+ 1, genctrtms,    32,    85,    30,     8, 0    ;12=music text
dw      0,  255*256+10, gfxvol   ,    68,    88,    60,     5, 0    ;13=music volgfx
dw setmmt,  255*256+17, genctrcms,   137,    85,    72,     8, 0    ;14=music mute
dw setmvl,  255*256+24, genctrsms,    32,    95,   132,     8, 0    ;15=music slider
dw      0,  255*256+ 1, stactrdrv,     3,   113,   112,     8, 0    ;16=driver description
dw staapl,  255*256+16, statxtbtb,    95,   111,    36,    12, 0    ;17=button apply
dw stahid,  255*256+16, statxtbta,   133,   111,    36,    12, 0    ;18=button hide

stawindatb                                                              ;*** SYSTEM SOUNDS
; onclick         type   property   xpos   ypos   xlen   ylen
dw      0,  255*256+ 0,         2,     0,     0, 10000, 10000, 0    ;00=background
dw statab,  255*256+20, stactrtba,     0,     2,   172,    11, 0    ;01=tab
dw      0,  255*256+17, sysctrcss,    50,    18,   128,     8, 0    ;02=symbos startup
dw      0,  255*256+ 1, sysctletx,     3,    18,    36,     8, 0    ;03=event title
dw setevt,  255*256+41, sysctrevt,     3,    28,   166,    34, 0    ;04=event list
dw      0,  255*256+ 1, sysctlstx,     3,    66,   166,     8, 0    ;05=sound title
dw setsnd,  255*256+42, sysctrsnd,    34,    65,   105,    10, 0    ;06=sound dropdown
dw settst,  255*256+10, gfxply,      141,    64,    13,    12, 0    ;07=sound play   button
dw setsvl,  255*256+10, gfxvbt,      156,    64,    13,    12, 0    ;08=sound volume button
dw      0,  255*256+ 3, sysctrshf,     0,    79,   172,    31, 0    ;09=scheme frame
dw setshl,  255*256+16, systxtshl,     8,    91,    50,    12, 0    ;10=scheme load
dw setshs,  255*256+16, systxtshs,    61,    91,    50,    12, 0    ;11=scheme save
dw setshd,  255*256+16, systxtshd,   114,    91,    50,    12, 0    ;12=scheme default
dw      0,  255*256+ 1, stactrdrv,     3,   113,   112,     8, 0    ;13=driver description
dw staapl,  255*256+16, statxtbtb,    95,   111,    36,    12, 0    ;14=button apply
dw stahid,  255*256+16, statxtbta,   133,   111,    36,    12, 0    ;15=button hide

stawindatc                                                              ;*** SETTINGS
; onclick         type   property   xpos   ypos   xlen   ylen
dw      0,  255*256+ 0,         2,     0,     0, 10000, 10000, 0    ;00=background
dw statab,  255*256+20, stactrtba,     0,     2,   172,    11, 0    ;01=tab
dw      0,  255*256+ 3, setctrchn,     0,    18,   172,    27, 0    ;02=psg channel frame
dw      0,  255*256+17, setctrch0,     8,    29,    36,     8, 0    ;03=psg channel all
dw      0,  255*256+18, setctrch1,    63,    29,    36,     8, 0    ;04=psg channel 1
dw      0,  255*256+18, setctrch2,    94,    29,    36,     8, 0    ;05=psg channel 2
dw      0,  255*256+18, setctrch3,   137,    29,    36,     8, 0    ;06=psg channel 3

dw      0,  255*256+ 3, setctrssf,     0,    45,   172,    32, 0    ;07=files frame
stawindatc1
dw      0,  255*256+ 1, setctrssp,     8,    58,    18,     8, 0    ;08=files psg text
dw      0,  255*256+32, setctrsip,    32,    56,    95,    12, 0    ;09=files psg input
dw setfpb,  255*256+16, settxtssb,   129,    56,    20,    12, 0    ;10=files psg browse
dw      0,  255*256+ 1, setctrsso,     8,    58,    18,     8, 0    ;11=files opl4 text
dw      0,  255*256+32, setctrsio,    32,    56,    95,    12, 0    ;12=files opl4 input
dw setfob,  255*256+16, settxtssb,   129,    56,    20,    12, 0    ;13=files opl4 browse
dw cfgrel,  255*256+10, gfxrel,      151,    56,    13,    12, 0    ;14=reload sounds

dw      0,  255*256+17, setctrmof,     4,    81,    60,     8, 0    ;15=disable music

dw      0,  255*256+ 1, stactrdrv,     3,   113,   112,     8, 0    ;16=driver description
dw staapl,  255*256+16, statxtbtb,    95,   111,    36,    12, 0    ;17=button apply
dw stahid,  255*256+16, statxtbta,   133,   111,    36,    12, 0    ;18=button hide



stawindatd                                                              ;*** STATS
; onclick         type   property   xpos   ypos   xlen   ylen
dw      0,  255*256+ 0,         2,     0,     0, 10000, 10000, 0    ;00=background
dw statab,  255*256+20, stactrtba,     0,     2,   172,    11, 0    ;01=tab
dw      0,  255*256+ 3, stactrmfr,     0,    18,   172,    68, 0    ;02=frame memory
dw      0,  255*256+ 1, stactrmtc,    46,    29,    50,     8, 0    ;03=memory title cpu
dw      0,  255*256+ 1, stactrmto,   110,    29,    50,     8, 0    ;04=memory title opl4

dw      0,  255*256+ 1, stactrmtt,     8,    39,    40,     8, 0    ;05=memory title total
dw      0,  255*256+ 1, stactrmtm,     8,    49,    40,     8, 0    ;06=memory title music
dw      0,  255*256+ 1, stactrmtx,     8,    59,    40,     8, 0    ;07=memory title effect
dw      0,  255*256+ 1, stactrmtf,     8,    69,    40,     8, 0    ;08=memory title free

dw      0,  255*256+ 1, stactrmct,    46,    39,    50,     8, 0    ;09=memory cpu  total
dw      0,  255*256+ 1, stactrmot,   110,    39,    50,     8, 0    ;10=memory opl4 total

dw      0,  255*256+ 1, stactrmcm,    46,    49,    50,     8, 0    ;11=memory cpu  music
dw      0,  255*256+ 1, stactrmcx,    46,    59,    50,     8, 0    ;12=memory cpu  effects
dw      0,  255*256+ 1, stactrmcf,    46,    69,    50,     8, 0    ;13=memory cpu  free
dw      0,  255*256+ 1, stactrmom,   110,    49,    50,     8, 0    ;14=memory opl4 music
dw      0,  255*256+ 1, stactrmox,   110,    59,    50,     8, 0    ;15=memory opl4 effects
dw      0,  255*256+ 1, stactrmof,   110,    69,    50,     8, 0    ;16=memory opl4 free

dw memmus,  255*256+16, statxtmmu,     3,    87,    81,    12, 0    ;17=button clean-up music
dw memefx,  255*256+16, statxtmfx,    88,    87,    81,    12, 0    ;18=button clean-up effects

dw      0,  255*256+ 1, stactrdrv,     3,   113,   112,     8, 0    ;??=driver description
dw stahid,  255*256+16, statxtbta,   133,   111,    36,    12, 0    ;??=button hide


;### General
genctrdpr   dw gentxtdpr,2+4                ;device
genctrdls   dw 2,0,genctrdls_rec,0,1,genctrdls_clm,0,0
genctrdls_clm   dw 0,200,0,0
genctrdls_rec
dw 1,gentxtd01
dw 2,gentxtd02

genctrvct   dw gentxtvct,2+4                ;volume
genctrtfx   dw gentxttfx,2+4                ;effects/music
genctrtms   dw gentxttms,2+4
genctrsfx   db 1,0:dw 0,255:db 16,-16       ;slider
genctrmfx   db 0
genctrsms   db 1,0:dw 0,255:db 16,-16
genctrmms   db 0
genctrcfx   dw genctrmfx,gentxtmut:db 2+4   ;mute
genctrcms   dw genctrmms,gentxtmut:db 2+4

;### System Sounds
sysctletx   dw systxtevt,2+4
sysctlstx   dw systxtsnd,2+4

sysctrshf   dw systxtsht,2+4

sysctrcss   dw cfgflgwel,systxtsta:db 2+4

sysctrevt   dw 19,0,sysctrevt_rec,0,1,sysctrevt_clm,0,1
sysctrevt_clm   dw 0,200,0,0
sysctrevt_rec
dw 32768+0,systxte00, 1,systxte01, 2,systxte02                                                                  ;notifications
dw       3,systxte03, 8,systxte08, 4,systxte04, 5,systxte05, 6,systxte06, 7,systxte07,17,systxte17,18,systxte18 ;window
dw       9,systxte09,10,systxte10,11,systxte11                                                                  ;menu
dw      12,systxte12,13,systxte13,14,systxte14,15,systxte15,16,systxte16                                        ;click

sysctrsnd   dw 22,0,sysctrsnd_rec,0,1,sysctrsnd_clm,0,1
sysctrsnd_clm   dw 0,200,0,0
sysctrsnd_rec
dw  0,systxts00, 1,systxts01, 2,systxts02, 3,systxts03, 4,systxts04, 5,systxts05, 6,systxts06, 7,systxts07
dw  8,systxts08, 9,systxts09,10,systxts10,11,systxts11,12,systxts12,13,systxts13,14,systxts14,15,systxts15
dw 16,systxts16,17,systxts17,18,systxts18,19,systxts19,20,systxts20,21,systxts21

;### Settings
setctrchn   dw settxtchn,2+4
setctrch0   dw cfgpsgxfc,settxtch0,2+4
setctrch1   dw cfgpsgxpc,settxtch1,256*0+2+4,setctrchc
setctrch2   dw cfgpsgxpc,settxtch2,256*1+2+4,setctrchc
setctrch3   dw cfgpsgxpc,settxtch3,256*2+2+4,setctrchc
setctrchc   dw -1,-1

setctrssf   dw settxtssf,2+4
setctrssp   dw settxtssp,2+4
setctrsip   dw cfgfilpsg,0,0,0,0,127:db 0
setctrsso   dw settxtsso,2+4
setctrsio   dw cfgfilwav,0,0,0,0,127:db 0

stactrtba   db 4,2+4+48+64
stactrtba0  db 0:dw statxttba1:db -1:dw statxttba2:db -1:dw statxttba3:db -1:dw statxttba4:db -1
stactrdrv   dw statxtdrv,2+12

setctrmof   dw cfgmusoff,settxtsmo:db 2+4


;### Stats
stactrmfr   dw statxtmfr,2+4                ;memory frame

stactrmtc   dw statxtmtc,2+12+256           ;memory title cpu
stactrmto   dw statxtmto,2+12+256           ;memory title opl4
stactrmtt   dw statxtmtt,2+4                ;memory title free
stactrmtm   dw statxtmtm,2+4                ;memory title music
stactrmtx   dw statxtmtx,2+4                ;memory title effects
stactrmtf   dw statxtmtf,2+4                ;memory title free

stactrmct   dw statxtmct,2+4+256            ;memory cpu total
stactrmcm   dw statxtmcm,2+4+256+128        ;memory cpu music
stactrmcx   dw statxtmcx,2+4+256+128        ;memory cpu effects
stactrmcf   dw statxtmcf,2+4+256+128        ;memory cpu free
stactrmot   dw statxtmot,2+4+256            ;memory opl4 total
stactrmom   dw statxtmom,2+4+256+128        ;memory opl4 music
stactrmox   dw statxtmox,2+4+256+128        ;memory opl4 effects
stactrmof   dw statxtmof,2+4+256+128        ;memory opl4 free

prgtrnend
