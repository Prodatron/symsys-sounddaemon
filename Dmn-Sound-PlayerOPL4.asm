;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@                 S y m b O S   -   S o u n d - D a e m o n                  @
;@                                                                            @
;@                             OPL4 Music DRIVER                              @
;@        Prodatron/SymbiosiS (MOD to SWM converter/compressor/merger,        @
;@                    2x speed-up, optimization, SoundDaemon adaption)        @
;@                Maarten Loor/NOP (Z80 MOD player conversion)                @
;@                 Peter Hanning (original 68000 MOD player)                  @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

;todo
;! music/effects destroy samples from each other when loading in a random order

;features
;- commands 8 panning -> E8x
;- commands 8,9,13 free to use
;? implement volume parameter, remove #c

;max time enigma.mod
;- classic 61 RL
;- current 52 RL
;- changed 45 RL
;- nodoubl 44 RL

;        ld a,(ix+PAT_EFFECT)
;        and #f0
;        jr z,...effect0

;        cp #10
;        jp z,...effect1 ;5
;        cp #20
;        jp z,...effect2 ;10

;        ld h,0
;        ld l,a
;        ld bc,xxx
;        add hl,bc
;        jp (hl)     ;10 additional nops



;--- PATTERN DATA HANDLING ----------------------------------------------------
;### PATADR -> gets address of current pattern row
;### PATDCR -> unpacks one pattern row

;--- SAMPLE DATA HANDLING -----------------------------------------------------
;### SMPO4I -> reserves opl4 sample ID
;### SMPEFX -> loads all samples from an effect collection
;### SMPEFR -> removes all already reserved/loaded samples from an effect collection
;### SMPALL -> loads all samples for a music
;### SMPREM -> removes all samples from a music
;### SMPNEW -> creates new sample
;### SMPLOD -> loads sample from opened file into OPL4 ram
;### SMPRES -> reserve memory for one sample
;### SMPFRE -> release sample memory
;### SMPBTL -> get number of pages/bits
;### SMPBTA -> Bitadresse holen
;### SMPBTT -> Bit testen
;### SMPBTS -> Bit setzen
;### SMPBTC -> Bit löschen

;--- OPL4 ROUTINES ------------------------------------------------------------
;### OP4DET -> tries to detect an OPL4 chip
;### OP4MEM -> detects OPL4 wavetable memory
;### OP4RES -> resets OPL4 hardware (enables WAV)
;### OP4SET -> sets multiple OPL4 registers
;### OP4ADR -> sets OPL4 ram read/write address
;### OP4VMA -> sets OPL4 master volume
;### OP4VTR -> get volume translation
;### OP4VFX -> sets effects master volume
;### OP4VMU -> sets music master volume
;### OP4VCH -> set channel volume
;### OP4KON -> set key on and panning
;### OP4KOF -> set volume off, then key off
;### OP4KEY -> prepare OPL4 key on/off and panning
;### OP4TON -> sets tone
;### OP4SMP -> starts new sample, if changed

;--- DEVICE DRIVER ROUTINES (OPL4) --------------------------------------------
;### OP4MIN -> resets opl4 music to the beginning
;### OP4MPL -> starts playing OPL4 music
;### OP4STP -> pauses the music and mutes the OPL4
;### OP4FRM -> plays one OPL4 music frame
;### OP4XPL -> starts an OPL4 sound effect


;---


MACRO   opl4_wt
        ld a,#ff    ;2
        in a,(#c4)  ;3
        and %11     ;2
if OPL4EMU=0
        jr nz,$-6   ;2 -> 9
endif
MEND



;==============================================================================
;### MOD-FUNCTIONS (INTERN) ###################################################
;==============================================================================

;N.O.P. Mod player adapted by Maarten Loor 2020 from the Amiga 68000 version by Peter Hanning
;- cannot start other samples with period (when it is set to loop) (?)

PAT_SAMPLE  equ 0
PAT_NOTE    equ 1
PAT_EFFECT  equ 2
PAT_FXDATA  equ 3

pat_empty   ds 4*4

temp_size       equ     17

n_sampnum       equ     0       ;B    SampleNumber   
n_notenum       equ     1       ;B    NoteNumber   
n_period        equ     2       ; W   Period   
n_volume        equ     4       ;B    Volume   
n_oldsamp       equ     5       ;B    OldSampleNumber   
n_cmdtemp       equ     6       ; W   CommandTemp   
n_oldpbendsp    equ     8       ;B    OldPitchBendSpeed
n_oldvibcmd     equ     9       ;B    OldVibratoCommand
n_vibtabpos     equ     10      ;B    VibratoTablePosition
n_oldtremcmd    equ     11      ;B    OldTremoloCommand
n_tremtabpos    equ     12      ;B    TremoloTablePosition
n_wavectrl      equ     13      ;B    WaveControl %0000TTVV
n_pattloop      equ     14      ; W   PatternLoop(E6)temp
n_changed       equ     16      ;B    bit0 -> period changed, bit1 -> volume changed

pos_temp_ch0    ds      temp_size,0
pos_temp_ch1    ds      temp_size,0
pos_temp_ch2    ds      temp_size,0
pos_temp_ch3    ds      temp_size,0

finetunes       ds      31,0            ;finetunes for samples [0-30]   /playing/
volumes         ds      31,0            ;volumes of samples [0-30]  
patterns        ds      128             ;pattern data [0-127]  
song_length     db      0               ;number of patterns (songlength)  
song_pos        db      0               ;current position [cur,copy]  
song_pospat     db      0
song_step       db      0               ;current step [cur,copy]  
channel         db      255             ;current channel (255 if not playing)
vblanks         db      6,6             ;vblank timing (cur, org)  
arpeggio        db      0               ;for playing c64 sounds  
command_E5temp  db      0               ;temp. for finetune  
command_EEtemp  db      0               ;temp. voor patt.delay  
mt_stopflag     db      0

filenr          db      0

modheader       ds      1084

repeat_song     db      1



;### playing routine
;mt_start   -> restart music
;mt_stop    -> stop/mute music


mt_start
        ld a,(channel)
        inc a
        call z,mt_init
mt_start0
        xor a
        ld (song_pos),a
        ld a,6
        ld (vblanks+1),a
mt_start1
        ld hl,pos_temp_ch0
        ld de,pos_temp_ch0+1
        ld bc,temp_size*4-1
        ld (hl),0
        ldir
        xor a
        ld (mt_stopflag),a
        dec a
        ld (patlstpos),a
        ld (patlstpat),a
        ld a,128
        ld (song_step),a
        ld a,6
        ld (vblanks+0),a
        ld hl,pat_empty
        ld (patadr_set1+2),hl
        ld (patadr_set2+2),hl
        ret

mt_stop
        call mt_stop0
        ld a,1
        ld (mt_stopflag),a
        ret
mt_stop0    ;mute only
        ld hl,channel
        ld a,(hl)
        inc a
        ret z
        ld (hl),255
mt_init ld hl,opl4_play
        jp op4set


mt_music
        ld      a,(vblanks)
        dec     a
        ld      (vblanks),a
        jp      z,mt_music_l0

off_note
        ld      a,(arpeggio)
        inc     a
        cp      3
        jr      nz,arpeggio_max
        xor     a
arpeggio_max
        ld      (arpeggio),a

patadr_set1
        ld ix,0
        xor     a
        ld      (channel),a
        ld      iy,pos_temp_ch0
        ld      b,4
offnote1
        push    bc
        ld      a,(ix+PAT_EFFECT)
        and #f0
        jp      z,offncom_0
        cp      #10
        jp      z,offncom_1
        cp      #20
        jp      z,offncom_2
        cp      #30
        jp      z,offncom_3
        cp      #40
        jp      z,offncom_4
        cp      #50
        jp      z,offncom_5
        cp      #60
        jp      z,offncom_6
        cp      #70
        jp      z,offncom_7
        cp      #A0
        jp      z,offncom_A
        cp      #B0
        jp      z,offncom_B
        cp      #E0
        jr      nz,of_return
        ld      a,(ix+PAT_FXDATA)
        and     %11110000
        cp      #60
        jp      z,offncom_E6
        cp      #90
        jp      z,offncom_E9
        cp      #C0
        jp      z,offncom_EC
        cp      #D0
        jp      z,offncom_ED
of_return
        pop     bc
        call    mt_addadr
        ld      a,(channel)
        cp      255
        jr      z,of_return1
        inc     a
        ld      (channel),a
of_return1
        djnz    offnote1
        ld a,(vblanks)
        dec a
        ret nz
        call mt_addstep
        call patadr                 ;hl=pattern data
        ld (patadr_set1+2),hl
        ld (patadr_set2+2),hl
        ret                 ;mt_exit

offncom_0
        ld      a,(ix+PAT_FXDATA)
        or      a
        jr      z,of_return
    
        ld      a,(arpeggio)
        ld      l,(iy+n_period+0)
        ld      h,(iy+n_period+1)
        or      a
        jr      z,offncom_09        ;arp0 -> hl=n_period
        ld      l,(iy+n_notenum)
        ld      h,0
        cp      1
        ld      a,(ix+PAT_FXDATA)
        jr      nz,offncom_02       ;arp1/2 -> hl=n_notenum, a=offset 0/1
        rrca
        rrca
        rrca
        rrca
offncom_02
        and     %1111
offncom_08
        ld      e,a
        ld      d,0
        add     hl,de               ;hl=notenum + offset
        ld      a,(iy+n_notenum)
        push    af
        call    mt_setnotep     ;add finetunes
        pop     af
        ld      (iy+n_notenum),a
        ld (iy+n_changed),1
        call    op4ton
        jr      of_return
offncom_09
        ld (iy+n_changed),0
        call    op4ton
        jr      of_return

offncom_1
        ld      e,(ix+PAT_FXDATA)
        ld      l,(iy+n_period+0)
        ld      h,(iy+n_period+1)
        xor a
        ld      d,a
        sbc     hl,de
        ld      de,108
        call    clccmp
        jr      nc,offncom_11
        ld      hl,108
offncom_11
        ld      (iy+n_period+0),l
        ld      (iy+n_period+1),h
        call    op4ton
        jp      of_return

offncom_2
        ld      e,(ix+PAT_FXDATA)
        ld      d,0
        ld      l,(iy+n_period+0)
        ld      h,(iy+n_period+1)
        add     hl,de
        ld      de,907+1
        call    clccmp
        jr      c,offncom_21
        ld      hl,907
offncom_21
        ld      (iy+n_period+0),l
        ld      (iy+n_period+1),h
        call    op4ton
        jp      of_return

offncom_3
        call    offncom_30
        jp      of_return
offncom_30
        ld      l,(iy+n_period+0)   ;get current note
        ld      h,(iy+n_period+1)
        ld      e,(iy+n_cmdtemp+0)  ;get new note
        ld      d,(iy+n_cmdtemp+1)
        call    clccmp
        jp      z,op4ton            ;curnote = newnote

        jr      c,offncom_31
        push    de      ;curnote > newnote (pitch down)
        ld      e,(iy+n_oldpbendsp)
        ld      d,0
        sbc     hl,de
        pop     de
        jr      c,offncom_34
        call    clccmp
        jr      nc,offncom_32
offncom_34
        ex      de,hl
        jr      offncom_32
offncom_31
        push    de      ;curnote < newnote  (pitch up)
        ld      e,(iy+n_oldpbendsp)
        ld      d,0
        add     hl,de
        pop     de
        inc     de
        call    clccmp
        jr      c,offncom_32
        dec     de
        ex      de,hl
offncom_32
        ld      (iy+n_period+0),l
        ld      (iy+n_period+1),h
        jp      op4ton

offncom_4
        call    offncom_40
        jp      of_return
offncom_40
        ld      a,(iy+n_vibtabpos)
        rrca            ;lsr.w #2,{a}
        rrca
        and     #1f     ;and.w #$001F,{a}
        ld      e,a
        ld      d,0
        ld      a,(iy+n_wavectrl)
        and     %11
        jr      z,offncom_42

        sla     e       ;lsl.b #3,{bc}
        sla     e
        sla     e
        cp      1
        jr      z,offncom_41    ;vib_rampdown
        ld      e,255
        jr      offncom_43
offncom_41      ;mt_vib_rampdown
        ld      a,(iy+n_vibtabpos)
        bit     7,a
        jr      z,offncom_43
        ld      a,255
        sub     e
        ld      e,a
        jr      offncom_43
offncom_42      ;mt_vib_sine
        ld      hl,vib_tab
        add     hl,de
        ld      e,(hl)
offncom_43      ;mt_vib_set
        ld      a,(iy+n_oldvibcmd)
        and     %1111   ;and.w #15,{a}
        add a
        ld h,a          ;0-15 *2
        call clcmu8     ;hl=h*e
        ld e,h
        ld d,0          ;de=hl/(128*2)
        ld      l,(iy+n_period+0)   ;move.w n_period,{hl}
        ld      h,(iy+n_period+1)

        ld      a,(iy+n_vibtabpos)
        or a
        jp      m,offncom_44
        add     hl,de
        jr      offncom_45
offncom_44      ;mt_VibratoNeg
        sbc     hl,de
offncom_45      ;mt_vibrato3
        ld      (iy+n_cmdtemp+0),l
        ld      (iy+n_cmdtemp+1),h
        ld (iy+n_changed),1
        call    op4ton
        ld      a,(iy+n_oldvibcmd)
        rrca
        rrca
        and     %111100
        add     (iy+n_vibtabpos)
        ld      (iy+n_vibtabpos),a
        ret

offncom_5
        call    offncom_30
        jp      offncom_A

offncom_6
        call    offncom_40
        jr      offncom_A

offncom_7
        ld      a,(iy+n_tremtabpos)
        rrca            ;lsr.w #2,{a} 
        rrca
        and     #1f     ;and.w #$001F,{a} 
        ld      e,a
        ld      d,0
        ld      a,(iy+n_wavectrl)
        rrca
        rrca
        and     %11
        jr      z,offncom_72

        sla     e       ;lsl.b #3,{bc} 
        sla     e
        sla     e
        cp      1
        jr      z,offncom_71    ;trem_rampdown
        ld      e,255
        jr      offncom_73
offncom_71      ;mt_trem_rampdown
        ld      a,(iy+n_tremtabpos)
        bit     7,a
        jr      z,offncom_73
        ld      a,255
        sub     e
        ld      e,a
        jr      offncom_73
offncom_72      ;mt_trem_sine
        ld      hl,vib_tab
        add     hl,de
        ld      e,(hl)
offncom_73      ;mt_trem_set
        ld      a,(iy+n_oldtremcmd)
        and     %1111   ;and.w #15,{a} 
        add a:add a     ;*4
        ld      h,a
        call    clcmu8  ;hl=h*e
        ld e,h
        ld d,0          ;de=hl/(256*4)=hl/64

        ld      l,(iy+n_volume) ;move.w n_volume,{hl}
        ld      h,0

        ld      a,(iy+n_tremtabpos)
        bit     7,a
        jr      nz,offncom_74
        add     hl,de
        jr      offncom_75
offncom_74      ;mt_tremoloNeg
        or a
        sbc     hl,de
        jr      nc,offncom_75
        ld      hl,0
offncom_75      ;mt_tremolo3
        ld      a,l
        cp      #41
        jr      c,offncom_76
        ld      l,#40
offncom_76
        ld      e,l
        call    op4vch

        ld      a,(iy+n_oldtremcmd)
        rrca
        rrca
        and     %111100
        add     (iy+n_tremtabpos)
        ld      (iy+n_tremtabpos),a
        jp      of_return

offncom_A
        ld      a,(ix+PAT_FXDATA)
        cp      #10
        jr      nc,offncom_A1
        and     %1111
        ld      b,a
        ld      a,(iy+n_volume)
        sub     b
        jr      nc,offncom_A2
        xor     a
        jr      offncom_a2
offncom_A1
        rrca
        rrca
        rrca
        rrca
        and     %1111
        ld      b,a
        ld      a,(iy+n_volume)
        add     b
        cp      #41
        jr      c,offncom_A2
        ld      a,#40
offncom_A2
        ld      (iy+n_volume),a
        ld e,a
        call    op4vch
        jp      of_return

offncom_B
        ld a,(vblanks)
        dec a
        jp nz,of_return             ;only check at division end
        ld a,(song_pos)
        ld b,a
        ld a,(song_length)
        dec a
        cp b
        jr nz,offncom_B1
        ld a,(repeat_song)          ;song end reached
        or a
        jr nz,offncom_B1
        call mt_stop                ;and no repeat -> stop
        jp of_return
offncom_B1
        ld a,(ix+PAT_FXDATA)
        inc a
        jr z,offncom_B2
        dec a
        ld (song_pos),a             ;** position jump (Bxx)
        ld a,128
        ld (song_step),a
        jp of_return
offncom_B2
        ld a,(song_step)            ;** pattern break (BFF)
        bit 7,a
        jp nz,of_return
        ld a,128
        ld (song_step),a
        ld a,(song_length)
        ld b,a
        ld a,(song_pos)
        inc a
        cp b
        jr c,offncom_B3
        xor a
offncom_B3
        ld (song_pos),a
        jp of_return

offncom_E6
        ld      a,(vblanks)
        dec a
        jp      nz,of_return
        ld      a,(ix+PAT_FXDATA)
        and     %1111
        jr      nz,offncom_E61
        ld      a,(song_step)
        ld      (iy+n_pattloop),a       ;store loop start
        jp      of_return
offncom_E61
        ld      b,a                     ;loop end reached, b=number of loops
        ld      a,(iy+n_pattloop+1)     ;a=already done loops
        inc     a
        inc     b
        cp      b                       ;=total loops?
        jr      nz,offncom_E62
        xor     a                       ;yes, finish, reset done loops
        ld      (iy+n_pattloop+1),a
        jp      of_return
offncom_E62
        ld      (iy+n_pattloop+1),a     ;no, increase
        ld      a,(iy+n_pattloop)
        set     7,a
        ld      (song_step),a           ;jump to loop begin
        jp      of_return


offncom_E9
        ld      a,(iy+n_cmdtemp)
        or      a
        jr      z,offncom_E91
        dec     a
        ld      (iy+n_cmdtemp),a
        or      a
        jp      nz,of_return
        ld      a,(ix+PAT_FXDATA)
        and     %1111
        ld      (iy+n_cmdtemp),a
offncom_E91
        call    mt_newnote
        jp      of_return

offncom_EC
        ld      a,(iy+n_cmdtemp)
        or      a
        jp      z,of_return
        dec     a
        ld      (iy+n_cmdtemp),a
        or      a
        jp      nz,of_return
        xor     a
        jp      offncom_A2

offncom_ED
        ld      a,(iy+n_cmdtemp)
        or      a
        jp      z,of_return
        dec     a
        ld      (iy+n_cmdtemp),a
        or      a
        jp      nz,of_return
        jr      offncom_E91

mt_music_l0
        ld      a,(vblanks+1)
        ld      (vblanks),a

        ld      a,(command_EEtemp)
        or      a
        jr      z,mt_music_l1
        dec     a
        ld      (command_EEtemp),a
        ret                         ;mt_exit

mt_music_l1

        ld      a,(Channel)
        cp      255
        ret z                       ;mt_exit
patadr_set2
        ld ix,0
        xor     a
        ld      (channel),a

        ld      iy,pos_temp_ch0

        ld      b,4
mt_music_l2
        push    bc

        xor     a
        ld      (command_E5temp),a
        call    mt_setsampl
        ld      a,(ix+PAT_EFFECT)
        and #f0
        jp      z,command_0
        cp      #C0
        jp      z,command_C
        cp      #40
        jp      z,command_4
        cp      #70
        jp      z,command_7
        cp      #f0
        jp      z,command_F
        cp      #E0
        jr      nz,mt_return
        ld      a,(ix+PAT_FXDATA)
        and     %11110000
        cp      #40
        jp      z,command_E4
        cp      #50
        jp      z,command_E5
        cp      #70
        jp      z,command_E7
        cp      #90
        jp      z,command_E9
        cp      #A0
        jp      z,command_EA
        cp      #B0
        jp      z,command_EB
        cp      #C0
        jp      z,command_EC
        cp      #D0
        jp      z,command_ED
        cp      #E0
        jp      z,command_EE
mt_return
        call    mt_newnote
        ld      a,(ix+PAT_EFFECT)
        and #f0
        cp      #e0
        jr      nz,mt_return_ED
        ld      a,(ix+PAT_FXDATA)
        and     %11110000
        cp      #10
        call    z,command_E1
        cp      #20
        call    z,command_E2
mt_return_ED

        bit 0,(iy+n_changed)
        jr z,mt_return_1
        ld l,(iy+n_period+0)    ;only necessary after arpeggio/vibrato and no new period
        ld h,(iy+n_period+1)
        call op4ton
        ld (iy+n_changed),0
mt_return_1

        call op4kon
        ld e,(iy+n_volume)
        call op4vch

        call    mt_addadr

        ld hl,channel
        inc (hl)

        ld      a,(mt_stopflag)
        or      a
        call    nz,mt_stop
        pop     bc
        dec     b
        jp      nz,mt_music_l2
        ret             ;mt_exit

mt_addstep
        ld      a,(song_step)
        bit     7,a
        jr      z,mt_addstep0
        res     7,a
        ld      (song_step),a
        ret
mt_addstep0
        inc     a
        cp      64
        jr      nz,mt_addstep2

        ld      a,(song_length)
        ld      b,a
        ld      a,(song_pos)
        inc     a
        cp      b
        jr      c,mt_addstep1
        ld      a,(repeat_song)
        or      a
        jr      nz,mt_addstep3
        call    mt_stop
        ret
mt_addstep3
        xor     a
mt_addstep1
        ld      (song_pos),a
        xor     a
mt_addstep2
        ld      (song_step),a
        ret

mt_addadr
        ld      de,4
        add     ix,de
        ld      de,temp_size
        add     iy,de
        ret

mt_setsampl
        ld      a,(ix+PAT_SAMPLE)
        or      a
        ret     z
        ld      (iy+n_sampnum),a
        dec     a
        ld      e,a
        ld      d,0
        ld      hl,volumes
        add     hl,de
        ld      a,(hl)
        ld      (iy+n_volume),a ;set standard volume
        ret

mt_newnote
        ld      a,(iy+n_sampnum)        ;get previous set samplenumber
        or      a
        ret     z       ;exit if no samplenumber is set 

        ld a,(ix+PAT_NOTE)
        or a
        ret     z       ;exit if no note specified 
        ld l,a
        ld h,0

        ld      a,(ix+PAT_EFFECT)
        and #f0
        cp      #30
        jr      z,command_3
        cp      #50
        jr      nz,no_comm_3
command_3
        ld      a,(ix+PAT_FXDATA)
        or      a
        jr      z,command_5
        ld      (iy+n_oldpbendsp),a
command_5
        call    mt_setnotep     ;add finetunes  
        ld      a,h
        or      l
        ret     z
        ld      (iy+n_cmdtemp),l        ;in command temp.
        ld      (iy+n_cmdtemp+1),h
        ret

no_comm_3
        push    hl

        call op4kof             ;122
        call op4smp             ;60

        pop hl
        call mt_setnotep        ;76     convert [hl] (nontuned) into tuned 
        ld (iy+n_period+0),l
        ld (iy+n_period+1),h
        ld (iy+n_changed),0
        jp op4ton               ;97

;l=notenum -> (iy+n_notenum)=notenum, hl=period
mt_setnotep
        ld h,0
        inc l:dec l
        ret     z               ;exit if no period in pos_temp_ch
        ld (iy+n_notenum),l
        ld c,l
        ld b,h                  ;bc=notenum
        ld de,periods
        add hl,hl
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ;de=period
        push de                 ;push period

        ld a,(command_E5temp)
        or a
        ld d,b
        jr nz,mt_setnotep0
        ld e,(iy+n_sampnum)     ;get samplenumber
        dec e
        ld hl,finetunes         ;get finetune of sample 
        add hl,de
        ld a,(hl)
mt_setnotep0
        ld e,d
        or a
        jr z,mt_setnotep1       ;fintune=0 -> do not alter 

        dec a
;a=0-14
        ld l,a
        add a
        add a
        add a       ;*8
        add l       ;*9
        ld l,a
        ld h,d
        add hl,hl   ;*18
        add hl,hl   ;*36    14

        ld de,ft_tab
        add hl,de
        add hl,bc               ;add note offset
        ld e,(hl)
        ld d,0
        bit 7,e
        jr z,mt_setnotep1
        ld d,255
mt_setnotep1
        pop hl
        add hl,de
        ret


command_0
        xor     a
        ld      (arpeggio),a
        jp      mt_return

command_4
        ld l,(iy+n_period+0)
        ld h,(iy+n_period+1)
        ld (iy+n_cmdtemp+0),h
        ld (iy+n_cmdtemp+1),l

        ld a,(ix+PAT_FXDATA)
        or a
        jp z,mt_return
        ld c,a
        ld e,(iy+n_oldvibcmd)
        and #f0
        jr z,command_41
        ld b,a
        ld a,e
        and #0f
        or b
        ld e,a
command_41
        ld a,c
        and #0f
        jr z,command_42
        ld b,a
        ld a,e
        and #f0
        or b
        ld e,a
command_42
        ld (iy+n_oldvibcmd),e
        jp mt_return

command_7
        ld a,(ix+PAT_FXDATA)
        or a
        jp z,mt_return
        ld c,a
        ld e,(iy+n_oldtremcmd)
        and #f0
        jr z,command_71
        ld b,a
        ld a,e
        and #0f
        or b
        ld e,a
command_71
        ld a,c
        and #0f
        jr z,command_72
        ld b,a
        ld a,e
        and #f0
        or b
        ld e,a
command_72
        ld (iy+n_oldtremcmd),e
        jp mt_return

command_C
        ld a,(ix+PAT_FXDATA)
        cp #41
        jr c,command_C1
        ld a,#40
command_C1
        ld (iy+n_volume),a
        ld e,a
        call op4vch
        jp mt_return

command_E1
        push af
        ld a,(ix+PAT_FXDATA)
        and #0f
        ld e,a
        ld d,0
        ld l,(iy+n_period+0)
        ld h,(iy+n_period+1)
        sbc hl,de
        ld de,108
        call clccmp
        jr nc,command_E11
        ld hl,108
command_E11
        ld (iy+n_period+0),l
        ld (iy+n_period+1),h
        call op4ton
        pop af
        ret

command_E2
        push af
        ld a,(ix+PAT_FXDATA)
        and #0f
        ld e,a
        ld d,0
        ld l,(iy+n_period+0)
        ld h,(iy+n_period+1)
        add hl,de
        ld de,907+1
        call clccmp
        jr c,command_E11
        ld hl,907
        jr command_E11

command_E4
        ld      a,(ix+PAT_FXDATA)
        and     %11
        ld      b,a
        ld      a,(iy+n_wavectrl)
        and     %11111100
        or      b
        ld      (iy+n_wavectrl),a
        xor     a
        ld      (iy+n_vibtabpos),a
        jp      mt_return

command_E5
        ld      a,(ix+PAT_FXDATA)
        and     %1111
        ld      (command_E5temp),a
        jp      mt_return

command_E7
        ld      a,(ix+PAT_FXDATA)
        rlca
        rlca
        and     %1100
        ld      b,a
        ld      a,(iy+n_wavectrl)
        and     %11110011
        or      b
        ld      (iy+n_wavectrl),a
        xor     a
        ld      (iy+n_tremtabpos),a
        jp      mt_return

command_E9
        ld      a,(ix+PAT_FXDATA)
        and     %1111
        ld      (iy+n_cmdtemp),a
        jp      mt_return

command_EA
        ld      a,(ix+PAT_FXDATA)
        rrca
        rrca
        rrca
        rrca
        and     %1111
        ld      b,a
        ld      a,(iy+n_volume)
        add     b
        cp      #41
        jr      c,command_EA1
        ld      a,#40
command_EA1
        ld      (iy+n_volume),a
        ld e,a
        call    op4vch
        jp      mt_return

command_EB
        ld      a,(ix+PAT_FXDATA)
        and     %1111
        ld      b,a
        ld      a,(iy+n_volume)
        sub     b
        jr      nc,command_EA1
        xor     a
        jr      command_EA1

command_EC
        ld      a,(ix+PAT_FXDATA)
        and     %1111
        jr      z,command_EC1
        inc     a
        ld      (iy+n_cmdtemp),a
        jp      mt_return
command_EC1
        xor     a
        ld      (iy+n_volume),a
        jp      mt_return

command_ED
        ld      a,(ix+PAT_FXDATA)
        and     %1111
        jp      z,mt_return
        inc     a
        ld      (iy+n_cmdtemp),a
        jp      mt_return_ED

command_EE
        ld      a,(ix+PAT_FXDATA)
        and     %1111
        ld      (command_EEtemp),a
        jp      mt_return

command_F
        ld      a,(ix+PAT_FXDATA)
        ld      (vblanks+1),a
        ld      (vblanks),a
        jp      mt_return


;==============================================================================
;### PATTERN DATA HANDLING ####################################################
;==============================================================================

patlstpos   db 0    ;last position in songlist
patlstpat   db 0    ;last pattern

patlstlin   db 0    ;last line (1-64, 0=new)
patlstdst   dw 0    ;last destination
patdcrlin   db 0    ;uncompressed lines+1 (2-65, 1=none)


;### PATADR -> gets address of current pattern row
;### Input      (song_pos)=current position in songlist, (song_step)=current position in pattern
;### Output     HL=address
;### Destroyed  AF,BC,DE,HL
patadr  ld a,(song_pos)
        ld hl,patlstpos
        cp (hl)
        jr z,patadr3            ;same pattern
        ld (hl),a
        ld e,a
        ld d,0
        ld hl,patterns
        add hl,de
        ld a,(hl)
        ld hl,patlstpat
        cp (hl)
        jr z,patadr3            ;same pattern
        ld (hl),a                   ;** new pattern
        ld l,a
        xor a
        ld h,a
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(op4patadr)
        add hl,de
        ld de,chndcrmem
        ld bc,4*256+255
patadr1 ld (de),a
        inc de:inc de
        ldi:ldi
        djnz patadr1
        ld (patlstlin),a
        inc a
        ld (patdcrlin),a
patadr2 ld hl,0                 ;=1024B pattern buffer-4*4
        ld (patlstdst),hl
patadr3 ld a,(song_step)            ;** position in current pattern
        res 7,a
        inc a
        ld hl,patlstlin
        cp (hl)
        jr z,patadr4            ;same position
        ld (hl),a
        jr c,patadr5            ;lower position
        ld hl,(patlstdst)       ;higher position
        ld de,4*4
        add hl,de
        ld (patlstdst),hl
        ex de,hl
        ld hl,patdcrlin
        cp (hl)
        jr c,patadr4            ;not new -> already uncompressed
        inc (hl)
        call patdcr             ;uncompress new position
patadr4 ld hl,(patlstdst)
        ret
patadr5 dec a                   ;lower position -> recalculate last destination
        add a:add a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
patadr6 ld de,0                 ;=1024B pattern buffer
        add hl,de
        ld (patlstdst),hl
        ret

;### PATDCR -> unpacks one pattern row
;### Input      DE=destination row
;### Output     DE=next row
;### Destroyed  AF,BC,HL,IXL

;MOD packing
;00iiiiii 00nnnnnn eeee0000 dddddddd -> 4 byte note data (instument, note, effect, effect data)
;01rrrrrr                            -> use again note data from position actual-(64-r)
;10rrrrrr                            -> r+1 empty notes
;11rrrrrr                            -> repeat last note r+1 times

chndcrmod   equ 0   ;repeat mode -> 0=nothing, 1=empty, 2=last
chndcrcnt   equ 1   ;count remaining slots
chndcrsrc   equ 2   ;source address
chndcrlen   equ 4

chndcrmax   equ 4
chndcrmem   ds chndcrlen*chndcrmax

patdcr  ld ixl,4
        ld hl,chndcrmem
patdcra ld a,(hl)               ;check current mode
        inc hl
        or a
        jr z,patdcr3
        dec (hl)
        jr z,patdcr3
patdcr0 dec a
        jr nz,patdcr1
        ld (de),a:inc de            ;** empty
        ld (de),a:inc de
        ld (de),a:inc de
        ld (de),a:inc de
        jr patdcr8
patdcr1 push hl                     ;** last
        ld hl,-16               ;4 channels
        add hl,de
        ldi:ldi:ldi:ldi
        pop hl
patdcr8 inc hl                  ;next channel
patdcr9 inc hl
patdcr5 inc hl
        dec ixl
        jr nz,patdcra
        ret
patdcr3 dec hl                      ;** load next from source
        ld (patdcr6+1),hl
        inc hl  
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld a,(bc)
        inc bc
        bit 7,a
        jr nz,patdcr7
        bit 6,a
        jr nz,patdcr4

        ld (de),a:inc de:ld a,(bc):inc bc
        ld (de),a:inc de:ld a,(bc):inc bc
        ld (de),a:inc de:ld a,(bc):inc bc
        ld (de),a:inc de            ;** add new note
        ld (hl),b
        dec hl
        ld (hl),c
        xor a
patdcr6 ld (0),a
        jr patdcr9

patdcr4 rla:rla                     ;** copy note from curpos-64+x
        push hl
        ld (hl),b
        dec hl
        ld (hl),c
        dec hl
        dec hl
        ld (hl),0
        ld l,a
        ld h,-1
        add hl,hl
        add hl,hl               ;4 channel
        add hl,de
        ldi:ldi:ldi:ldi
        pop hl
        jr patdcr5

patdcr7 ld (hl),b                   ;** start new repeat mode
        dec hl
        ld (hl),c
        dec hl
        ld c,a
        and 63
        inc a
        ld (hl),a
        dec hl
        ld a,c
        rlca:rlca
        and 1
        inc a
        ld (hl),a
        inc hl
        jr patdcr0


;==============================================================================
;### SAMPLE DATA HANDLING #####################################################
;==============================================================================

smphed  db 0,0,0        ;address (high,mid,low)
        db 0,0          ;loop (high,low)
        db 0,0          ;end (high,low)
        db 0            ;lfo, vib
        db %11111111    ;ar, d1r
        db 0            ;dl, d2r
        db 0            ;rate comp, rr
        db 0            ;am

;### SMPO4I -> reserves opl4 sample ID
;### Output     CF=0 ok, C=sample ID
;###            CF=1 no free ID
;### Destroyed  AF,B,HL
smpo4it ds 256-64   ;flags, if opl4 sample (64-255) reserved

smpo4i  ld c,64
        ld hl,smpo4it
        ld b,256-64
        xor a
smpo4i1 cp (hl)
        jr z,smpo4i2
        inc hl
        inc c
        djnz smpo4i1
        scf
        ret
smpo4i2 inc (hl)
        ret

;### SMPEFX -> loads all samples from an effect collection
;### Input      A=file handle, HL=effect collection data record
;### Output     CF=0 -> ok, CF=1 error (A=error code)
;### Destroyed  AF,BC,DE,HL,IX,IY
smpefx  ld (smpefx3+1),hl
        push af
        push hl

        ld a,(op4ply)
        rrca
        add #37
        ld (smpefx4),a
        call op4stp

        call op4res
        ld d,7
        call op4vma
        ld hl,opl4_load     ;switch opl4 to load mode
        call op4set
        pop ix
        pop hl              ;h=file handle
        ld b,(ix+0)         ;b=sample count
        inc ix              ;ix=sample records
smpefx1 push bc
        ex de,hl
        call smpo4i
        ld a,snderrme4
        jr c,smpefx3
        ex de,hl
        ld l,c
        ld (ix+smpop4vol),l
        push hl
        push ix
        call smpnew
        pop ix
        pop hl
smpefx2 pop bc
        jr c,smpefx3
        ld de,smpop4len
        add ix,de
        djnz smpefx1

smpefx4 db 0
        push af
        call nc,mt_start1
        pop af
        call nc,op4mpl
        ld hl,opl4_play     ;switch opl4 to play mode
        call op4set
        ld d,0
        jp op4vma

smpefx3 ld hl,0             ;error -> remove all loaded effects
        push af
        call smpefr
        call smpefx4
        pop af
        ret

;### SMPEFR -> removes all already reserved/loaded samples from an effect collection
;### Input      HL=effect collection data record
;### Destroyed  AF,BC,DE,HL,IX
smpefr  ld b,(hl)
        inc hl
        push hl:pop ix
smpefr1 ld c,(ix+smpop4vol)
        inc c:dec c
        ret z
        push bc
        ld b,0
        ld (ix+smpop4vol),b
        ld hl,smpo4it-64
        add hl,bc
        ld (hl),b
        push ix
        ld l,(ix+smpop4adr+0)
        ld h,(ix+smpop4adr+1)
        ld c,(ix+smpop4siz+0)
        ld b,(ix+smpop4siz+1)
        call smpfre
        pop ix
        ld bc,smpop4len
        add ix,bc
        pop bc
        djnz smpefr1
        ret

;### SMPALL -> loads all samples for a music
;### Input      A=file handle
;### Output     CF=0 -> ok, CF=1 error (A=error code)
;### Destroyed  AF,BC,DE,HL,IX,IY
smpall  push af
        call op4res
        ld d,7
        call op4vma
        ld hl,opl4_load     ;switch opl4 to load mode
        call op4set
        pop hl              ;h=file handle
        ld a,(snddatmem+SWM_NUMSMP)
        ld b,a              ;b=sample count
        ld ix,(op4smpadr)   ;ix=sample records
        ld l,0              ;l=sample ID
smpall1 push bc
        push hl
        push ix
        call smpnew
        pop ix
        pop hl
        pop bc
        jr c,smpall2
        inc l
        ld de,smpop4len
        add ix,de
        djnz smpall1
smpall0 ld hl,opl4_play     ;switch opl4 to play mode
        call op4set
        ld d,0
        jp op4vma
smpall2 push af             ;error -> remove all already loaded samples
        call smprem
        call smpall0
        pop af
        ret

;### SMPREM -> removes all samples from a music
;### Destroyed  AF,BC,HL,IX
smprem  ld bc,(snddatmem+SWM_NUMSMP-1)
        ld hl,(op4smpadr)
        ld c,0
smprem1 push bc
        push hl
        ld e,(hl)
        ld (hl),c
        inc hl
        ld d,(hl)
        ld (hl),c
        inc hl
        ld a,e
        or d
        jr z,smprem2
        ld c,(hl):inc hl
        ld b,(hl)
        ex de,hl
        call smpfre
smprem2 pop hl
        ld bc,smpop4len
        add hl,bc
        pop bc
        djnz smprem1
        ret

;### SMPNEW -> creates new sample
;### Input      H=file handle, IX=sample data record, L=opl4 sample ID (0-62=music, 64-255=effects)
;### Output     CF=0 -> ok, CF=1 error (A=error code)
;### Destroyed  AF,BC,DE,HL,IX,IY
smpnew  push hl
        ld c,(ix+smpop4siz+0)
        ld b,(ix+smpop4siz+1)
        push ix
        push bc
        call smpres             ;reserve opl4 memory
        pop bc
        pop ix
        pop de
        ld a,snderrme4
        ret c
        ld (ix+smpop4adr+0),l
        ld (ix+smpop4adr+1),h
        ld a,d
        push de
        push ix
        call smplod             ;load into opl4 ram
        ;...add 3 additional bytes at the end, see mod player ##!!##
        pop ix
        pop de                  ;E=sample ID
        ret c
        ld h,(ix+smpop4adr+0)
        ld l,(ix+smpop4adr+1)
        set 5,l
        ld (smphed+0),hl        ;set start address

        ld l,(ix+smpop4siz+0)
        ld h,(ix+smpop4siz+1)   ;hl=length+3bytes
        ld bc,-3
        add hl,bc
        ld c,l
        ld l,h
        ld h,c                  ;lh=length

        ld b,(ix+smpop4rep+0)
        ld c,(ix+smpop4rep+1)   ;cb=repeat
        ld a,c:and b:inc a
        jr nz,smpnew1
        ld b,h:ld c,l           ;no repeat -> repeat = length
smpnew1 ld (smphed+3),bc        ;set loop point
        ld a,l:cpl:ld l,a
        ld a,h:cpl:ld h,a
        ld (smphed+5),hl        ;set inverted length
        ld d,0
        ld a,e
        cp 64
        jr nc,smpnew2
        ld hl,volumes           ;music sample -> use volume and finetune
        add hl,de
        ld a,(ix+smpop4vol)
        ld (hl),a
        ld hl,finetunes
        add hl,de
        ld a,(ix+smpop4fin)
        ld (hl),a
smpnew2 ex de,hl
        add hl,hl
        add hl,hl           ;*4
        ld e,l:ld d,h
        add hl,hl
        add hl,hl           ;*16
        sbc hl,de           ;*12
        ld e,0
        call op4adr
        ld de,12
        ld hl,smphed
        call smplod5            ;copy wave header into opl4 ram
        or a
        ret

;### SMPLOD -> loads sample from opened file into OPL4 ram
;### Input      A=file handle, HL=address (high part), BC=length
;### Output     CF=0 -> ok, CF=1 -> disc error (A=error code)
;### Destroyed  AF,BC,DE,HL,IX,IY
smplod  ld (smplod3+1),a
        push bc
        ld e,h
        ld h,l
        ld l,0
        call op4adr
        pop de
smplod1 ld a,e
        or d
        ret z           ;remain=0 -> finished
        ld hl,1024
        sbc hl,de
        ex de,hl        ;hl=remain
        ld c,l
        ld b,h
        jr nc,smplod2   ;bufsiz > remain -> use remain
        ld bc,1024      ;bufsiz <= remain -> use bufsiz
smplod2 or a
        sbc hl,bc
        push hl
        ld a,(App_BnkNum)
        ld e,a
smplod3 ld a,0
        ld hl,(patadr6+1)
        push hl
        call SyFile_FILINP  ;load from file
        pop hl
        jr c,smplod4
        ld e,c
        ld d,b          ;de=length
        call smplod5
        pop de
        jr smplod1

smplod4 pop hl
        ld a,snderrfil
        ret

smplod5 ld bc,OPL4_REG  ;hl=source, de=length
        di
        opl4_wt 
        ld a,6          ;select data register
        out (c),a
        inc c

smplod6 opl4_wt         ;9  copy data to opl4 ram
        ld a,(hl)       ;2
        out (c),a       ;4
        inc hl          ;2
        dec de          ;2
        ld a,d          ;1
        or e            ;1
        jr nz,smplod6   ;3 -> 15 + 9
        ei
        ret

if 0    ;fast variant, has nearly no effect (???)
        inc d
        dec d
        jr z,smplod9
smplod8 ld a,256/32
smplod7 inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi
        inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi
        inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi
        inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi:inc b:outi
        dec a
        jr nz,smplod7
        dec d
        jr nz,smplod8
smplod9 inc e
        dec e
        ret z
smplod6 inc b:outi
        dec e
        jr nz,smplod6
        ei
        ret
endif


smpbtn  equ 2048/256*1024       ;number of bits
smpmem  db %11111111,%00001111  ;sample headers (use the first 12*256)
        ds smpbtn/8-2           ;reserved sample memory (bit=1 -> 256byte reserved)
smppag  dw 12                   ;reserved 256 byte pages

;### SMPRES -> reserve memory for one sample
;### Input      BC=length in bytes
;### Ausgabe    CF=0-> HL=upper address (*256)
;###            CF=1-> memory full
;### Veraendert AF,BC,DE,HL,IX,IY
smpres  call smpbtl             ;ix=number of required 256byte pages
        ld hl,12                ;hl=start page
        ld de,smpbtn-12         ;de=number of total available 256pages

smpres1 call smpbtt             ;test, if free page
        jr z,smpres4            ;yes -> check, if enough free pages
smpres2 inc hl
        dec de                  ;no -> next
        ld a,e
        or d
        jr nz,smpres1
smpres3 scf                     ;no page left -> memory full
        ret

smpres4 ld c,ixl:ld b,ixh       ;bc=required 256 pages
        push hl:pop iy          ;iy=possible start page
smpres5 push bc
        call smpbtt
        pop bc
        jr nz,smpres2           ;not free -> continue
        inc hl
        dec bc
        ld a,c
        or b
        jr z,smpres6            ;all required are free -> take it!
        dec de
        ld a,e
        or d
        jr nz,smpres5           ;test remaining ones
        jr smpres3
smpres6 push ix:pop de
        ld hl,(smppag)
        add hl,de
        ld (smppag),hl
        push iy:pop hl          ;hl=start of free pages
        push hl
smpres7 call smpbts             ;reserve required pages
        inc hl
        dec de
        ld a,e:or d
        jr nz,smpres7
        pop hl                  ;return start page/upper address
        ret

;### SMPFRE -> release sample memory
;### Input      HL=upper address (*256), BC=length
;### Destroyed  AF,BC,DE,HL,IX
smpfre  call smpbtl
        push ix:pop de
        ld hl,(smppag)
        or a
        sbc hl,de
        ld (smppag),hl
smpfre1 call smpbtc
        inc hl
        dec de
        ld a,e
        or d
        jr nz,smpfre1
        ret

;### SMPBTL -> get number of pages/bits
;### Input      BC=length (1-65535)
;### Output     IX=number of 256byte pages
;### Destroyed  F
smpbtl  ld ixh,0
        ld ixl,b
        inc c:dec c
        ret z
        inc ix                  ;ix=number of required 256pages
        ret

;### SMPBTA -> Bitadresse holen
;### Eingabe    HL=Bitnummer (0-8191)
;### Ausgabe    HL=Adresse, A=Maske (00000001 - 10000000)
;### Verändert  BC
smpbta  ld a,l
        srl h:rr l
        srl h:rr l
        srl h:rr l
        ld bc,smpmem
        add hl,bc
        and 7
        ld b,a
        ld a,1
        ret z
smpbta1 rla
        djnz smpbta1
        ret

;### SMPBTT -> Bit testen
;### Eingabe    HL=Bitnummer (0-8191)
;### Ausgabe    ZF=1-> Bit gelöscht, ZF=0-> Bit gesetzt
;### Verändert  AF,BC
smpbtt  push hl
        call smpbta
        and (hl)
        pop hl
        ret

;### SMPBTS -> Bit setzen
;### Eingabe    HL=Bitnummer (0-8191)
;### Verändert  AF,BC
smpbts  push hl
        call smpbta
        or (hl)
        ld (hl),a
        pop hl
        ret

;### SMPBTC -> Bit löschen
;### Eingabe    HL=Bitnummer (0-8191)
;### Verändert  AF,BC
smpbtc  push hl
        call smpbta
        cpl
        and (hl)
        ld (hl),a
        pop hl
        ret


;==============================================================================
;### AMIGA CONVERSION TABLES ##################################################
;==============================================================================

periods
        dw      0
; Tuning 0, Normal
        dw      856,808,762,720,678,640,604,570,538,508,480,453
        dw      428,404,381,360,339,320,302,285,269,254,240,226
        dw      214,202,190,180,170,160,151,143,135,127,120,113
ft_tab
; Tuning 1
        db      -6 ,-6 ,-5 ,-5 ,-4 ,-3 ,-3 ,-3 ,-3 ,-3 ,-3 ,-3
        db      -3 ,-3 ,-2 ,-3 ,-2 ,-2 ,-2 ,-1 ,-1 ,-1 ,-1 ,-1
        db      -1 ,-1 ,-1 ,-1 ,-1 ,-1 ,-1 ,-1 ,-1 ,-1 ,-1 ,0
; Tuning 2
        db      -12,-12,-10,-11,-8 ,-8 ,-7 ,-7 ,-6 ,-6 ,-6 ,-6
        db      -6 ,-6 ,-5 ,-5 ,-4 ,-4 ,-4 ,-3 ,-3 ,-3 ,-3 ,-2
        db      -3 ,-3 ,-2 ,-3 ,-3 ,-2 ,-2 ,-2 ,-2 ,-2 ,-2 ,-1
; Tuning 3
        db      -18,-17,-16,-16,-13,-12,-12,-11,-10,-10,-10,-9
        db      -9 ,-9 ,-8 ,-8 ,-7 ,-6 ,-6 ,-5 ,-5 ,-5 ,-5 ,-4
        db      -5 ,-4 ,-3 ,-4 ,-4 ,-3 ,-3 ,-3 ,-3 ,-2 ,-2 ,-2
; Tuning 4
        db      -24,-23,-21,-21,-18,-17,-16,-15,-14,-13,-13,-12
        db      -12,-12,-11,-10,-9 ,-8 ,-8 ,-7 ,-7 ,-7 ,-7 ,-6
        db      -6 ,-6 ,-5 ,-5 ,-5 ,-4 ,-4 ,-4 ,-4 ,-3 ,-3 ,-3
; Tuning 5
        db      -30,-29,-26,-26,-23,-21,-20,-19,-18,-17,-17,-16
        db      -15,-14,-13,-13,-11,-11,-10,-9 ,-9 ,-9 ,-8 ,-7
        db      -8 ,-7 ,-6 ,-6 ,-6 ,-5 ,-5 ,-5 ,-5 ,-4 ,-4 ,-4
; Tuning 6
        db      -36,-34,-32,-31,-27,-26,-24,-23,-22,-21,-20,-19
        db      -18,-17,-16,-15,-14,-13,-12,-11,-11,-10,-10,-9
        db      -9 ,-9 ,-7 ,-8 ,-7 ,-6 ,-6 ,-6 ,-6 ,-5 ,-5 ,-4
; Tuning 7
        db      -42,-40,-37,-36,-32,-30,-29,-27,-25,-24,-23,-22
        db      -21,-20,-18,-18,-16,-15,-14,-13,-13,-12,-12,-10
        db      -10,-10,-9 ,-9 ,-9 ,-8 ,-7 ,-7 ,-7 ,-6 ,-6 ,-5
; Tuning -8
        db      51,48,46,42,42,38,36,34,32,30,28,27
        db      25,24,23,21,21,19,18,17,16,15,14,14
        db      12,12,12,10,10,10,9 ,8 ,8 ,8 ,7 ,7
; Tuning -7
        db      44,42,40,37,37,35,32,31,29,27,25,24
        db      22,21,20,19,18,17,16,15,15,14,13,12
        db      11,10,10,9 ,9 ,9 ,8 ,7 ,7 ,7 ,6 ,6
; Tuning -6
        db      38,36,34,32,31,30,28,27,25,24,22,21
        db      19,18,17,16,16,15,14,13,13,12,11,11
        db      9 ,9 ,9 ,8 ,7 ,7 ,7 ,6 ,6 ,6 ,5 ,5
; Tuning -5
        db      31,30,29,26,26,25,24,22,21,20,18,17
        db      16,15,14,13,13,12,12,11,11,10,9 ,9
        db      8 ,7 ,8 ,7 ,6 ,6 ,6 ,5 ,5 ,5 ,5 ,5
; Tuning -4
        db      25,24,23,21,21,20,19,18,17,16,14,14
        db      13,12,11,10,11,10,10,9 ,9 ,8 ,7 ,7
        db      6 ,6 ,6 ,5 ,5 ,5 ,5 ,4 ,4 ,4 ,3 ,4
; Tuning -3
        db      19,18,17,16,16,15,15,14,13,12,11,10
        db      9 ,9 ,9 ,9 ,8 ,8 ,7 ,7 ,7 ,6 ,5 ,6
        db      5 ,4 ,5 ,4 ,4 ,4 ,4 ,3 ,3 ,3 ,3 ,3
; Tuning -2
        db      12,12,12,10,11,11,10,10,9 ,8 ,7 ,7
        db      6 ,6 ,6 ,5 ,6 ,5 ,5 ,5 ,5 ,4 ,4 ,4
        db      3 ,3 ,3 ,3 ,2 ,3 ,3 ,2 ,2 ,2 ,2 ,2
; Tuning -1
        db      6 ,6 ,6 ,5 ,6 ,6 ,6 ,5 ,5 ,5 ,4 ,4
        db      3 ,3 ,3 ,3 ,3 ,3 ,3 ,3 ,3 ,2 ,2 ,2
        db      2 ,1 ,2 ,1 ,1 ,1 ,1 ,1 ,1 ,1 ,1 ,1

vib_tab
        db      000,024,049,074,097,120,141,161
        db      180,197,212,224,235,244,250,253
        db      255,253,250,244,235,224,212,197
        db      180,161,141,120,097,074,049,024


;==============================================================================
;### OPL4 ROUTINES ############################################################
;==============================================================================

OPL4_REG    equ #ff7e
OPL4_DATA   equ #ff7f

OPL4_FM_C6  equ #ffc6
OPL4_FM_C7  equ #ffc7

op4_64kbnk  db 0    ;number of 64k banks


opl4_play
        db 2,%00010000
        db #50,254,#51,254,#52,254,#53,254,#54,254,#55,254,#56,254,#57,254  ;mute all channels
        db #58,254,#59,254,#5a,254,#5b,254,#5c,254,#5d,254,#5e,254,#5f,254
        db #60,254,#61,254,#62,254,#63,254,#64,254,#65,254,#66,254,#67,254
        db #20,001,#21,001,#22,001,#23,001,#24,001,#25,001,#26,001,#27,001  ;set upper sample id bit
        db #28,001,#29,001,#2a,001,#2b,001,#2c,001,#2d,001,#2e,001,#2f,001
        db #30,001,#31,001,#32,001,#33,001,#34,001,#35,001,#36,001,#37,001
        db 0

opl4_load
        db #68,0,#69,0,#6a,0,#6b,0,#6c,0,#6d,0,#6e,0,#6f,0                  ;disable all channels
        db #70,0,#71,0,#72,0,#73,0,#74,0,#75,0,#76,0,#77,0
        db #78,0,#79,0,#7a,0,#7b,0,#7c,0,#7d,0,#7e,0,#7f,0
        db #50,254,#51,254,#52,254,#53,254,#54,254,#55,254,#56,254,#57,254  ;mute all channels
        db #58,254,#59,254,#5a,254,#5b,254,#5c,254,#5d,254,#5e,254,#5f,254
        db #60,254,#61,254,#62,254,#63,254,#64,254,#65,254,#66,254,#67,254
        db 2,1
        db 0


;### OP4DET -> tries to detect an OPL4 chip
;### Output     CF=0 -> OPL4 found
;###            CF=1 -> no hardware detected
op4det  
    if PLATFORM_TYPE=PLATFORM_PCW   ;no OPL4 support on Amstrad PCW (currently)
        scf
        ret
elseif PLATFORM_TYPE=PLATFORM_SVM   ;no OPL4 support on SymbOSVM (currently)
        scf
        ret
elseif PLATFORM_TYPE=PLATFORM_NCX   ;no OPL4 support on Amstrad NC
        scf
        ret
elseif PLATFORM_TYPE=PLATFORM_ZNX   ;no OPL4 support on ZX Spectrum
        scf
        ret
endif

        call op4res
        ld bc,OPL4_REG
        call op4det2
        ld a,2
        out (c),a
        inc c
        call op4det2
        in a,(c)
        and #e0
        cp #20
        jr z,op4det1
        scf
if OPL4EMU=0
        ret
endif
op4det1 ld hl,smpmem
        ld de,smpmem+1
        push de
        push hl
        ld bc,2048/256/8*1024-1
        ld (hl),#ff
        ldir                ;first mark all as reserved
        di
if OPL4EMU=0
        call op4mem
else
ld a,4
endif
        ei
        ld (op4_64kbnk),a   ;a=2-32=totbnk; totmem = a*65536, totpag = a*65536/256, totbyt in smpmem = a*65536/256/8 = a*32
        add a
        add a       ;*4
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl   ;*32
        ld c,l
        ld b,h      ;length of free memory
        dec bc
        pop hl
        pop de
        push hl
        ld (hl),#00         ;mark available as free
        ldir
        pop hl
        ld (hl),#ff
        ld (hl),#0f         ;first 12 pages (3K) are sample headers
        or a
        ret

op4det2 ld a,16             ;delay for fast nachines
op4det3 dec a
        jr nz,op4det3
        ret

;### OP4MEM -> detects OPL4 wavetable memory
;### Output     A=number of 64K banks
op4mem  ld bc,OPL4_REG
        ld h,#02
        ld a,#01
        call op4mem5
        ld e,32
op4mem1 dec e
        ld a,e
        call op4mema        ;set address
        ld a,e
        call op4memw        ;write values
        ld a,e:xor #55
        call op4memw
        ld a,e:xor #aa
        call op4memw
        inc e:dec e
        jr nz,op4mem1
op4mem2 ld a,e
        call op4mema
        call op4memr
        cp e
        jr nz,op4mem3
        call op4memr
        xor #55:cp e
        jr nz,op4mem3
        call op4memr
        xor #aa:cp e
        jr nz,op4mem3
        inc e
        bit 6,e
        jr z,op4mem2
op4mem3 ld h,#02
        ld a,#10
        call op4mem5
        ld a,e
        ret
;set 64k bank in A
op4mema add #20
        ld h,#03   :call op4mem5    ;hig
        inc h:xor a:call op4mem5    ;mid
        inc h:xor a:jr   op4mem5    ;low
;write A to memory
op4memw ld h,6
op4mem5 ld l,a
        opl4_wt
        out (c),h
        inc c
	opl4_wt
        out (c),l
        dec c
        ret
;read A from memory
op4memr ld h,6
	opl4_wt
        out (c),h
        inc c
	opl4_wt
        in a,(c)
        dec c
        ret


;### OP4RES -> resets OPL4 hardware (enables WAV)
;### Destroyed  AF,BC
op4res  ld bc,OPL4_FM_C6
        ;opl4_wt
        ld a,5
        out (c),a
        inc c
        ;opl4_wt
        ld a,3
        out (c),a
        ret

;### OP4SET -> sets multiple OPL4 registers
;### Input      (HL)=reg1, dat1, reg2, dat2, ... 0
;### Destroyed  AF,BC,HL
op4set  ld bc,OPL4_REG
op4set1 opl4_wt
        ld a,(hl)
        or a
        ret z
        out (c),a
        inc hl
        inc c
        opl4_wt
        ld a,(hl)
        out (c),a
        dec c
        inc hl
        jr op4set1

;### OP4ADR -> sets OPL4 ram read/write address
;### Input      EHL=22bit address
;### Destroyed  AF,BC,DE
op4adr  ld bc,OPL4_REG
        set 5,e         ;always select upper 2MB
        ld d,3
        opl4_wt:out (c),d:inc c:opl4_wt:out (c),e:dec c:inc d
        opl4_wt:out (c),d:inc c:opl4_wt:out (c),h:dec c:inc d
        opl4_wt:out (c),d:inc c:opl4_wt:out (c),l:dec c
        ret

;### OP4VMA -> sets OPL4 master volume
;### Input      D=master volume (0-7, 0=full, 7=off)
;### Destroyed  AF,BC,E
op4vma  ld bc,OPL4_REG
        opl4_wt
        ld a,#f9
        out (c),a
        ld a,d
        rlca
        rlca
        rlca
        ld e,a
        ld a,d
        or e
        inc c
        ld e,a
        opl4_wt
        out (c),e
        ret

op4volo     ;volume table (original)
db #7F*2+1,#5C*2+1,#52*2+1,#4A*2+1,#44*2+1,#3F*2+1,#3B*2+1,#37*2+1,#34*2+1,#31*2+1,#2F*2+1,#2D*2+1,#2A*2+1,#28*2+1,#27*2+1,#25*2+1
db #23*2+1,#22*2+1,#20*2+1,#1F*2+1,#1E*2+1,#1C*2+1,#1B*2+1,#1A*2+1,#19*2+1,#18*2+1,#17*2+1,#16*2+1,#15*2+1,#14*2+1,#13*2+1,#12*2+1
db #12*2+1,#11*2+1,#10*2+1,#0F*2+1,#0F*2+1,#0E*2+1,#0D*2+1,#0C*2+1,#0C*2+1,#0B*2+1,#0B*2+1,#0A*2+1,#09*2+1,#09*2+1,#08*2+1,#08*2+1
db #07*2+1,#06*2+1,#06*2+1,#05*2+1,#05*2+1,#04*2+1,#04*2+1,#03*2+1,#03*2+1,#03*2+1,#02*2+1,#02*2+1,#01*2+1,#01*2+1,#00*2+1,#00*2+1
db #00*2+1

op4volm     ;volume table (music)
db #7F*2+1,#5C*2+1,#52*2+1,#4A*2+1,#44*2+1,#3F*2+1,#3B*2+1,#37*2+1,#34*2+1,#31*2+1,#2F*2+1,#2D*2+1,#2A*2+1,#28*2+1,#27*2+1,#25*2+1
db #23*2+1,#22*2+1,#20*2+1,#1F*2+1,#1E*2+1,#1C*2+1,#1B*2+1,#1A*2+1,#19*2+1,#18*2+1,#17*2+1,#16*2+1,#15*2+1,#14*2+1,#13*2+1,#12*2+1
db #12*2+1,#11*2+1,#10*2+1,#0F*2+1,#0F*2+1,#0E*2+1,#0D*2+1,#0C*2+1,#0C*2+1,#0B*2+1,#0B*2+1,#0A*2+1,#09*2+1,#09*2+1,#08*2+1,#08*2+1
db #07*2+1,#06*2+1,#06*2+1,#05*2+1,#05*2+1,#04*2+1,#04*2+1,#03*2+1,#03*2+1,#03*2+1,#02*2+1,#02*2+1,#01*2+1,#01*2+1,#00*2+1,#00*2+1
db #00*2+1

op4volx     ;volume table (effects)
db #7F*2+1,#5C*2+1,#52*2+1,#4A*2+1,#44*2+1,#3F*2+1,#3B*2+1,#37*2+1,#34*2+1,#31*2+1,#2F*2+1,#2D*2+1,#2A*2+1,#28*2+1,#27*2+1,#25*2+1
db #23*2+1,#22*2+1,#20*2+1,#1F*2+1,#1E*2+1,#1C*2+1,#1B*2+1,#1A*2+1,#19*2+1,#18*2+1,#17*2+1,#16*2+1,#15*2+1,#14*2+1,#13*2+1,#12*2+1
db #12*2+1,#11*2+1,#10*2+1,#0F*2+1,#0F*2+1,#0E*2+1,#0D*2+1,#0C*2+1,#0C*2+1,#0B*2+1,#0B*2+1,#0A*2+1,#09*2+1,#09*2+1,#08*2+1,#08*2+1
db #07*2+1,#06*2+1,#06*2+1,#05*2+1,#05*2+1,#04*2+1,#04*2+1,#03*2+1,#03*2+1,#03*2+1,#02*2+1,#02*2+1,#01*2+1,#01*2+1,#00*2+1,#00*2+1
db #00*2+1

;### OP4VTR -> get volume translation
;### Input      E=master volume (0-255; 0=mute, 255=max), A=volume (0-64)
;### Output     A=opl4 volume
;### Destroyed  F,DE,HL
op4vtr  inc e:dec e
        jr z,op4vtr1
        inc de          ;de=1-256
        call clcm16     ;hl=de*a (0-64)
        ld e,h
op4vtr1 ld d,0
        ld hl,op4volo
        add hl,de
        ld a,(hl)
        ret

;### OP4VFX -> sets effects master volume
;### Input      A=main volume (0-255)
;### Destroyed  AF,BC,DE,HL
op4vfx  ld hl,op4volx
        jr op4vmu0

;### OP4VMU -> sets music master volume
;### Input      A=main volume (0-255)
;### Destroyed  AF,BC,DE,HL
op4vmu  ld hl,op4volm
op4vmu0 ld c,a
        xor a
        ld b,a
op4vmu1 ld e,c
        push hl
        call op4vtr
        pop hl
        ld (hl),a
        inc hl
        inc b
        ld a,b
        cp 65
        jr nz,op4vmu1
        ret

;### OP4VCH -> set channel volume
;### Input      E=volume (0-64), (channel)=channel
;### Destroyed  AF,BC,DE,HL
op4vch  ld hl,op4volm
op4vch0 ld bc,OPL4_REG
        opl4_wt
        ld a,(channel)
        add #50         ;set total level   
        out (c),a
        ld d,0
        add hl,de
        ld e,(hl)
        inc c
        opl4_wt
        out (c),e
        ret

;### OP4KON -> set key on and panning
op4kon  call op4key
        set 7,a
        ld e,a
        opl4_wt
        out (c),e
        ret

;### OP4KOF -> set volume off, then key off
op4kof  ld e,0
        call op4vch
        call op4key
        res 7,a
        ld e,a
        opl4_wt
        out (c),e
        ret

;### OP4KEY -> prepare OPL4 key on/off and panning
;### Input      (channel)=channel, (op4keyp+channel)=panning
;### Output     A=panning, BC=OPL4_DATA
;### Destroyed  F,BC,DE,HL
op4keyp db 5,11,11,5    ;0-15

op4key  ld bc,OPL4_REG
        opl4_wt
        ld a,(channel)
        ld e,a
        add #68         ;keyon/panpot
        out (c),a
        inc c
        ld d,0
        ld hl,op4keyp
        add hl,de
        ld a,(hl)
        ret

;list
;ds 7
;nolist

;### OP4TON -> sets tone
;### Input      HL=amiga pitch (108-...), (channel)=channel
;### Destroyed  AF,BC,DE,HL
op4tonp     ;period to f-number (byte 0,1)/octave (byte 1) conversion; starts with period 907, ends with period  108
db #06+1,#04+8,#EA+1,#03+8,#CE+1,#03+8,#B2+1,#03+8,#98+1,#03+8,#7E+1,#03+8,#64+1,#03+8,#4A+1,#03+8,#32+1,#03+8,#18+1,#03+8,#00+1,#03+8,#E8+1,#02+8,#D2+1,#02+8,#BA+1,#02+8,#A4+1,#02+8,#8E+1,#02+8,#78+1,#02+8,#62+1,#02+8,#4E+1,#02+8,#38+1,#02+8
db #24+1,#02+8,#10+1,#02+8,#FC+1,#01+8,#E8+1,#01+8,#D6+1,#01+8,#C2+1,#01+8,#B0+1,#01+8,#9E+1,#01+8,#8C+1,#01+8,#7A+1,#01+8,#68+1,#01+8,#56+1,#01+8,#46+1,#01+8,#34+1,#01+8,#24+1,#01+8,#14+1,#01+8,#04+1,#01+8,#F4+1,#00+8,#E4+1,#00+8,#D4+1,#00+8
db #C6+1,#00+8,#B6+1,#00+8,#A8+1,#00+8,#98+1,#00+8,#8A+1,#00+8,#7C+1,#00+8,#6E+1,#00+8,#60+1,#00+8,#52+1,#00+8,#44+1,#00+8,#38+1,#00+8,#2A+1,#00+8,#1C+1,#00+8,#10+1,#00+8,#04+1,#00+8,#EE+1,#F7+8,#D6+1,#F7+8,#BC+1,#F7+8,#A4+1,#F7+8,#8C+1,#F7+8
db #74+1,#F7+8,#5E+1,#F7+8,#46+1,#F7+8,#30+1,#F7+8,#18+1,#F7+8,#02+1,#F7+8,#EC+1,#F6+8,#D6+1,#F6+8,#C2+1,#F6+8,#AC+1,#F6+8,#96+1,#F6+8,#82+1,#F6+8,#6E+1,#F6+8,#58+1,#F6+8,#44+1,#F6+8,#30+1,#F6+8,#1C+1,#F6+8,#0A+1,#F6+8,#F6+1,#F5+8,#E2+1,#F5+8
db #D0+1,#F5+8,#BE+1,#F5+8,#AA+1,#F5+8,#98+1,#F5+8,#86+1,#F5+8,#74+1,#F5+8,#62+1,#F5+8,#50+1,#F5+8,#40+1,#F5+8,#2E+1,#F5+8,#1E+1,#F5+8,#0C+1,#F5+8,#FC+1,#F4+8,#EC+1,#F4+8,#DA+1,#F4+8,#CA+1,#F4+8,#BA+1,#F4+8,#AA+1,#F4+8,#9A+1,#F4+8,#8C+1,#F4+8
db #7C+1,#F4+8,#6C+1,#F4+8,#5E+1,#F4+8,#4E+1,#F4+8,#40+1,#F4+8,#30+1,#F4+8,#22+1,#F4+8,#14+1,#F4+8,#06+1,#F4+8,#F8+1,#F3+8,#EA+1,#F3+8,#DC+1,#F3+8,#CE+1,#F3+8,#C0+1,#F3+8,#B2+1,#F3+8,#A4+1,#F3+8,#98+1,#F3+8,#8A+1,#F3+8,#7E+1,#F3+8,#70+1,#F3+8
db #64+1,#F3+8,#56+1,#F3+8,#4A+1,#F3+8,#3E+1,#F3+8,#32+1,#F3+8,#24+1,#F3+8,#18+1,#F3+8,#0C+1,#F3+8,#00+1,#F3+8,#F4+1,#F2+8,#E8+1,#F2+8,#DE+1,#F2+8,#D2+1,#F2+8,#C6+1,#F2+8,#BA+1,#F2+8,#B0+1,#F2+8,#A4+1,#F2+8,#9A+1,#F2+8,#8E+1,#F2+8,#84+1,#F2+8
db #78+1,#F2+8,#6E+1,#F2+8,#62+1,#F2+8,#58+1,#F2+8,#4E+1,#F2+8,#44+1,#F2+8,#38+1,#F2+8,#2E+1,#F2+8,#24+1,#F2+8,#1A+1,#F2+8,#10+1,#F2+8,#06+1,#F2+8,#FC+1,#F1+8,#F2+1,#F1+8,#E8+1,#F1+8,#E0+1,#F1+8,#D6+1,#F1+8,#CC+1,#F1+8,#C2+1,#F1+8,#BA+1,#F1+8
db #B0+1,#F1+8,#A6+1,#F1+8,#9E+1,#F1+8,#94+1,#F1+8,#8C+1,#F1+8,#82+1,#F1+8,#7A+1,#F1+8,#70+1,#F1+8,#68+1,#F1+8,#60+1,#F1+8,#56+1,#F1+8,#4E+1,#F1+8,#46+1,#F1+8,#3E+1,#F1+8,#34+1,#F1+8,#2C+1,#F1+8,#24+1,#F1+8,#1C+1,#F1+8,#14+1,#F1+8,#0C+1,#F1+8
db #04+1,#F1+8,#FC+1,#F0+8,#F4+1,#F0+8,#EC+1,#F0+8,#E4+1,#F0+8,#DC+1,#F0+8,#D4+1,#F0+8,#CE+1,#F0+8,#C6+1,#F0+8,#BE+1,#F0+8,#B6+1,#F0+8,#AE+1,#F0+8,#A8+1,#F0+8,#A0+1,#F0+8,#98+1,#F0+8,#92+1,#F0+8,#8A+1,#F0+8,#84+1,#F0+8,#7C+1,#F0+8,#74+1,#F0+8
db #6E+1,#F0+8,#66+1,#F0+8,#60+1,#F0+8,#5A+1,#F0+8,#52+1,#F0+8,#4C+1,#F0+8,#44+1,#F0+8,#3E+1,#F0+8,#38+1,#F0+8,#30+1,#F0+8,#2A+1,#F0+8,#24+1,#F0+8,#1C+1,#F0+8,#16+1,#F0+8,#10+1,#F0+8,#0A+1,#F0+8,#04+1,#F0+8,#FA+1,#E7+8,#EE+1,#E7+8,#E2+1,#E7+8
db #D6+1,#E7+8,#CA+1,#E7+8,#BC+1,#E7+8,#B0+1,#E7+8,#A4+1,#E7+8,#98+1,#E7+8,#8C+1,#E7+8,#80+1,#E7+8,#74+1,#E7+8,#6A+1,#E7+8,#5E+1,#E7+8,#52+1,#E7+8,#46+1,#E7+8,#3A+1,#E7+8,#30+1,#E7+8,#24+1,#E7+8,#18+1,#E7+8,#0E+1,#E7+8,#02+1,#E7+8,#F8+1,#E6+8
db #EC+1,#E6+8,#E2+1,#E6+8,#D6+1,#E6+8,#CC+1,#E6+8,#C2+1,#E6+8,#B6+1,#E6+8,#AC+1,#E6+8,#A2+1,#E6+8,#96+1,#E6+8,#8c+1,#e6+8,#82+1,#e6+8,#78+1,#e6+8,#6e+1,#e6+8,#62+1,#e6+8,#58+1,#e6+8,#4e+1,#e6+8,#44+1,#E6+8,#3A+1,#E6+8,#30+1,#E6+8,#26+1,#E6+8
db #1C+1,#E6+8,#12+1,#E6+8,#0A+1,#E6+8,#00+1,#E6+8,#F6+1,#E5+8,#EC+1,#E5+8,#E2+1,#E5+8,#DA+1,#E5+8,#D0+1,#E5+8,#C6+1,#E5+8,#BE+1,#E5+8,#B4+1,#E5+8,#AA+1,#E5+8,#A2+1,#E5+8,#98+1,#E5+8,#90+1,#E5+8,#86+1,#E5+8,#7E+1,#E5+8,#74+1,#E5+8,#6C+1,#E5+8
db #62+1,#E5+8,#5A+1,#E5+8,#50+1,#E5+8,#48+1,#E5+8,#40+1,#E5+8,#36+1,#E5+8,#2E+1,#E5+8,#26+1,#E5+8,#1E+1,#E5+8,#14+1,#E5+8,#0C+1,#E5+8,#04+1,#E5+8,#FC+1,#E4+8,#F4+1,#E4+8,#EC+1,#E4+8,#E2+1,#E4+8,#DA+1,#E4+8,#D2+1,#E4+8,#CA+1,#E4+8,#C2+1,#E4+8
db #BA+1,#E4+8,#B2+1,#E4+8,#AA+1,#E4+8,#A2+1,#E4+8,#9A+1,#E4+8,#94+1,#E4+8,#8C+1,#E4+8,#84+1,#E4+8,#7C+1,#E4+8,#74+1,#E4+8,#6C+1,#E4+8,#64+1,#E4+8,#5E+1,#E4+8,#56+1,#E4+8,#4E+1,#E4+8,#46+1,#E4+8,#40+1,#E4+8,#38+1,#E4+8,#30+1,#E4+8,#2A+1,#E4+8
db #22+1,#E4+8,#1A+1,#E4+8,#14+1,#E4+8,#0C+1,#E4+8,#06+1,#E4+8,#FE+1,#E3+8,#F8+1,#E3+8,#F0+1,#E3+8,#EA+1,#E3+8,#E2+1,#E3+8,#DC+1,#E3+8,#D4+1,#E3+8,#CE+1,#E3+8,#C6+1,#E3+8,#C0+1,#E3+8,#B8+1,#E3+8,#B2+1,#E3+8,#AC+1,#E3+8,#A4+1,#E3+8,#9E+1,#E3+8
db #98+1,#E3+8,#90+1,#E3+8,#8A+1,#E3+8,#84+1,#E3+8,#7E+1,#E3+8,#76+1,#E3+8,#70+1,#E3+8,#6A+1,#E3+8,#64+1,#E3+8,#5E+1,#E3+8,#56+1,#E3+8,#50+1,#E3+8,#4A+1,#E3+8,#44+1,#E3+8,#3E+1,#E3+8,#38+1,#E3+8,#32+1,#E3+8,#2A+1,#E3+8,#24+1,#E3+8,#1E+1,#E3+8
db #18+1,#E3+8,#12+1,#E3+8,#0C+1,#E3+8,#06+1,#E3+8,#00+1,#E3+8,#FA+1,#E2+8,#F4+1,#E2+8,#EE+1,#E2+8,#E8+1,#E2+8,#E2+1,#E2+8,#DE+1,#E2+8,#D8+1,#E2+8,#D2+1,#E2+8,#CC+1,#E2+8,#C6+1,#E2+8,#C0+1,#E2+8,#BA+1,#E2+8,#B6+1,#E2+8,#B0+1,#E2+8,#AA+1,#E2+8
db #A4+1,#E2+8,#9E+1,#E2+8,#9A+1,#E2+8,#94+1,#E2+8,#8E+1,#E2+8,#88+1,#E2+8,#84+1,#E2+8,#7E+1,#E2+8,#78+1,#E2+8,#72+1,#E2+8,#6E+1,#E2+8,#68+1,#E2+8,#62+1,#E2+8,#5E+1,#E2+8,#58+1,#E2+8,#52+1,#E2+8,#4E+1,#E2+8,#48+1,#E2+8,#44+1,#E2+8,#3E+1,#E2+8
db #38+1,#E2+8,#34+1,#E2+8,#2E+1,#E2+8,#2A+1,#E2+8,#24+1,#E2+8,#20+1,#E2+8,#1A+1,#E2+8,#16+1,#E2+8,#10+1,#E2+8,#0C+1,#E2+8,#06+1,#E2+8,#02+1,#E2+8,#FC+1,#E1+8,#F8+1,#E1+8,#F2+1,#E1+8,#EE+1,#E1+8,#E8+1,#E1+8,#E4+1,#E1+8,#E0+1,#E1+8,#DA+1,#E1+8
db #D6+1,#E1+8,#D0+1,#E1+8,#CC+1,#E1+8,#C8+1,#E1+8,#C2+1,#E1+8,#BE+1,#E1+8,#BA+1,#E1+8,#B4+1,#E1+8,#B0+1,#E1+8,#AC+1,#E1+8,#A6+1,#E1+8,#A2+1,#E1+8,#9E+1,#E1+8,#9A+1,#E1+8,#94+1,#E1+8,#90+1,#E1+8,#8C+1,#E1+8,#88+1,#E1+8,#82+1,#E1+8,#7E+1,#E1+8
db #7A+1,#E1+8,#76+1,#E1+8,#70+1,#E1+8,#6C+1,#E1+8,#68+1,#E1+8,#64+1,#E1+8,#60+1,#E1+8,#5C+1,#E1+8,#56+1,#E1+8,#52+1,#E1+8,#4E+1,#E1+8,#4A+1,#E1+8,#46+1,#E1+8,#42+1,#E1+8,#3E+1,#E1+8,#3A+1,#E1+8,#34+1,#E1+8,#30+1,#E1+8,#2C+1,#E1+8,#28+1,#E1+8
db #24+1,#E1+8,#20+1,#E1+8,#1C+1,#E1+8,#18+1,#E1+8,#14+1,#E1+8,#10+1,#E1+8,#0C+1,#E1+8,#08+1,#E1+8,#04+1,#E1+8,#00+1,#E1+8,#FC+1,#E0+8,#F8+1,#E0+8,#F4+1,#E0+8,#F0+1,#E0+8,#EC+1,#E0+8,#E8+1,#E0+8,#E4+1,#E0+8,#E0+1,#E0+8,#DC+1,#E0+8,#D8+1,#E0+8
db #D4+1,#E0+8,#D0+1,#E0+8,#CE+1,#E0+8,#CA+1,#E0+8,#C6+1,#E0+8,#C2+1,#E0+8,#BE+1,#E0+8,#BA+1,#E0+8,#B6+1,#E0+8,#B2+1,#E0+8,#AE+1,#E0+8,#AC+1,#E0+8,#A8+1,#E0+8,#A4+1,#E0+8,#A0+1,#E0+8,#9C+1,#E0+8,#98+1,#E0+8,#96+1,#E0+8,#92+1,#E0+8,#8E+1,#E0+8
db #8A+1,#E0+8,#86+1,#E0+8,#84+1,#E0+8,#80+1,#E0+8,#7C+1,#E0+8,#78+1,#E0+8,#74+1,#E0+8,#72+1,#E0+8,#6E+1,#E0+8,#6A+1,#E0+8,#66+1,#E0+8,#64+1,#E0+8,#60+1,#E0+8,#5C+1,#E0+8,#5A+1,#E0+8,#56+1,#E0+8,#52+1,#E0+8,#4E+1,#E0+8,#4C+1,#E0+8,#48+1,#E0+8
db #44+1,#E0+8,#42+1,#E0+8,#3E+1,#E0+8,#3A+1,#E0+8,#38+1,#E0+8,#34+1,#E0+8,#30+1,#E0+8,#2E+1,#E0+8,#2A+1,#E0+8,#26+1,#E0+8,#24+1,#E0+8,#20+1,#E0+8,#1C+1,#E0+8,#1A+1,#E0+8,#16+1,#E0+8,#14+1,#E0+8,#10+1,#E0+8,#0C+1,#E0+8,#0A+1,#E0+8,#06+1,#E0+8
db #04+1,#E0+8,#00+1,#E0+8,#FA+1,#D7+8,#F4+1,#D7+8,#EE+1,#D7+8,#E8+1,#D7+8,#E2+1,#D7+8,#DC+1,#D7+8,#D6+1,#D7+8,#D0+1,#D7+8,#CA+1,#D7+8,#C4+1,#D7+8,#BC+1,#D7+8,#B6+1,#D7+8,#B0+1,#D7+8,#AA+1,#D7+8,#A4+1,#D7+8,#9E+1,#D7+8,#98+1,#D7+8,#92+1,#D7+8
db #8C+1,#D7+8,#86+1,#D7+8,#80+1,#D7+8,#7A+1,#D7+8,#74+1,#D7+8,#70+1,#D7+8,#6A+1,#D7+8,#64+1,#D7+8,#5E+1,#D7+8,#58+1,#D7+8,#52+1,#D7+8,#4C+1,#D7+8,#46+1,#D7+8,#40+1,#D7+8,#3A+1,#D7+8,#36+1,#D7+8,#30+1,#D7+8,#2A+1,#D7+8,#24+1,#D7+8,#1E+1,#D7+8
db #18+1,#D7+8,#14+1,#D7+8,#0E+1,#D7+8,#08+1,#D7+8,#02+1,#D7+8,#FE+1,#D6+8,#F8+1,#D6+8,#F2+1,#D6+8,#EC+1,#D6+8,#E6+1,#D6+8,#E2+1,#D6+8,#DC+1,#D6+8,#D6+1,#D6+8,#D2+1,#D6+8,#CC+1,#D6+8,#C6+1,#D6+8,#C2+1,#D6+8,#BC+1,#D6+8,#B6+1,#D6+8,#B2+1,#D6+8
db #AC+1,#D6+8,#A6+1,#D6+8,#A2+1,#D6+8,#9C+1,#D6+8,#96+1,#D6+8,#92+1,#D6+8,#8C+1,#D6+8,#86+1,#D6+8,#82+1,#D6+8,#7C+1,#D6+8,#78+1,#D6+8,#72+1,#D6+8,#6E+1,#D6+8,#68+1,#D6+8,#62+1,#D6+8,#5E+1,#D6+8,#58+1,#D6+8,#54+1,#D6+8,#4E+1,#D6+8,#4A+1,#D6+8
db #44+1,#D6+8,#40+1,#D6+8,#3A+1,#D6+8,#36+1,#D6+8,#30+1,#D6+8,#2C+1,#D6+8,#26+1,#D6+8,#22+1,#D6+8,#1C+1,#D6+8,#18+1,#D6+8,#12+1,#D6+8,#0E+1,#D6+8,#0A+1,#D6+8,#04+1,#D6+8,#00+1,#D6+8,#FA+1,#D5+8,#F6+1,#D5+8,#F2+1,#D5+8,#EC+1,#D5+8,#E8+1,#D5+8
db #E2+1,#D5+8,#DE+1,#D5+8,#DA+1,#D5+8,#D4+1,#D5+8,#D0+1,#D5+8,#CC+1,#D5+8,#C6+1,#D5+8,#C2+1,#D5+8,#BE+1,#D5+8,#B8+1,#D5+8,#B4+1,#D5+8,#B0+1,#D5+8,#AA+1,#D5+8,#A6+1,#D5+8,#A2+1,#D5+8,#9C+1,#D5+8,#98+1,#D5+8,#94+1,#D5+8,#90+1,#D5+8,#8A+1,#D5+8
db #86+1,#D5+8,#82+1,#D5+8,#7E+1,#D5+8,#78+1,#D5+8,#74+1,#D5+8,#70+1,#D5+8,#6C+1,#D5+8,#66+1,#D5+8,#62+1,#D5+8,#5E+1,#D5+8,#5A+1,#D5+8,#56+1,#D5+8,#50+1,#D5+8,#4C+1,#D5+8,#48+1,#D5+8,#44+1,#D5+8,#40+1,#D5+8,#3C+1,#D5+8,#36+1,#D5+8,#32+1,#D5+8
db #2E+1,#D5+8,#2A+1,#D5+8,#26+1,#D5+8,#22+1,#D5+8,#1E+1,#D5+8,#1A+1,#D5+8,#14+1,#D5+8,#10+1,#D5+8,#0C+1,#D5+8,#08+1,#D5+8,#04+1,#D5+8,#00+1,#D5+8,#FC+1,#D4+8,#F8+1,#D4+8,#F4+1,#D4+8,#F0+1,#D4+8,#EC+1,#D4+8,#E8+1,#D4+8,#E2+1,#D4+8,#DE+1,#D4+8
db #DA+1,#D4+8,#D6+1,#D4+8,#D2+1,#D4+8,#CE+1,#D4+8,#CA+1,#D4+8,#C6+1,#D4+8,#C2+1,#D4+8,#BE+1,#D4+8,#BA+1,#D4+8,#B6+1,#D4+8,#B2+1,#D4+8,#AE+1,#D4+8,#AA+1,#D4+8,#A6+1,#D4+8,#A2+1,#D4+8,#9E+1,#D4+8,#9A+1,#D4+8,#96+1,#D4+8,#94+1,#D4+8,#90+1,#D4+8
db #8C+1,#D4+8,#88+1,#D4+8,#84+1,#D4+8,#80+1,#D4+8,#7C+1,#D4+8,#78+1,#D4+8,#74+1,#D4+8,#70+1,#D4+8,#6C+1,#D4+8,#68+1,#D4+8,#64+1,#D4+8,#62+1,#D4+8,#5E+1,#D4+8,#5A+1,#D4+8,#56+1,#D4+8,#52+1,#D4+8,#4E+1,#D4+8,#4A+1,#D4+8,#46+1,#D4+8,#44+1,#D4+8
db #40+1,#D4+8,#3C+1,#D4+8,#38+1,#D4+8,#34+1,#D4+8,#30+1,#D4+8,#2E+1,#D4+8,#2A+1,#D4+8,#26+1,#D4+8,#22+1,#D4+8,#1E+1,#D4+8,#1A+1,#D4+8,#18+1,#D4+8,#14+1,#D4+8,#10+1,#D4+8,#0C+1,#D4+8,#08+1,#D4+8,#06+1,#D4+8,#02+1,#D4+8,#FE+1,#D3+8,#FA+1,#D3+8
db #F8+1,#D3+8,#F4+1,#D3+8,#F0+1,#D3+8,#EC+1,#D3+8,#EA+1,#D3+8,#E6+1,#D3+8,#E2+1,#D3+8,#DE+1,#D3+8,#DC+1,#D3+8,#D8+1,#D3+8,#D4+1,#D3+8,#D0+1,#D3+8,#CE+1,#D3+8,#CA+1,#D3+8,#C6+1,#D3+8,#C4+1,#D3+8,#C0+1,#D3+8,#BC+1,#D3+8,#B8+1,#D3+8,#B6+1,#D3+8
db #B2+1,#D3+8,#AE+1,#D3+8,#AC+1,#D3+8,#A8+1,#D3+8,#A4+1,#D3+8,#A2+1,#D3+8,#9E+1,#D3+8,#9A+1,#D3+8,#98+1,#D3+8,#94+1,#D3+8,#90+1,#D3+8,#8E+1,#D3+8,#8A+1,#D3+8,#86+1,#D3+8,#84+1,#D3+8,#80+1,#D3+8,#7E+1,#D3+8,#7A+1,#D3+8,#76+1,#D3+8,#74+1,#D3+8

op4ton  add hl,hl
	ld de,op4tonp-216
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld hl,(channel)
	ld bc,OPL4_REG
	opl4_wt
	ld a,#38        ;1st -> set octave   
	add l
	out (c),a
	inc c
	opl4_wt
	out (c),d
	dec c
	opl4_wt
	ld a,#20	;2nd -> set f-num  
	add l
	out (c),a
	inc c
	opl4_wt
	out (c),e
	ret

;### OP4SMP -> starts new sample, if changed
;### Input      (channel)=channel, IY=data record
;### Destroyed  AF,BC,E
op4smp  ld a,(iy+n_sampnum)
        cp (iy+n_oldsamp)
        ret z
        ld (iy+n_oldsamp),a
        add 127
op4smp1 ld e,a
        ld bc,OPL4_REG
        opl4_wt
        ld a,(channel)
        add #08         ;set sample number   
        out (c),a
        inc c
        opl4_wt
        out (c),e
        ret


;==============================================================================
;### DEVICE DRIVER ROUTINES (OPL4) ############################################
;==============================================================================

op4ply  db 0    ;flag, if OPL4 music is playing


;### OP4MIN -> resets opl4 music to the beginning
;### Input      A=subsong (0-255)
;### Destroyed  AF,BC,DE,HL,IX,IY
op4min  ld hl,snddatmem
        ld bc,SWM_SNGLST
        add hl,bc
        ld de,0                 ;de=position in global songlist
        or a
op4min1 jr z,op4min2
        ld c,(hl)
        ld b,0
        inc hl
        ex de,hl
        add hl,bc
        ex de,hl
        dec a
        jr op4min1
op4min2 ld a,(hl)
        ld (song_length),a      ;a=subsong length
        ld hl,(op4lstadr)
        add hl,de
        ld de,patterns
        ld bc,128
        ldir
        jp mt_start0

;### OP4MPL -> starts playing OPL4 music
;### Destroyed  AF,BC,DE,HL
op4mpl  call mt_init
        ld a,1
        ld (op4ply),a
        ret

;### OP4STP -> pauses the music and mutes the OPL4
;### Destroyed  AF,BC,DE,HL
op4stp  xor a
        ld (op4ply),a
        jp mt_stop0

;### OP4FRM -> plays one OPL4 music frame
;### Destroyed  AF,BC,DE,HL,IX,IY
op4frm  db 0
        ld a,(op4ply)
        or a
        ret z
        di                  ;* play music
        call mt_music
        ei
        ret

;### OP4XPL -> starts an OPL4 sound effect
;### Input      C=opl4 sample ID (64-255), HL=amiga pitch (108-), A=channel (op4chn1st-23), D=volume (0=silent, 64=loud), E=panning (0-15)
;### Destroyed  AF,BC,DE,HL
op4xpl  push de
        ld (channel),a
        ld a,c
        add 128
        push hl
        push af
        call op4kof     ;key off
        pop af
        call op4smp1    ;set sample
        pop hl
        call op4ton     ;set period
        dec c
        opl4_wt
        ld a,(channel)
        add #68         ;key/panpot
        out (c),a
        inc c
        pop de          ;e=panning
        set 7,e         ;e=panning + keyon
        opl4_wt
        out (c),e
        ld e,d
        ld hl,op4volx
        jp op4vch0      ;set volume
