;**************************************************************************
;*                                                                        *
;*      MoonBlaster for MoonSound Wave BASIC driver                       *
;*                                                                        *
;* Author :R. Schrijvers & M. Delorme                                     *
;* Versiom:1.14 - Plays MBWAVE 0.92 until MBWAVE 1.14 songs               *
;* Date   :10/10/98 (DDMMYY)                                              *
;*                                                                        *
;* Comments:                                                              *
;* ML-programmers should have no trouble ripping the replayer from this   *
;* source. Therefore, no seperate ML-source will be released.             *
;**************************************************************************

;--- Defines ---

R800ASM	equ	0	; assembly for R800 on/off
Z80HASM	equ	1	; assembly for 7Mhz on/off
SPTEST	equ	0	; speed test on/off (don't use speed test on turbo r!!)
FADE	equ	1	; include code for fade
RAMHEADERS	equ	1	; don't change ROM headers
	; When this is switched OFF the
	; replayer will be faster, but only do
	; this when you really need the speed!
	; It will affect the sound quality.

PROCNM	equ	0fd89h
WVIO	equ	07eh	; wave I/O base port
FMIO	equ	0c4h
PTW_SIZE	equ	20	; size of Wave playtable line
WAVCHNS	equ	24



;--- BLOAD header ---
	db	0feh
	dw	start,einde-04000h+start2,start
	org	09000h

	include	3	; MBMACROS

;---------------------------- BASIC driver code ----------------------------

;-------------------------------
;--- Initialise BASIC driver ---
;-------------------------------

start:	di
	ld	hl,play_busy	; clear replayer vars
	ld	de,play_busy + 1
	ld	bc,30
	ld	(hl),b	; ld (hl),0
	ldir
	ld	hl,songdata_bank1
	ld	a,3
	ld	(hl),a
	inc	hl
	ld	(hl),a
	inc	hl
	ld	(hl),a	; init default mapper banks
	ld	hl,08000h
	ld	(songdata_adres),hl	; init default song address

	call	init_calls	; init call statements

	di
	ld	a,(0f342h)
	ld	h,040h
	call	024h	; RAM on page 1
	ld	hl,start2
	ld	de,04000h
	ld	bc,einde - id	; copy driver to 04000h
	ldir

	di
	ld	a,(0fcc1h)
	ld	h,040h
	call	024h	; ROM on page 1
	ei
	ret


;---- initialise call statements ----

init_calls:	ld	a,(0f342h)
	push	af
	and	011b
	rlca
	rlca
	rlca
	rlca
	ld	e,a
	ld	d,0
	ld	hl,0fcc9h
	add	hl,de
	pop	af
	and	01100b
	ld	e,a
	add	hl,de
	inc	hl
	ld	(hl),32
	ret



;----------------------------
;---- Start of 'ROM' code ---
;----------------------------

start2:
	org	04000h

;--- call header ---

id:	db	"AB"
init:	dw	0
statement:	dw	check_labels
reserved:	dw	0,0,0,0,0


;-------------------
;--- Check Calls ---
;-------------------

check_labels:	push	hl
	ld	de,call_idents	; call identifiers
chklab_next:	ld	hl,PROCNM
chklab_nxtchar:	ld	a,(de)
	cp	(hl)
	jr	nz,chklab_skipchr	; not equal, skip rest chars
	or	a
	jr	z,chklab_found	; end marker, so label found!
	inc	hl
	inc	de
	jr	chklab_nxtchar	; check next char of call

chklab_skipchr:	ld	a,(de)
	or	a
	jr	z,chklab_endchar	; end of label chars
	inc	de
	jr	chklab_skipchr

chklab_endchar:	inc	de	; skip stuff
	inc	de
	inc	de
	ld	a,(de)	; end of labels?
	inc	a
	jr	z,chklab_notfnd	; yes, so call not found
	jr	chklab_next	; no, check next label

chklab_notfnd:	pop	hl
	scf
	ret

chklab_found:	ex	de,hl
	inc	hl
	ld	e,(hl)	; get pointer to call
	inc	hl
	ld	d,(hl)
	pop	hl
	call	chklab_callde	; call address in DE
	and	a
	ret
chklab_callde:	push	de
	ret



;--------------------------
;--- BASIC driver calls ---
;--------------------------

;--- start music ---

mbplay:	ld	a,(DOSinit)
	or	a
	jp	z,initerror
	push	hl
	call	start_music
	pop	hl
	ret

;--- stop music ---

mbstop:
	ld	a,(DOSinit)
	or	a
	jp	z,initerror
	push	hl
	call	stop_music
	pop	hl
	ret


;--- fade music ---

	IF	FADE=1

mbfade:	ld	a,(DOSinit)
	or	a
	jp	z,initerror
	ld	ix,0521ch
	call	basic_call	; get banknr
	push	hl
	call	fade_music
	pop	hl
	ret

	ENDIF


;--- continue music ---

mbcont:	ld	a,(DOSinit)
	or	a
	jp	z,initerror
	push	hl
	call	cont_music
	pop	hl
	ret

;--- halt music ---

mbhalt:	ld	a,(DOSinit)
	or	a
	jp	z,initerror
	push	hl
	call	halt_music
	pop	hl
	ret

;--- init mapper routines ---

mbinit:	push	hl
	call	InitMapper
	pop	hl
	ret


;--- allocate extra segments ---

mballoc:	ld	a,(DOSinit)
	or	a
	jp	z,initerror
	ld	ix,0521ch
	call	basic_call	; get banknr
	push	hl
	call	AllocSegs
	pop	hl
	ret


;--- free extra segments ---

mbfree:	ld	a,(DOSinit)
	or	a
	jp	z,initerror
	push	hl
	call	FreeSegs
	pop	hl
	ret


;--- set song data banks ---

mbbank1:	ld	a,(DOSinit)
	or	a
	jp	z,initerror
	call	mbbank
	ld	(songdata_bank1),a
	ret

mbbank2:	ld	a,(DOSinit)
	or	a
	jp	z,initerror
	call	mbbank
	ld	(songdata_bank2),a
	ret

mbbank3:	ld	a,(DOSinit)
	or	a
	jp	z,initerror
	call	mbbank
	ld	(songdata_bank3),a
	ret

mbbank:	ld	ix,0521ch
	call	basic_call	; get banknr
	push	hl
	push	af
	ld	a,(play_busy)
	or	a
	call	nz,stop_music	; stop music if playing
	pop	af
	pop	hl
	ret

;--- set song data address ---

mbaddr:	ld	a,(DOSinit)
	or	a
	jp	z,initerror
	ld	ix,0542fh
	call	basic_call	; get address
	push	hl
	push	de
	ld	a,(play_busy)
	or	a
	call	nz,stop_music	; stop music if playing
	pop	de
	pop	hl
	ld	(songdata_adres),de
	ret


;--- Load MWM file ---

; Note: The routine below is a bit complex because it supports
; songs > 16K. However, if you know that your song will always be < 16K you
; can simplify it a lot:
; - read the header and trash it!
; - read the rest of the file
; - modify the play_nextpos routine so that 3 is added to the pattern address

mbload:	ld	a,(DOSinit)
	or	a
	jp	z,initerror
	ld	ix,04c64h
	call	basic_call
	push	hl
	ld	ix,067d0h	; get filename
	call	basic_call
	push	hl
	pop	ix
	call	build_fcb	; build right FCB

	call	curbank_FE
	push	af

	call	open_file	; open song file
	or	a
	jp	nz,loderr

	ld	hl,songdata_bank1	; select first song bank
	ld	(load_bank),hl
	ld	a,(hl)
	call	selbank_FE

	ld	hl,6
	ld	de,(songdata_adres)
	call	load_file	; read header
	ld	a,8	; file type 8 = wave user song
	call	check_header
	jr	nz,loderr2

	ld	hl,278
	ld	de,(songdata_adres)	; read settings
	call	load_file
	ld	a,(de)
	add	hl,de
	ex	de,hl
	inc	a
	ld	l,a
	ld	h,0
	call	load_file	; read positions
	call	check_pats
	add	hl,de
	ex	de,hl
	add	a,a
	ld	l,a
	ld	h,0
	call	load_file	; read pattern addresses
	add	hl,de
	ld	(load_adres),hl

mbload_lp:	ld	de,load_buffer
	ld	hl,3
	call	load_file
	ld	a,(load_buffer + 2)
	or	a
	jr	z,mbload2
	ld	de,(load_adres)
	ld	hl,(load_buffer)
	call	load_file
	ld	de,08000h
	ld	(load_adres),de
	ld	hl,(load_bank)
	inc	hl
	ld	a,(hl)
	ld	(load_bank),hl
	call	selbank_FE
	jr	mbload_lp

mbload2:
	in	a,(#FD)
	call	selbank_FE
	call	load_xlfo_data
	call	close_file
	pop	af
	call	selbank_FE
	pop	hl
	ret

;--- load error ---

loderr2:	ld	hl,errtxt2
	jr	loderr_cnt
loderr:	ld	hl,errtxt
error:
loderr_cnt:	call	print
	call	0c0h	;beep
	pop	af
	call	selbank_FE
	pop	hl
	ld	ix,0409bh
	jp	basic_call

;--- Init error ---

initerror:
	ei
	ld	hl,errtxt_init
	jr	error

;--- load xlfo data ---

load_xlfo_data:
	ld	de,xlfo_data+#4000
	ld	hl,4
	call	load_file	; hl stays 4 after this
	ld	b,4
	ld	hl,xlfo_label+#4000
	call	chk_headerlus
	ret	nz
	ld	de,xls_tabel+#4000
	ld	hl,18
	jp	load_file

xlfo_label:	db	"XLFO"
xlfo_data:	ds	4

;--- Load MWK file ---
; Note: This will clear the first song bank!!

mwkload:	ld	a,(DOSinit)
	or	a
	jp	z,initerror
	ld	ix,04c64h
	call	basic_call
	push	hl
	ld	ix,067d0h	; get filename
	call	basic_call
	push	hl
	pop	ix

	call	build_fcb	; build right FCB

	call	curbank_FE
	push	af
	call	open_file	; open Wavekit file
	or	a
	jp	nz,loderr	; load error

	ld	hl,songdata_bank1
	ld	(load_bank),hl	; select first bank as buffer
	ld	a,(hl)
	call	selbank_FE

	ld	hl,6
	ld	de,(songdata_adres)
	call	load_file	; read header
	ld	a,13	; file type 13 = user wavekit
	call	check_header
	jp	nz,loderr2

	call	init_opl4

	call	load_mwkdata	; load tone and wave data
	call	load_mwktones	; load tones
	call	close_file
	pop	af
	call	selbank_FE
	pop	hl
	ret


;--- Load tone info bytes and wave tables ---
; In: wavekit file is open
; Out: tones_data: contains tone info bytes
;       waves: contains wave tables

load_mwkdata:	ld	hl,4 + 64
	ld	de,08000h
	call	load_file	; load tone info bytes
	ld	hl,08000h + 4
	ld	de,tones_data
	ld	bc,64
	ldir
	ld	a,(08000h + 3)	; #waves
	ld	b,a
	ld	hl,0
	ld	de,25
mwkload_lp1:	add	hl,de
	djnz	mwkload_lp1
	push	hl
	ld	de,08000h
	call	load_file	; load wave tables
	pop	bc
	ld	hl,08000h
	ld	de,waves
	ldir
	ret


;--- Load all tones ---
; In: tones_data is filled with tone info bytes
;      wavekit file is open
; Out: sample headers and data is set in sample RAM

load_mwktones:	ld	de,0	; tone header start at 200000h
	ld	ix,sample_address
	ld	(ix + 0),d	; reg 'DE' is filles with 0
	ld	(ix + 1),3
	ld	(ix + 2),20h	; sample start at 200300h
	ld	hl,tones_data
	ld	b,64
load_mwktonesl:	push	bc
	push	hl
	bit	0,(hl)
	call	nz,load_mwktone
	ex	de,hl
	ld	de,12
	add	hl,de
	ex	de,hl
	pop	hl
	inc	hl
	pop	bc
	djnz	load_mwktonesl

	ld	c,2
	ld	a,10000b
	jp	opl4_out_wave	; disable SRAM access mode


;--- Load one tone ---
; In: tones_data is filled with tone info bytes
;      wavekit file is open
;      IX = pointer to current sample address
;      HL = pointer to tone info byte
;      DE = pointer to tone header SRAM address
; Out: sample header and data is set in sample RAM
;       contents of IX is increased by sample size

load_mwktone:	push	de
	push	hl
	ld	de,08000h + 1
	ld	hl,11 + 2
	call	load_file
	pop	hl
	push	hl
	ld	a,(hl)
	bit	5,a
	jp	nz,loadRomTone

	ld	hl,(08000h + 1)
	ld	a,(ix + 0)	; add relative start address
	add	a,l
	ld	(08000h + 2),a
	ld	a,(ix + 1)
	add	a,h
	ld	(08000h + 1),a
	pop	hl
	push	af
	ld	a,(hl)	; include sample type bits
	and	11000000b
	or	(ix + 2)
	ld	(08000h),a
	pop	af
	jr	nc,load_mwktone2	; Carry from add a,h?
	ld	hl,08000h
	inc	(hl)

load_mwktone2:	pop	hl
	push	hl
	ld	e,020h
	call	set_opl4_wrt	; set write to address for header
	ld	hl,08000h
	ld	de,12
	call	ramtosram	; move header to Sample RAM

	ld	l,(ix + 0)	; current sample RAM address
	ld	h,(ix + 1)
	ld	e,(ix + 2)
	call	set_opl4_wrt

	ld	hl,(08000h + 1 + 11)	; sample size
	push	hl

	ld	(sample_size),hl
load_mwktonelp:	ld	de,04000h
	ld	hl,(sample_size)
	or	a
	sbc	hl,de
	ld	(sample_size),hl
	jr	c,load_mwktone3	; < 4000h
	ld	a,l
	or	h
	jr	z,load_mwktone3	; == 4000h

	ld	de,08000h	; buffer address
	ld	hl,04000h
	call	load_file	; load 04000h bytes
	ex	de,hl
	call	ramtosram	; and put them in SRAM
	jr	load_mwktonelp
load_mwktone3	add	hl,de
	ld	de,08000h	; buffer address
	call	load_file	; load last bytes
	ex	de,hl
	call	ramtosram	; and put them in SRAM

	pop	hl
	ld	a,(ix + 0)
	add	a,l
	ld	(ix + 0),a
	ld	a,(ix + 1)
	adc	a,h
	ld	(ix + 1),a
	jr	nc,load_mwktone4
	inc	(ix + 2)
load_mwktone4:	pop	de
	ret

sample_address:	ds	3,0
sample_size:	dw	0

loadRomTone:
	pop	hl
	and	a,%11000000
	ld	hl,(08000h + 1 + 11)	; sample size
	or	a,h
	ld	hl,#8000
	ld	(hl),a
	ld	de,(#8001)
	inc	hl
	ld	(hl),d
	inc	hl
	ld	(hl),e
	pop	hl
	push	hl
	ld	e,020h
	call	set_opl4_wrt	; set write to address for header
	ld	hl,08000h
	ld	de,12
	call	ramtosram	; move header to Sample RAM
	jr	load_mwktone4


;--- put samples in SRAM ---
; In: HL = RAM address DE = length

ramtosram:	push	hl
	push	de
	push	bc
	ld	c,WVIO + 1
ramtosram_lp:	outi		; unsigned
ramtosram_wt:	in	a,(FMIO)
	rra
	jr	c,ramtosram_wt
	dec	de
	ld	a,d
	or	e
	jr	nz,ramtosram_lp
	pop	bc
	pop	de
	pop	hl
	ret


;------------------------------------
;--- Set OPL4 for SRAM read/write ---
;------------------------------------
; In: EHL = SRAM address
; Out: C = wave data port

set_opl4_wrt:	ld	c,2	; enable SRAM access
	ld	a,10001b
	call	opl4_out_wave
	inc	c
	ld	a,e
	and	111111b
	call	opl4_out_wave
	inc	c
	ld	a,h
	call	opl4_out_wave
	inc	c
	ld	a,l
	call	opl4_out_wave
	ld	a,6
	out	(WVIO),a
	ld	c,WVIO + 1
	ret



;--- print replayer version ---

mbver:	push	hl
	ld	hl,vertxt
	call	print
	pop	hl
	ret


;--- check header ---
; In: A = file type
; Out: Z for Ok, NZ for error

check_header:	ld	(header_txt + 5),a
	ld	hl,header_txt
	ld	b,6
chk_headerlus:	ld	a,(de)
	cp	(hl)
	ret	nz
	inc	hl
	inc	de
	djnz	chk_headerlus
	ret

;--- search highest pattern ---
; In: L = #positions, DE = pointer to patterns
; Out: A = highest pattern

check_pats:	push	hl
	push	de
	ld	b,l
	ex	de,hl
	xor	a
check_patslp:	cp	(hl)
	jr	nc,check_pats2
	ld	a,(hl)
check_pats2:	inc	hl
	djnz	check_patslp
	inc	a
	pop	de
	pop	hl
	ret


;--- Build FCB ---
; In: IX = pointer to filename string
; Out: FCB contains filename in right FCB format

build_fcb:	ld	hl,fcb
	ld	de,upper_fcb
	ld	bc,37
	ldir		; move FCB out of page 1
	ld	a,(ix+0)
	ld	e,(ix+1)
	ld	d,(ix+2)	; pointer to start of string
	ld	hl,upper_fcb + 1	; FCB + 1, start of filename in FCB

	ld	b,9
build_fcb_lp:	ld	a,(de)
	cp	"."
	jr	z,build_fcb_end	; end of name, only extension follows!
	ld	(hl),a
	inc	hl
	inc	de
	djnz	build_fcb_lp
build_fcb_end:	inc	de
	ex	de,hl
	ld	de,upper_fcb + 1 + 8
	ld	bc,3
	ldir		; copy extension to FCB
	ret


;--- Call into BASIC ROM ---

basic_call:	ld	iy,(0fcc1h)
	jp	01ch


;--- Print text ---
; In: HL = textptr

print:	ld	a,(hl)
	or	a
	ret	z
	rst	018h
	inc	hl
	jr	print


header_txt:	db	"MBMS",010h,8
errtxt:	db	"MB Load Error!",0
errtxt2:	db	"Not a (compatible) MB file!",0
errtxt_init:	db	"Initialise mapper routines first!",0

vertxt:	db	"MWM BASIC driver v1.14",0ah,0dh,0

;--- call identifiers ---

call_idents:
	db	"R800",0
	dw	r800d
	db	"Z80",0
	dw	z80
	db	"MBPLAY",0
	dw	mbplay
	db	"MBSTOP",0
	dw	mbstop
	db	"MBCONT",0
	dw	mbcont
	db	"MBHALT",0
	dw	mbhalt
	db	"MBINIT",0
	dw	mbinit
	db	"MBALLOC",0
	dw	mballoc
	db	"MBFREE",0
	dw	mbfree
	db	"MBBANK1",0
	dw	mbbank1
	db	"MBBANK2",0
	dw	mbbank2
	db	"MBBANK3",0
	dw	mbbank3
	db	"MBADDR",0
	dw	mbaddr
	db	"MBVER",0
	dw	mbver
	db	"MWMLOAD",0
	dw	mbload
	db	"MWKLOAD",0
	dw	mwkload
	IF	FADE=1
	db	"MBFADE",0
	dw	mbfade
	ENDIF
	db	0ffh	; sentinel



;--- Z80/R800 switch ---

z80:	ld	a,(02dh)	; Switch to Z80 if Turbo-R
	cp	3
	ret	c
	ld	a,080h
	jp	0180h
r800d:	ld	a,(02dh)	; Switch to R800 DRAM if Turbo-R
	cp	3
	ret	c
	ld	a,082h
	jp	0180h


load_adres:	dw	0
load_bank:	dw	0



;-------------------------------- PLAYROUTINE --------------------------------

; start_music = start music
; stop_music = stop music
; cont_music = continues music after pause
; halt_music = halts/pauses music

play_busy:	equ	0da00h	; status:   0 = not playing
	;       255 = playing
songdata_bank1:	equ	0da01h	; mapperbank with song data
songdata_bank2:	equ	0da02h	; mapperbank with song data
songdata_bank3:	equ	0da03h	; mapperbank with song data
songdata_adres:	equ	0da04h	; address of song data
play_pos:	equ	0da06h	; current position
play_step:	equ	0da07h	; current step
status:	equ	0da08h	; status bytes (0 = off)
step_buffer:	equ	0da0bh	; decrunched step, played next int

load_buffer:	equ	0da23h
freeDOS2segs:	equ	0da26h
upper_fcb:	equ	0da40h

;--------------------
;--- Start music ---
;--------------------
; In : -
; Out: -
; Mod: all

start_music:	di
	ld	a,(play_busy)
	or	a
	ret	nz	; already playing?

	ld	hl,0
	ld	(status),hl
	ld	(status+1),hl	; clear status bytes

	ld	a,0ffh
	ld	(play_busy),a	; set busy playing

	ld	(play_pos),a
	ld	a,15
	ld	(play_step),a	; set step and position

	call	curbank_FE
	push	af
	ld	a,(songdata_bank1)
	call	selbank_FE

	ld	hl,(songdata_adres)
	ld	de,xleng
	ld	bc,220
	ldir		; copy song settings
	ld	de,58
	add	hl,de	; skip name/wavekit
	ld	(pos_address),hl
	ld	a,(xleng)
	inc	a
	ld	e,a
	add	hl,de
	ld	(pat_address),hl
	pop	af
	call	selbank_FE

	call	init_opl4	; initialise OPL4
	call	init_voices	; set start voices
	ld	a,(xtempo)
	ld	(play_speed),a	; set tempo
	ld	a,(play_speed)
	sub	3
	ld	(play_timercnt),a	; initialise timer (tempo)
	xor	a
	ld	(play_tspval),a	; transpose off
	IF	FADE=1
	ld	(play_fading),a
	ld	(play_fadecnt),a
	ld	(play_fadetcnt),a
	ENDIF

start_mus_cnt:
	di
	ld	hl,0fd9Ah
	ld	de,old_int
	ld	bc,5
	ldir		; save interrupt hook

	ld	a,(0f342h)
	ld	(Page_nmb),a
	ld	hl,opl4_int_han
	ld	de,0fb04h
	ld	bc,9
	ldir

	ld	hl,0FD9Ah	;Init On Hook 0FD9Ah a Jump to empty RS232 area
	ld	(hl),0C3h	; JP
	inc	hl
	ld	(hl),004h	; 04
	inc	hl
	ld	(hl),0FBh	; FB

	ld	a,2
	out	(0c4h),a
	ld	a,(xhzequal)
	or	a
	jr	z,Speed60Hz
	cp	1
	jr	nz,Speedxhz
	ld	a,248
	jr	Speedxhz
Speed60Hz:
	ld	a,208
Speedxhz:
	neg
	out	(0c5h),a
	opl4_wait	; wait if Turbo-R
	ld	a,4
	out	(0c4h),a
	opl4_wait	; wait if Turbo-R
	ld	a,00100001b
	out	(0c5h),a
	ei
	ret

opl4_int_han:
	in	a,(0C4H)	; Put this shit in the RS232 area
	rla		; this is to prevent 50 or 60 CALLFs
	ret	nc	; to the replayer
	rst	030h
Page_nmb:	db	0
	dw	play_int
	ret

;--- initialise OPL4 registers ---

init_opl4:	ld	a,5
	out	(FMIO+2),a
	opl4_wait	; wait if TURBO R
	ld	a,3
	out	(FMIO+3),a

	ld	c,2
	ld	a,10000b
	jp	opl4_out_wave	; init Wave ROM stuff


;----------------------------
;--- Stel Start Voices in ---
;----------------------------

init_voices:
	ld	b,WAVCHNS	; # wave channels
	ld	iy,play_table_wav
	ld	ix,xbegwav
	ld	de,PTW_SIZE
init_wavesl:
	push	de
	push	bc
	ld	a,(ix - 72)	; xdetune!
	add	a,a
	ld	(iy + 5),a	; detune!
	ld	(iy + 12),0	; Reverb off
	ld	a,(ix + 0)	; wave/patchnr
	push	af
	call	play_wwavevt2
	pop	af
	ld	hl,xwavvols - 1
	add_hl_a
	ld	a,(hl)	; volume
	ld	(iy + 15),a
	call	play_wchgvol2
	ld	a,(ix - 98)	; stereo preset
	call	play_wchgste2
	inc	ix
	pop	bc
	pop	de
	add	iy,de
	djnz	init_wavesl
	ret



;-----------------------
;--- Continue muziek ---
;-----------------------
; In : -
; Out: -
; Mod: all

cont_music:
	ld	a,(play_busy)	; already playing?
	or	a
	ret	nz
	dec	a
	ld	(play_busy),a
	jp	start_mus_cnt


;--------------------
;--- Stop muziek ----
;--------------------
; In : -
; Out: -
; Mod: all

stop_music:

;------------------
;--- Halt music ---
;------------------

halt_music:
	ld	a,(play_busy)	; already stopped?
	or	a
	ret	z

	di
	ld	a,4
	out	(0c4h),a
	opl4_wait	; wait if Turbo-R
	ld	a,128
	out	(0c5h),a	; Reset Opl4 flags to prevent a crash
	opl4_wait	; wait if Turbo-R
	xor	a
	out	(0c5h),a	; Stop timers
	ld	(play_busy),a
	ld	hl,old_int	; restore old interrupt hook
	ld	de,0fd9ah
	ld	bc,5
	ldir

	ld	b,WAVCHNS	; # wave channels
	ld	iy,play_table_wav
	ld	de,PTW_SIZE
halt_musicl3:
	call	play_woffevt
	call	play_chgdmp
	add	iy,de
	djnz	halt_musicl3
	ei
	ret

;------------------
;--- Fade music ---
;------------------
; In : A is fade speed
; Out: -
; Mod: AF, B

	IF	FADE=1

fade_music:	ld	b,a
	ld	a,(play_busy)	; already stopped?
	or	a
	ret	z
	ld	a,255
	ld	(play_fading),a	; fading on
	ld	a,b
	ld	(play_fadespd),a	; set fade speed
	ret

	ENDIF

;-------------------------------
;--- Music interrupt routine ---
;-------------------------------

play_int:
	di
	ld	a,4

	out	(0C4H),a
	opl4_wait	; wait if Turbo-R
	ld	a,128+1
	out	(0C5H),a	; reset opl4 IRQ

play_int3:

	IF	SPTEST=1
	IF	R800ASM=1
	ld	bc,5000
	ELSE
	IF	Z80HASM=1
	ld	bc,1100
	ELSE
	ld	bc,550
	ENDIF
	ENDIF
play__bla:
	dec	bc
	ld	a,b
	or	c
	jr	nz,play__bla

	ld	a,255	; white
	out	(099h),a
	ld	a,7+128
	out	(099h),a
	ENDIF

	call	play_pitch	; pitch-bend/modulation handler

	IF	FADE=1
	ld	a,(play_fading)
	or	a
	jr	z,play_int5
	call	play_fade	; fading
	ld	a,(play_fading)
	or	a
	jp	z,play_int_end
play_int5:
	ENDIF

	call	curbank_FE
	push	af

	ld	a,(play_speed)	; speed
	ld	hl,play_timercnt
	inc	(hl)
	cp	(hl)
	jp	nz,play_int_sec	; almost there?
	ld	(hl),0

	ld	a,(songdata_bank)
	call	selbank_FE

	call	play_wtones	; select tones in advance

	IF	SPTEST=1
	ld	a,15 * 16 + 8	; red
	out	(099h),a
	ld	a,7+128
	out	(099h),a
	ENDIF


	ld	hl,step_buffer	; songdata-adres
	ld	iy,play_table_wav
	ld	b,WAVCHNS	; # Wave channels!
	ld	de,PTW_SIZE
play_int_wlus:
	ld	a,(hl)
	or	a
	jr	z,play_int_wend2	; empty

	ex	af,af'
	ld	a,b
	exx
	ld	b,a
	ex	af,af'

	ld	de,play_int_wend
	push	de

	cp	97
	jp	c,play_wonevt	; wave on
	jp	z,play_woffevt	; wave off
	cp	146
	jp	c,play_wwavevt	; wave
	cp	178
	jp	c,play_wchgvol	; volume
	cp	193
	jp	c,play_wchgste	; stereo
	cp	212
	jp	c,play_wlnk	; link
	cp	231
	jp	c,play_wchgpit	; pitch bending
	cp	238
	jp	c,play_wchgdet	; detune
	cp	241
	jp	c,play_wchgmod	; modulation
	jp	z,play_chgpsr	; pseudo reverb on
	cp	243
	jp	c,play_chgdmp	; damp
	jp	z,play_chglfo	; LFO
	cp	245
	jp	c,play_chgpso	; pseudo reverb off
	cp	255
	jp	c,play_chgxls	; eXtra Lfo Settings

play_int_wend:
	exx
play_int_wend2:
	add	iy,de
	inc	hl
	djnz	play_int_wlus

	ld	a,(hl)	; command line
	or	a
	jr	z,play_cmdcnt

	ld	ix,play_cmdcnt

	cp	24
	jp	c,play_chgtmp	; change tempo
	jp	z,play_endop	; end of pattern
	cp	28
	jr	c,play_cmdcnt	; status
	cp	76 + 1
	jp	c,play_chgtrs	; transpose
	cp	211
	jp	c,play_chgbasefr	; base frequency

play_cmdcnt:
play_int_fin:
	pop	af
	call	selbank_FE

play_int_end:
	IF	SPTEST=1
	ld	a,15*16	; black
	out	(099h),a
	ld	a,7+128
	out	(099h),a
	ENDIF

old_int:	; Old int from hook 0FD9Ah
	ret
	ret
	ret
	ret
	ret

;-----------------------------------------------
;--- Interrupt routine BEFORE play-interrupt ---
;-----------------------------------------------

play_int_sec:	dec	a
	cp	(hl)
	jp	z,play_int_secit
	dec	a
	cp	(hl)
	jp	nz,play_int_fin

play_int_3rd:
	ld	a,(play_step)	; increase current step
	inc	a
	and	01111b
	ld	(play_step),a
	ld	hl,(songdata_ptr)
	call	z,play_nextpos	; step 0 => new position

	IF	SPTEST=1
	ld	a,15*16 + 4	; blue
	out	(099h),a
	ld	a,7+128
	out	(099h),a
	ENDIF

	ld	a,(songdata_bank)
	call	selbank_FE

;--- decrunch one step ---

	ld	de,step_buffer
decr_step_lp:
	ld	a,(hl)
	inc	hl
	cp	0ffh	; 0FFh => completely empty
	jp	nz,decr_step_2
	exx
	ld	hl,step_buffer
	ld	de,step_buffer + 1
	ld	bc,25 - 1
	ld	(hl),b
	ldir
	exx
	jp	decr_step_end

decr_step_2:
	ld	(de),a	; 1st byte uncrunched
	inc	de
	push	hl
	inc	hl
	inc	hl
	inc	hl
	exx
	pop	hl
	ld	b,3	; decrunch 3 * 8 bytes
decr_step_lp1:
	ld	a,(hl)
	exx
	ld	b,8	; decrunch 8 bytes
	ld	c,a
decr_step_lp2:
	xor	a
	rlc	c
	jr	nc,decr_step_3	; no carry? then empty event
	ld	a,(hl)
	inc	hl
decr_step_3:
	ld	(de),a
	inc	de
	djnz	decr_step_lp2
	exx
	inc	hl
	djnz	decr_step_lp1
	exx
decr_step_end:
	ld	(songdata_ptr),hl

;--- Calculate freq. & note nr of wave to play ---

	IF	SPTEST=1
	ld	a,15*16+3	; green
	ld	a,15*16
	out	(099h),a
	ld	a,7+128
	out	(099h),a
	ENDIF

	ld	iy,play_table_wav
	ld	hl,step_buffer	; third interrupt
	ld_bc	(WAVCHNS/2),96	; Wave channels
	jr	play_int_seclp

play_int_secit:
	ld	b,WAVCHNS
	ld	hl,step_buffer
	ld	iy,play_table_wav
	ld	de,PTW_SIZE
play_int_secl2:
	ld	a,(hl)
	dec	a
	cp	96
	jr	nc,play_int_secpb
	ld	(iy + 2),0
play_int_secpb:
	inc	hl
	add	iy,de
	djnz	play_int_secl2

	ld	iy,play_table_wav + (WAVCHNS/2) * PTW_SIZE
	ld	hl,step_buffer + WAVCHNS / 2	; second interrupt
	ld_bc	(WAVCHNS/2),96	; Wave channels
	jr	play_int_seclp


play_int_seclp:
	ld	de,PTW_SIZE
play_int_secwl:
	ld	a,(hl)
	dec	a
	cp	c	; 96
	jp	c,calc_wave	; JP to and fro for extra speed
play_int_secwe:
	add	iy,de
	inc	hl
	djnz	play_int_secwl
	jp	play_int_fin

;--- calc wave stuff ---

calc_wave:
	exx
	ld	d,a

	ld	hl,patch_table	; dit stuk verandert A niet!
	ld	b,0
	ld	c,(iy + 10)
	ld	a,c
	cp	175
	jp	z,calc_drm	; gm drum patch
	cp	176
	jp	nc,calc_own	; own wave

calc_drm_cnt:	ld	a,d
	add	hl,bc
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)	; pointer to patch
	ex	de,hl
	ld	e,(hl)
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	hl
	ld	(iy + 13),c	; pointer to header bytes
	ld	(iy + 14),b
	; search right patch part

	bit	0,e	; transpose
	jr	z,keyb_wonwav7
	ld	b,a
	ld	a,(play_tspval)
	add	a,b
keyb_wonwav7:	ld	b,0
	ld	de,3 + 2
calc_wave_lp:	cp	(hl)
	jr	c,calc_wave_2
	ld	b,(hl)
	add	hl,de
	cp	(hl)	; 4 * the same, saves 30 T-states!
	jr	c,calc_wave_2	; (Anything for some extra speed)
	ld	b,(hl)
	add	hl,de
	cp	(hl)
	jr	c,calc_wave_2
	ld	b,(hl)
	add	hl,de
	cp	(hl)
	jr	c,calc_wave_2
	ld	b,(hl)
	add	hl,de
	jp	calc_wave_lp
calc_wave_2:	ld	d,a	; save note...
	inc	hl
	ld	a,(hl)	; low byte tone
	ld	(iy + 7),a

	inc	hl
	ld	a,(hl)
	and	1	; also resets carry!
	ld	(iy + 6),a	; high byte tone

	ld	a,(hl)	; tone-note
	rra		; note that carry was set 0 earlier!!
	add	a,d
	sub	b
	ld	(iy + 0),a	; last note

	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(iy + 17),d	; pointer to freqtab
	ld	(iy + 16),e

	ld	hl,tabdiv12
	ld	c,a
	ld	b,0
	add	hl,bc
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	a,(hl)
	ex	de,hl

	add_hl_a	; right ptr to freq

	ld	e,(hl)
	inc	hl
	ld	d,(hl)	; DE = freq

	sla	e	; freq fine
	ld	a,d
	rla		; freq rotated 1 left
	add	a,c	; octave

	ld	d,a	; high byte freq

	ld	h,b	; LD H,0!
calc_drmcnt2:	ld	l,(iy + 5)
	bit	7,l
	jr	z,calc_wave_6
	dec	h
	add	hl,hl	; detune...
calc_wave_7:	add	hl,de
	res	3,h
	ld	(iy + 8),l	; freq fine
	ld	(iy + 9),h
	exx		; Yes! Finally, finished...
	jp	play_int_secwe
calc_wave_6:	ex	de,hl
	add	hl,de	; detune...
	ld	d,1000b
	jr	calc_wave_7



;--- Calc GM drums ---

calc_drm:	ld	a,d
	cp	36
	jp	c,calc_drm_cnt	; < 36 => first drum handled as patch
	cp	85 + 5 + 1
	jp	c,calc_drm2
	ld	a,84 + 4 + 1	; > 89 => 89
calc_drm2:
	ld	hl,gmdrm_c4
	sub	36
	ld	b,a
	add	a,a
	add	a,a
	ld	e,a
	ld	d,0
	add	hl,de
	ld	e,b
	add	hl,de
	ld	a,(hl)
	ld	(iy + 7),a
	ld	(iy + 6),0
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,(hl)
	ld	(iy + 13),a
	inc	hl
	ld	a,(hl)
	ld	(iy + 14),a
	ld	h,0
	jp	calc_drmcnt2

calc_own:
	sub	176
	ld	c,a
	add	a,a
	add	a,a
	add	a,a
	ld	l,a
	ld	h,0
	add	hl,hl
	add_hl_a	; * 24
	ld	a,c
	add_hl_a	; * 25
	ld	bc,waves
	add	hl,bc	; pointer to patch

	ld	e,(hl)	; transpose
	inc	hl
	; zoek juiste patch-deel
	ld	a,d
	bit	0,e	; transpose
	jr	z,calc_own2
	ld	a,(play_tspval)
	add	a,d

calc_own2:	ld	d,0
	ld	bc,3
calc_own_lp:	cp	(hl)
	jr	c,calc_own_2
	ld	d,(hl)
	add	hl,bc
	jp	calc_own_lp
calc_own_2:	ld	b,a	; save note...
	inc	hl
	ld	a,(hl)	; low byte tone
	ld	e,a
	add	a,128	; tone 384 and above
	ld	(iy + 7),a
	ld	(iy + 6),1	; RAM wave is altijd > 256
	inc	hl

	ld	a,(hl)	; tone-note
	add	a,b
	sub	d
	ld	(iy + 0),a	; last note
	push	af

	ld	(iy + 14),0	; no header

	ld	hl,tones_data
	ld	d,0
	add	hl,de
	ld	a,(hl)
	and	110b
	ld	hl,frqtab_amiga
	jr	z,calc_own3
	ld	hl,frqtab_441khz
	cp	2
	jr	z,calc_own3
	ld	hl,frqtab_turbo
calc_own3:	pop	af
	ld	(iy + 16),l
	ld	(iy + 17),h

	ld	e,a	; D is still 0
	add	hl,de
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	h,0
	jp	calc_drmcnt2


;---------------------------
;--- WAVE Event routines ---
;---------------------------

play_wtones:	ld	hl,step_buffer	; songdata address
	ld	b,WAVCHNS	; # channels
	ld	iy,play_table_wav
	ld	de,PTW_SIZE
play_wtonesl:	ld	a,(hl)
	dec	a
	cp	96
	jp	nc,play_wtonese

	ld	a,068h - 1
	add	a,b	; calc. register
	out	(WVIO),a
	xor	a
	nop
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a	; off

	ld	a,050h - 1
	add	a,b	; calc. register
	opl4_wait	; wait if Turbo-R
	out	(WVIO),a
	ld	c,a
	ld	a,11111111b
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a	; volume 0!

	ld	a,20h - 1
	add	a,b
	opl4_wait	; wait if Turbo-R
	out	(WVIO),a
	ld	a,(iy + 8)
	ld	(iy + 18),a
	or	(iy + 6)
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a	; freq + tone

	ld	a,8 - 1
	add	a,b
	opl4_wait	; wait if Turbo-R
	out	(WVIO),a
	ld	a,(iy + 7)
	opl4_7Mhz	; wait if 7Mhz
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a	; tone

	ld	a,38h - 1
	add	a,b
	opl4_wait	; wait if Turbo-R
	out	(WVIO),a
	ld	a,(iy + 9)
	ld	(iy + 19),a
	or	(iy + 12)	; pseude reverb
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a	; freq

play_wtonese:	inc	hl
	add	iy,de
	djnz	play_wtonesl
	ret


;--- Play ON-event ---

play_wonevt:
	dec	b
	ld	l,(iy + 13)
	ld	h,(iy + 14)
	ld	a,h
	or	a	; Check only on high byte of pointer
	jr	z,play_wonevtlp2	; own voice, no header...

	IF	RAMHEADERS=1
	ld	a,80h
	add	a,b
	out	(WVIO),a
	ld	a,(hl)
	opl4_7Mhz
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a
	inc	hl

play_wvwait:
	in	a,(FMIO)	; wait till Wave Load ready
	bit	1,a
	jr	nz,play_wvwait

play_wonevtlp:
	ld	a,(hl)
	cp	0ffh
	jr	z,play_wonevtlp2
	add	a,b
	opl4_wait	; wait if Turbo-R
	out	(WVIO),a
	inc	hl
	ld	a,(hl)
	opl4_7Mhz
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a	; header byte
	inc	hl
	jp	play_wonevtlp
	ENDIF

play_wonevtlp2:
	ld	a,050h	; set volume back to normal
	add	a,b
	opl4_wait	; wait if Turbo-R
	out	(WVIO),a
	ld	a,(iy + 15)
	or	1	; level direct
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a

	ld	a,068h
	add	a,b
	opl4_wait	; wait if Turbo-R
	out	(WVIO),a
	ld	a,10000000b
	or	(iy + 11)	; pan pot
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a	; key on
	ret


;--- Play OFF event ---

play_woffevt:	ld	a,068h - 1
	add	a,b	; calc. register
	out	(WVIO),a
	ld	(iy+2),0	; pb/mod off
	opl4_wait	; wait if Turbo-R
	opl4_7Mhz
	in	a,(WVIO + 1)
	and	1111111b
	opl4_7Mhz	; wait if 7Mhz
	opl4_wait	; wait if Turbo-R
	out	(WVIO + 1),a
	ret


;--- Play Wave event ---

play_wwavevt:	sub	98 - 1
play_wwavevt2:	ld	(iy + 2),0	; pb off
	ld	c,a
	ld	hl,xwavnrs - 1
	add_hl_a
	ld	a,(hl)
	ld	(iy + 10),a
	ld	a,c
	ld	hl,xwavvols - 1
	add_hl_a
	ld	a,(iy + 15)
	and	1
	ld	d,a
	IF	FADE=1
	ld	a,(play_fading)
	or	a
	jr	nz,play_wavevtfd
	ENDIF
	ld	a,(hl)
	add	a,a
	add	a,a
	or	d
	ld	(iy + 15),a
	ret

play_wavevtfd:	ld	a,(hl)
	add	a,a
	add	a,a
	or	d
	cp	(iy + 15)
	ret	c
	ld	(iy + 15),a
	ret


;--- Play volume event ---

play_wchgvol:	sub	146
	xor	31
	add	a,a
play_wchgvol2:	add	a,a	; * 4, OPL4 can handle 0-127
	add	a,a
	ld	c,a

	IF	FADE=1
	ld	a,(play_fading)
	or	a
	jr	z,play_wchgvolfd
	ld	a,c
	or	1
	cp	(iy + 15)
	ret	c
	ENDIF
play_wchgvolfd:
	ld	a,050h - 1
	add	a,b
	out	(WVIO),a
	ld	a,(iy + 15)	; level direct
	and	1
	or	c
	ld	(iy + 15),a
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a
	ret

;--- Link note ---

play_wlnk:	ld	(iy + 2),0
	push	bc
	sub	202
	add	a,(iy + 0)
	ld	(iy + 0),a

	bit	0,(iy + 6)
	jr	z,play_wlnk2
	bit	7,(iy + 7)
	jr	nz,play_wlnk3

play_wlnk2:	ld	hl,tabdiv12
	ld	c,a
	ld	b,0
	add	hl,bc
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	a,(hl)
	ld	l,(iy + 16)
	ld	h,(iy + 17)
	add_hl_a	; ptr to freq

	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl	; HL = freq

	add	hl,hl
	ld	a,h
	add	a,c
	ld	h,a
play_wlnk_7:	ld	d,0
	ld	e,(iy + 5)
	bit	7,e
	jr	z,play_wlnk_6
	dec	d
play_wlnk_6:	add	hl,de	; detune...
	add	hl,de

	ld	(iy + 18),l	; freq fine
	ld	(iy + 19),h

	pop	bc
	ld	a,20h - 1
	add	a,b
	out	(WVIO),a
	ld	a,l
	or	(iy + 6)
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a	; freq + tone

	ld	a,38h - 1
	add	a,b
	opl4_wait	; wait if Turbo-R
	out	(WVIO),a
	ld	a,h
	or	(iy + 12)
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a	; freq
	ret

play_wlnk3:	ld	l,(iy + 16)	; link own wave
	ld	h,(iy + 17)
	ld	e,a
	ld	d,0
	add	hl,de
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl	; freq
	jp	play_wlnk_7


;--- Play stereo event ---

play_wchgste:	sub	178 + 7
play_wchgste2:	and	1111b
	ld	d,a
	ld	a,(iy+11)
	and	11110000b
	or	d
	ld	(iy+11),a
	ld	a,68h - 1
	add	a,b
	out	(WVIO),a
	ld	(iy + 2),0
	opl4_wait	; wait if Turbo-R
	in	a,(WVIO + 1)
	and	11110000b
	or	d
	opl4_wait	; wait if Turbo-R
	out	(WVIO + 1),a
	ret

;--- Pitch bending ---

play_wchgpit:	sub	221
	ld	(iy+2),1	; Pitch bending on
	add	a,a
	add	a,a
	ld	(iy+3),a	; Set pitch bend speed
	rlca		; bit 7,a
	jr	c,play_wchgpit2
	ld	(iy+4),0
	ret

play_wchgpit2:	ld	(iy+4),0ffh
	ret


;--- Modulation event ---

play_wchgmod:	sub	238 - 2
	ld	(iy + 2),a
	add	a,a
	add	a,a
	add	a,a
	add	a,a
	ld	hl,xmodtab - 2 * 16
	add_hl_a
	ld	(iy + 3),l
	ld	(iy + 4),h
	ret

;--- Set detune ---

play_wchgdet:	sub	234
	add	a,a
	add	a,a	; * 4
	ld	(iy + 5),a
	ret

;--- Damp ---

play_chgdmp:
	ld	a,068h - 1
	add	a,b	; calc. register
	out	(WVIO),a
	ld	(iy+2),0	; pb/mod off
	opl4_7Mhz
	opl4_wait	; wait if Turbo-R
	in	a,(WVIO+1)
	or	1000000b
	opl4_7Mhz	; wait if 7Mhz
	opl4_wait	; wait if Turbo-R
	out	(WVIO + 1),a
	ret

;--- Pseudo reverb on ---

play_chgpsr:	set	3,(iy+12)
	ret

;--- Pseudo reverb off ---

play_chgpso:	res	3,(iy+12)
	ret

;--- LFO ---

play_chglfo:	ld	a,068h - 1
	add	a,b	; calc. register
	out	(WVIO),a
	opl4_7Mhz	; wait if 7Mhz
	opl4_wait	; wait if Turbo-R
	in	a,(WVIO+1)
	xor	100000b
	opl4_7Mhz	; wait if 7Mhz
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a
	ret

;--- eXtra Lfo Settings

play_chgxls:
	sub	246
	add	a,a
	ld	hl,xls_tabel
	add_hl_a

	ld	a,068h - 1
	add	a,b	; calc. register
	ld	d,a	; Save calculation for later
	out	(WVIO),a
	opl4_7Mhz	; wait if 7Mhz
	opl4_wait	; wait if Turbo-R
	in	a,(WVIO+1)
	opl4_wait	; wait if Turbo-R
	opl4_7Mhz
	ld	c,a
	set	5,a
	out	(WVIO+1),a

	ld	a,080h - 1
	add	a,b	; calc. register
	out	(WVIO),a
	ld	a,(hl)
	opl4_wait	; wait if Turbo-R
	opl4_7Mhz
	out	(WVIO+1),a
	inc	hl

	ld	a,0E0h - 1
	add	a,b	; calc. register
	out	(WVIO),a
	ld	a,(hl)
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a
	opl4_wait	; wait if Turbo-R
	opl4_7Mhz
	ld	a,d	; Reg d = #68
	out	(WVIO),a
	opl4_wait
	ld	a,c	; Reg c = contents reg #68
	res	5,a
	out	(WVIO+1),a
	ret

xls_tabel:
	db	49,0
	db	50,0
	db	51,0
	db	52,0
	db	53,0
	db	54,0
	db	55,0
	db	58,5
	db	03,0

;--------------------------
;--- CMD Event routines ---
;--------------------------

;-- change tempo --

play_chgtmp:	cpl
	add	a,25 +1
	ld	(play_speed),a
	jp	(ix)

;-- change base frequency --

play_chgbasefr:
	ld	c,a
	ld	a,2
	out	(0c4h),a
	ld	a,c
	sub	77
	opl4_wait	; wait if turbo r
	out	(0c5h),a
	neg
	ld	(xhzequal),a
	jp	(ix)


;-- end of pattern --

play_endop:	ld	a,15
	ld	(play_step),a
	jp	(ix)

;--- set transpose ---

play_chgtrs:	sub	52
	ld	(play_tspval),a
	jp	(ix)



;---------------------------
;--- Go to next position ---
;---------------------------

play_nextpos:	ld	a,(songdata_bank1)
	call	selbank_FE	; this bank contains pattern addresses

	ld	a,(xleng)
	inc	a
	ld	b,a
	ld	a,(play_pos)
	inc	a
	cp	b
	jp	c,play_nextpos2
	ld	a,(xloop)
	cp	255
	call	z,play_nextstop	; stop song, want loop OFF

play_nextpos2:
	ld	(play_pos),a
	ld	hl,(pos_address)
	add_hl_a
	ld	a,(hl)
	ld	(current_pat),a
	add	a,a
	ld	hl,(pat_address)
	add_hl_a
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	ld	a,h
	rlca
	rlca
	and	011b
	ld	de,songdata_bank1
	add_de_a
	ld	a,(de)
	ld	(songdata_bank),a
	ld	a,h
	and	00111111b
	ld	h,a
	ld	de,(songdata_adres)
	add	hl,de
	ret
play_nextstop:
	call	stop_music
	xor	a
	ret

;--------------------------------
;--- Pitch interrupt routines ---
;--------------------------------

;----- pitch bending/modulation -----

play_pitch:
	ld	iy,play_table_wav
	ld	de,PTW_SIZE
	ld	hl,play_pitchwvl2
	ld	b,WAVCHNS	; wave channels
play_pitchwlus:
	ld	a,(iy+2)
	or	a
	jp	nz,play_pitch_wdo
play_pitchwvl2:
	add	iy,de
	djnz	play_pitchwlus
	ret



;--- pitch bending ---

play_pitch_wdo:	exx

	ld	c,a

	ld	l,(iy + 3)	; pitch bend speed
	ld	h,(iy + 4)
	dec	c
	jp	nz,play_mod_wdo	; modulation
	ex	de,hl
play_pitch_wd4:
	ld	h,(iy + 19)
	ld	l,(iy + 18)
	add	hl,de	; sliding
	bit	3,h
	jr	z,play_pitch_wd5
	bit	7,d
	jr	nz,play_pitch_wd6
	ld	a,h
	add	a,1000b
	ld	h,a
	jr	play_pitch_wd5
play_pitch_wd6:
	res	3,h
play_pitch_wd5:
	ld	(iy + 18),l	; freq fine
	ld	(iy + 19),h
	ld	a,(iy + 1)
	ld	c,a
	out	(WVIO),a
	ld	a,l
	or	(iy + 6)
	opl4_wait	; wait if Turbo-R
	opl4_7Mhz
	out	(WVIO+1),a	; freq + tone

	ld	a,c
	add	a,24
	opl4_7Mhz	; wait if 7Mhz
	opl4_wait	; wait if Turbo-R
	out	(WVIO),a
	ld	a,h
	opl4_7Mhz	; wait if 7Mhz
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a	; freq
	exx
	jp	(hl)


;---- modulation ----

play_mod_wdo:
	ld	d,0
	ld	a,(hl)
	add	a,a
	add	a,a
	ld	e,a
	jr	nc,play_mod_wdo3
	dec	d
play_mod_wdo3:
	inc	hl
	ld	a,(hl)
	cp	10
	jp	nz,play_mod_wdo2
	ld	a,c

	ld	hl,xmodtab - 16
	add	a,a
	add	a,a
	add	a,a
	add	a,a
	add_hl_a
play_mod_wdo2:
	ld	(iy + 3),l
	ld	(iy + 4),h
	jp	play_pitch_wd4


;-------------------------------
;--- Fade interrupt routines ---
;-------------------------------

	IF	FADE=1

play_fade:	ld	a,(play_fadespd)	; speed
	ld	hl,play_fadecnt
	inc	(hl)
	cp	(hl)
	ret	nz
	ld	(hl),0

	ld	b,WAVCHNS
	ld	iy,play_table_wav
	ld	de,PTW_SIZE
play_fadelp:	ld	a,(iy + 15)
	add	a,8	; -4, but bit 0 is not for volume
	jr	nc,play_fade2
	ld	a,255
play_fade2:	ld	(iy + 15),a
	ld	a,050h - 1
	add	a,b
	out	(WVIO),a
	ld	a,(iy + 15)	; level direct
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a
	add	iy,de
	djnz	play_fadelp

	ld	hl,play_fadetcnt	; total counter
	inc	(hl)
	ld	a,(hl)
	cp	33	; will always be faded out in 33 steps
	ret	nz
	xor	a
	ld	(play_fading),a
	jp	stop_music

	ENDIF


;----------------
;--- OPL4 out ---
;----------------

opl4_out_wave:	ex	af,af'
	ld	a,c
	opl4_wait	; wait if Turbo-R
	out	(WVIO),a
	ex	af,af'
	opl4_7Mhz	; wait if 7Mhz
	opl4_wait	; wait if Turbo-R
	out	(WVIO+1),a
	ret


;--- smart table: --

;    - last note played                 01: + 0
;    - frequency register               01: + 1
;    - pitch bending on/off             01: + 2
;    - pitch bend speed                 02: + 3
;    - detune value                     01: + 5
;    - tone nr for next interrupt       02: + 6
;    - freq for next interrupt          02: + 8
;    - current patch                    01  + 10
;    - current stereo setting           01  + 11
;    - pseudo reverb                    01  + 12
;    - Pointer to header bytes          02  + 13
;    - Volume                           01  + 15
;    - Pointer to used freq table       01  + 16
;    - Current pitch freq.              02  + 18
;                               --
;    Total:                             20

play_table_wav:
	db	0,037h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch1
	db	0,036h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch2
	db	0,035h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch3
	db	0,034h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch4
	db	0,033h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch5
	db	0,032h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch6
	db	0,031h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch7
	db	0,030h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch8
	db	0,02fh,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch9
	db	0,02eh,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch10
	db	0,02dh,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch11
	db	0,02ch,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch12
	db	0,02bh,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch13
	db	0,02ah,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch14
	db	0,029h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch15
	db	0,028h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch16
	db	0,027h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch17
	db	0,026h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch18
	db	0,025h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch19
	db	0,024h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch20
	db	0,023h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch21
	db	0,022h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch22
	db	0,021h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch23
	db	0,020h,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; ch24


songdata_bank:	db	0
play_speed:	db	0	; current play speed
play_tspval:	db	0	; current transpose
play_timercnt:	db	0	; tempo counter
current_pat:	db	0
	IF	FADE=1
play_fading:	db	0
play_fadecnt:	db	0
play_fadespd:	db	0
play_fadetcnt:	db	0
	ENDIF


xleng	ds	1	; Song length
xloop	ds	1	; Loop position
xwvstpr	ds	24	; Stereo settings Wave
xtempo	ds	1	; Tempo
xhzequal	ds	1	; Base frequency
xdetune	ds	24	; Detune settings
xmodtab	ds	3*16	; Modulation tables
xbegwav	ds	24	; Start waves
xwavnrs	ds	48	; Wave numbers
xwavvols	ds	48	; Wave volumes

pat_address:	dw	0
pos_address:	dw	0
songdata_ptr:	dw	0

tabdiv12:
	db	-5*16,0,-5*16,2*1,-5*16,2*2,-5*16,2*3,-5*16,2*4,-5*16,2*5
	db	-5*16,2*6,-5*16,2*7,-5*16,2*8,-5*16,2*9,-5*16,2*10,-5*16,2*11
	db	-4*16,0,-4*16,2*1,-4*16,2*2,-4*16,2*3,-4*16,2*4,-4*16,2*5
	db	-4*16,2*6,-4*16,2*7,-4*16,2*8,-4*16,2*9,-4*16,2*10,-4*16,2*11
	db	-3*16,0,-3*16,2*1,-3*16,2*2,-3*16,2*3,-3*16,2*4,-3*16,2*5
	db	-3*16,2*6,-3*16,2*7,-3*16,2*8,-3*16,2*9,-3*16,2*10,-3*16,2*11
	db	-2*16,0,-2*16,2*1,-2*16,2*2,-2*16,2*3,-2*16,2*4,-2*16,2*5
	db	-2*16,2*6,-2*16,2*7,-2*16,2*8,-2*16,2*9,-2*16,2*10,-2*16,2*11
	db	-1*16,0,-1*16,2*1,-1*16,2*2,-1*16,2*3,-1*16,2*4,-1*16,2*5
	db	-1*16,2*6,-1*16,2*7,-1*16,2*8,-1*16,2*9,-1*16,2*10,-1*16,2*11
	db	0*16,0,0*16,2*1,0*16,2*2,0*16,2*3,0*16,2*4,0*16,2*5
	db	0*16,2*6,0*16,2*7,0*16,2*8,0*16,2*9,0*16,2*10,0*16,2*11
	db	1*16,0,1*16,2*1,1*16,2*2,1*16,2*3,1*16,2*4,1*16,2*5
	db	1*16,2*6,1*16,2*7,1*16,2*8,1*16,2*9,1*16,2*10,1*16,2*11
	db	2*16,0,2*16,2*1,2*16,2*2,2*16,2*3,2*16,2*4,2*16,2*5
	db	2*16,2*6,2*16,2*7,2*16,2*8,2*16,2*9,2*16,2*10,2*16,2*11
	db	3*16,0,3*16,2*1,3*16,2*2,3*16,2*3,3*16,2*4,3*16,2*5
	db	3*16,2*6,3*16,2*7,3*16,2*8,3*16,2*9,3*16,2*10,3*16,2*11
	db	4*16,0,4*16,2*1,4*16,2*2,4*16,2*3,4*16,2*4,4*16,2*5
	db	4*16,2*6,4*16,2*7,4*16,2*8,4*16,2*9,4*16,2*10,4*16,2*11
	db	5*16,0,5*16,2*1,5*16,2*2,5*16,2*3,5*16,2*4,5*16,2*5
	db	5*16,2*6,5*16,2*7,5*16,2*8,5*16,2*9,5*16,2*10,5*16,2*11
	db	6*16,0,6*16,2*1,6*16,2*2,6*16,2*3,6*16,2*4,6*16,2*5
	db	6*16,2*6,6*16,2*7,6*16,2*8,6*16,2*9,6*16,2*10,6*16,2*11
	db	7*16,0,7*16,2*1,7*16,2*2,7*16,2*3,7*16,2*4,7*16,2*5
	db	7*16,2*6,7*16,2*7,7*16,2*8,7*16,2*9,7*16,2*10,7*16,2*11
	db	8*16,0,8*16,2*1,8*16,2*2,8*16,2*3,8*16,2*4,8*16,2*5
	db	8*16,2*6,8*16,2*7,8*16,2*8,8*16,2*9,8*16,2*10,8*16,2*11
	db	9*16,0,9*16,2*1,9*16,2*2,9*16,2*3,9*16,2*4,9*16,2*5
	db	9*16,2*6,9*16,2*7,9*16,2*8,9*16,2*9,9*16,2*10,9*16,2*11
	db	10*16,0,10*16,2*1,10*16,2*2,10*16,2*3,10*16,2*4,10*16,2*5
	db	10*16,2*6,10*16,2*7,10*16,2*8,10*16,2*9,10*16,2*10,10*16,2*11

;--- freq. table for 44.1 kHz

frqtab_441khz:	dw	(-4 * 2048 + 0) * 2
	dw	(-4 * 2048 + 61) * 2
	dw	(-4 * 2048 + 125) * 2
	dw	(-4 * 2048 + 194) * 2
	dw	(-4 * 2048 + 266) * 2
	dw	(-4 * 2048 + 343) * 2
	dw	(-4 * 2048 + 424) * 2
	dw	(-4 * 2048 + 510) * 2
	dw	(-4 * 2048 + 601) * 2
	dw	(-4 * 2048 + 698) * 2
	dw	(-4 * 2048 + 801) * 2
	dw	(-4 * 2048 + 909) * 2
	dw	(-3 * 2048 + 0) * 2
	dw	(-3 * 2048 + 61) * 2
	dw	(-3 * 2048 + 125) * 2
	dw	(-3 * 2048 + 194) * 2
	dw	(-3 * 2048 + 266) * 2
	dw	(-3 * 2048 + 343) * 2
	dw	(-3 * 2048 + 424) * 2
	dw	(-3 * 2048 + 510) * 2
	dw	(-3 * 2048 + 601) * 2
	dw	(-3 * 2048 + 698) * 2
	dw	(-3 * 2048 + 801) * 2
	dw	(-3 * 2048 + 909) * 2
	dw	(-2 * 2048 + 0) * 2
	dw	(-2 * 2048 + 61) * 2
	dw	(-2 * 2048 + 125) * 2
	dw	(-2 * 2048 + 194) * 2
	dw	(-2 * 2048 + 266) * 2
	dw	(-2 * 2048 + 343) * 2
	dw	(-2 * 2048 + 424) * 2
	dw	(-2 * 2048 + 510) * 2
	dw	(-2 * 2048 + 601) * 2
	dw	(-2 * 2048 + 698) * 2
	dw	(-2 * 2048 + 801) * 2
	dw	(-2 * 2048 + 909) * 2
	dw	(-1 * 2048 + 0) * 2
	dw	(-1 * 2048 + 61) * 2
	dw	(-1 * 2048 + 125) * 2
	dw	(-1 * 2048 + 194) * 2
	dw	(-1 * 2048 + 266) * 2
	dw	(-1 * 2048 + 343) * 2
	dw	(-1 * 2048 + 424) * 2
	dw	(-1 * 2048 + 510) * 2
	dw	(-1 * 2048 + 601) * 2
	dw	(-1 * 2048 + 698) * 2
	dw	(-1 * 2048 + 801) * 2
	dw	(-1 * 2048 + 909) * 2
	dw	(-0 * 2048 + 0) * 2
	dw	(-0 * 2048 + 61) * 2
	dw	(-0 * 2048 + 125) * 2
	dw	(-0 * 2048 + 194) * 2
	dw	(-0 * 2048 + 266) * 2
	dw	(-0 * 2048 + 343) * 2
	dw	(-0 * 2048 + 424) * 2
	dw	(-0 * 2048 + 510) * 2
	dw	(-0 * 2048 + 601) * 2
	dw	(-0 * 2048 + 698) * 2
	dw	(-0 * 2048 + 801) * 2
	dw	(-0 * 2048 + 909) * 2
	dw	(+1 * 2048 + 0) * 2
	dw	(+1 * 2048 + 61) * 2
	dw	(+1 * 2048 + 125) * 2
	dw	(+1 * 2048 + 194) * 2
	dw	(+1 * 2048 + 266) * 2
	dw	(+1 * 2048 + 343) * 2
	dw	(+1 * 2048 + 424) * 2
	dw	(+1 * 2048 + 510) * 2
	dw	(+1 * 2048 + 601) * 2
	dw	(+1 * 2048 + 698) * 2
	dw	(+1 * 2048 + 801) * 2
	dw	(+1 * 2048 + 909) * 2
	dw	(+2 * 2048 + 0) * 2
	dw	(+2 * 2048 + 61) * 2
	dw	(+2 * 2048 + 125) * 2
	dw	(+2 * 2048 + 194) * 2
	dw	(+2 * 2048 + 266) * 2
	dw	(+2 * 2048 + 343) * 2
	dw	(+2 * 2048 + 424) * 2
	dw	(+2 * 2048 + 510) * 2
	dw	(+2 * 2048 + 601) * 2
	dw	(+2 * 2048 + 698) * 2
	dw	(+2 * 2048 + 801) * 2
	dw	(+2 * 2048 + 909) * 2
	dw	(+3 * 2048 + 0) * 2
	dw	(+3 * 2048 + 61) * 2
	dw	(+3 * 2048 + 125) * 2
	dw	(+3 * 2048 + 194) * 2
	dw	(+3 * 2048 + 266) * 2
	dw	(+3 * 2048 + 343) * 2
	dw	(+3 * 2048 + 424) * 2
	dw	(+3 * 2048 + 510) * 2
	dw	(+3 * 2048 + 601) * 2
	dw	(+3 * 2048 + 698) * 2
	dw	(+3 * 2048 + 801) * 2
	dw	(+3 * 2048 + 909) * 2
	dw	(+4 * 2048 + 0) * 2
	dw	(+4 * 2048 + 61) * 2
	dw	(+4 * 2048 + 125) * 2
	dw	(+4 * 2048 + 194) * 2
	dw	(+4 * 2048 + 266) * 2
	dw	(+4 * 2048 + 343) * 2
	dw	(+4 * 2048 + 424) * 2
	dw	(+4 * 2048 + 510) * 2
	dw	(+4 * 2048 + 601) * 2
	dw	(+4 * 2048 + 698) * 2
	dw	(+4 * 2048 + 801) * 2
	dw	(+4 * 2048 + 909) * 2
	dw	(+5 * 2048 + 0) * 2
	dw	(+5 * 2048 + 61) * 2
	dw	(+5 * 2048 + 125) * 2
	dw	(+5 * 2048 + 194) * 2
	dw	(+5 * 2048 + 266) * 2
	dw	(+5 * 2048 + 343) * 2
	dw	(+5 * 2048 + 424) * 2
	dw	(+5 * 2048 + 510) * 2
	dw	(+5 * 2048 + 601) * 2
	dw	(+5 * 2048 + 698) * 2
	dw	(+5 * 2048 + 801) * 2
	dw	(+5 * 2048 + 909) * 2

;--- freq table for Amiga ---

frqtab_amiga:

	dw	(-5 * 2048 + 529) * 2
	dw	(-5 * 2048 + 621) * 2
	dw	(-5 * 2048 + 721) * 2
	dw	(-5 * 2048 + 823) * 2
	dw	(-5 * 2048 + 937) * 2
	dw	(-4 * 2048 + 14) * 2
	dw	(-4 * 2048 + 76) * 2
	dw	(-4 * 2048 + 142) * 2
	dw	(-4 * 2048 + 211) * 2
	dw	(-4 * 2048 + 284) * 2
	dw	(-4 * 2048 + 361) * 2
	dw	(-4 * 2048 + 447) * 2

	dw	(-4 * 2048 + 529) * 2
	dw	(-4 * 2048 + 621) * 2
	dw	(-4 * 2048 + 721) * 2
	dw	(-4 * 2048 + 823) * 2
	dw	(-4 * 2048 + 937) * 2
	dw	(-3 * 2048 + 14) * 2
	dw	(-3 * 2048 + 76) * 2
	dw	(-3 * 2048 + 142) * 2
	dw	(-3 * 2048 + 211) * 2
	dw	(-3 * 2048 + 284) * 2
	dw	(-3 * 2048 + 361) * 2
	dw	(-3 * 2048 + 447) * 2

	dw	(-3 * 2048 + 529) * 2
	dw	(-3 * 2048 + 621) * 2
	dw	(-3 * 2048 + 721) * 2
	dw	(-3 * 2048 + 823) * 2
	dw	(-3 * 2048 + 937) * 2
	dw	(-2 * 2048 + 14) * 2
	dw	(-2 * 2048 + 76) * 2
	dw	(-2 * 2048 + 142) * 2
	dw	(-2 * 2048 + 211) * 2
	dw	(-2 * 2048 + 284) * 2
	dw	(-2 * 2048 + 361) * 2
	dw	(-2 * 2048 + 447) * 2

	dw	(-2 * 2048 + 529) * 2
	dw	(-2 * 2048 + 621) * 2
	dw	(-2 * 2048 + 721) * 2
	dw	(-2 * 2048 + 823) * 2
	dw	(-2 * 2048 + 937) * 2
	dw	(-1 * 2048 + 14) * 2
	dw	(-1 * 2048 + 76) * 2
	dw	(-1 * 2048 + 142) * 2
	dw	(-1 * 2048 + 211) * 2
	dw	(-1 * 2048 + 284) * 2
	dw	(-1 * 2048 + 361) * 2
	dw	(-1 * 2048 + 447) * 2

	dw	(-1 * 2048 + 529) * 2
	dw	(-1 * 2048 + 621) * 2
	dw	(-1 * 2048 + 721) * 2
	dw	(-1 * 2048 + 823) * 2
	dw	(-1 * 2048 + 937) * 2
	dw	(-0 * 2048 + 14) * 2
	dw	(-0 * 2048 + 76) * 2
	dw	(-0 * 2048 + 142) * 2
	dw	(-0 * 2048 + 211) * 2
	dw	(-0 * 2048 + 284) * 2
	dw	(-0 * 2048 + 361) * 2
	dw	(-0 * 2048 + 447) * 2

	dw	(-0 * 2048 + 529) * 2
	dw	(-0 * 2048 + 621) * 2
	dw	(-0 * 2048 + 721) * 2
	dw	(-0 * 2048 + 823) * 2
	dw	(-0 * 2048 + 937) * 2
	dw	(+1 * 2048 + 14) * 2
	dw	(+1 * 2048 + 76) * 2
	dw	(+1 * 2048 + 142) * 2
	dw	(+1 * 2048 + 211) * 2
	dw	(+1 * 2048 + 284) * 2
	dw	(+1 * 2048 + 361) * 2
	dw	(+1 * 2048 + 447) * 2

	dw	(+1 * 2048 + 529) * 2
	dw	(+1 * 2048 + 621) * 2
	dw	(+1 * 2048 + 721) * 2
	dw	(+1 * 2048 + 823) * 2
	dw	(+1 * 2048 + 937) * 2
	dw	(+2 * 2048 + 14) * 2
	dw	(+2 * 2048 + 76) * 2
	dw	(+2 * 2048 + 142) * 2
	dw	(+2 * 2048 + 211) * 2
	dw	(+2 * 2048 + 284) * 2
	dw	(+2 * 2048 + 361) * 2
	dw	(+2 * 2048 + 447) * 2

	dw	(+2 * 2048 + 529) * 2
	dw	(+2 * 2048 + 621) * 2
	dw	(+2 * 2048 + 721) * 2
	dw	(+2 * 2048 + 823) * 2
	dw	(+2 * 2048 + 937) * 2
	dw	(+3 * 2048 + 14) * 2
	dw	(+3 * 2048 + 76) * 2
	dw	(+3 * 2048 + 142) * 2
	dw	(+3 * 2048 + 211) * 2
	dw	(+3 * 2048 + 284) * 2
	dw	(+3 * 2048 + 361) * 2
	dw	(+3 * 2048 + 447) * 2


;--- freq table for Turbo-R ---

frqtab_turbo:
	dw	(-5 * 2048 + 439) * 2
	dw	(-5 * 2048 + 526) * 2
	dw	(-5 * 2048 + 618) * 2
	dw	(-5 * 2048 + 716) * 2
	dw	(-5 * 2048 + 819) * 2
	dw	(-5 * 2048 + 929) * 2
	dw	(-4 * 2048 + 10) * 2
	dw	(-4 * 2048 + 72) * 2
	dw	(-4 * 2048 + 137) * 2
	dw	(-4 * 2048 + 206) * 2
	dw	(-4 * 2048 + 279) * 2
	dw	(-4 * 2048 + 357) * 2

	dw	(-4 * 2048 + 439) * 2
	dw	(-4 * 2048 + 526) * 2
	dw	(-4 * 2048 + 618) * 2
	dw	(-4 * 2048 + 716) * 2
	dw	(-4 * 2048 + 819) * 2
	dw	(-4 * 2048 + 929) * 2
	dw	(-3 * 2048 + 10) * 2
	dw	(-3 * 2048 + 72) * 2
	dw	(-3 * 2048 + 137) * 2
	dw	(-3 * 2048 + 206) * 2
	dw	(-3 * 2048 + 279) * 2
	dw	(-3 * 2048 + 357) * 2

	dw	(-3 * 2048 + 439) * 2
	dw	(-3 * 2048 + 526) * 2
	dw	(-3 * 2048 + 618) * 2
	dw	(-3 * 2048 + 716) * 2
	dw	(-3 * 2048 + 819) * 2
	dw	(-3 * 2048 + 929) * 2
	dw	(-2 * 2048 + 10) * 2
	dw	(-2 * 2048 + 72) * 2
	dw	(-2 * 2048 + 137) * 2
	dw	(-2 * 2048 + 206) * 2
	dw	(-2 * 2048 + 279) * 2
	dw	(-2 * 2048 + 357) * 2

	dw	(-2 * 2048 + 439) * 2
	dw	(-2 * 2048 + 526) * 2
	dw	(-2 * 2048 + 618) * 2
	dw	(-2 * 2048 + 716) * 2
	dw	(-2 * 2048 + 819) * 2
	dw	(-2 * 2048 + 929) * 2
	dw	(-1 * 2048 + 10) * 2
	dw	(-1 * 2048 + 72) * 2
	dw	(-1 * 2048 + 137) * 2
	dw	(-1 * 2048 + 206) * 2
	dw	(-1 * 2048 + 279) * 2
	dw	(-1 * 2048 + 357) * 2

	dw	(-1 * 2048 + 439) * 2
	dw	(-1 * 2048 + 526) * 2
	dw	(-1 * 2048 + 618) * 2
	dw	(-1 * 2048 + 716) * 2
	dw	(-1 * 2048 + 819) * 2
	dw	(-1 * 2048 + 929) * 2
	dw	(-0 * 2048 + 10) * 2
	dw	(-0 * 2048 + 72) * 2
	dw	(-0 * 2048 + 137) * 2
	dw	(-0 * 2048 + 206) * 2
	dw	(-0 * 2048 + 279) * 2
	dw	(-0 * 2048 + 357) * 2

	dw	(-0 * 2048 + 439) * 2
	dw	(-0 * 2048 + 526) * 2
	dw	(-0 * 2048 + 618) * 2
	dw	(-0 * 2048 + 716) * 2
	dw	(-0 * 2048 + 819) * 2
	dw	(-0 * 2048 + 929) * 2
	dw	(+1 * 2048 + 10) * 2
	dw	(+1 * 2048 + 72) * 2
	dw	(+1 * 2048 + 137) * 2
	dw	(+1 * 2048 + 206) * 2
	dw	(+1 * 2048 + 279) * 2
	dw	(+1 * 2048 + 357) * 2

	dw	(+1 * 2048 + 439) * 2
	dw	(+1 * 2048 + 526) * 2
	dw	(+1 * 2048 + 618) * 2
	dw	(+1 * 2048 + 716) * 2
	dw	(+1 * 2048 + 819) * 2
	dw	(+1 * 2048 + 929) * 2
	dw	(+2 * 2048 + 10) * 2
	dw	(+2 * 2048 + 72) * 2
	dw	(+2 * 2048 + 137) * 2
	dw	(+2 * 2048 + 206) * 2
	dw	(+2 * 2048 + 279) * 2
	dw	(+2 * 2048 + 357) * 2

waves:	ds	48 * 25
tones_data:	ds	64


	include	2	; PATCHES

;------------------------------ End of replayer ----------------------------

;------------------------------
;--- Memory mapper routines ---
;------------------------------

;--- Init mapper ---
; In: -
; Out: Checks DOS version and inits mapper routines.
;      Also 'allocates' first 64K

InitMapper:	ld	a,255
	ld	(DOSinit),a
	xor	a
	BDOS	06Fh	; DOS2 returns version in r == -1
	ld	a,b
	ld	(DOSversion),a
	cp	2
	jr	c,InitMapperDOS1

	xor	a	; get mapper variable table
	ld	de,4*256+1
	call	0FFCAh
	ld	(DOSVarTab),hl
	inc	hl
	inc	hl
	ld	a,(hl)
	ld	(freeDOS2segs),a

	xor	a	; get mapper jump table
	ld	de,4*256+2
	call	0FFCAh
	ld	(DOSJmpTab),hl

	ld	de,1bh	; Fill 1st 4 fields of segtable
	call	dos2_segrtn
	ld	(DOSSegTab + 3),a
	ld	de,21h
	call	dos2_segrtn
	ld	(DOSSegTab + 2),a
	ld	de,27h
	call	dos2_segrtn
	ld	(DOSSegTab + 1),a
	ld	de,2dh
	call	dos2_segrtn
	ld	(DOSSegTab + 0),a
	ret

;- allocate in DOS1 -

InitMapperDOS1:	ld	hl,0203h
	ld	(DOSSegTab),hl
	ld	hl,0001h
	ld	(DOSSegTab + 2),hl
	ret


; --- Select segment/bank on 08000h-0BFFFh
; In: A = seg/banknr

selbank_FE:	push	bc
	ld	b,a
	ld	a,(DOSversion)
	cp	2
	jr	c,Selbank_FE2	; DOS1
	push	hl
	push	de
	ld	a,b
	ld	hl,DOSSegTab
	add_hl_a
	ld	a,(hl)	; zoek segmentnr
	ld	de,24h
	call	dos2_segrtn
	pop	de
	pop	hl
	pop	bc
	ret
Selbank_FE2:	ld	a,b
	ld	(DOSSegTab + 2),a
	out	(0FEh),a
	pop	bc
	ret

;--- Calls DOS2 mapper routine ---
; In: DE = routine offset

dos2_segrtn:	ld	hl,(DOSJmpTab)
	add	hl,de
	push	hl
	ret


; Get current segment/bank on 08000h-0BFFFh
; Out: A = seg/banknr

curbank_FE:	ld	a,(DOSversion)
	cp	2
	jr	c,curbank_FE2	; DOS1
	ld	de,27h
	call	dos2_segrtn
	ld	hl,DOSSegTab
	ld	d,0
curbank_FE3:	cp	(hl)
	jr	z,curbank_FE4
	inc	hl
	inc	d
	jp	curbank_FE3
curbank_FE4:	ld	a,d
	ret
curbank_FE2:	ld	a,(DOSSegTab + 2)
	ret


;--- Allocate segments ---
; In: A = nr of segments

AllocSegs:	ld	b,a
	ld	a,(DOSNrSegs)
	or	a
	ret	nz
	ld	a,b
	or	a
	ret	z	; 0 segments? return
	ld	(DOSNrSegs),a
	ld	hl,DOSSegTab + 4
	ld	c,0
	ld	b,a
alloc_seglp:	push	bc
	push	hl
	xor	a
	ld	b,a	; primary mapper ; B = 0
	ld	d,a	;
	ld	e,a	; DE =0
	inc	a	; system segment ; A = 1
	call	dos2_segrtn	; call alloc routine
	pop	hl
	ld	(hl),a
	inc	hl
	pop	bc
	inc	c
	djnz	alloc_seglp
	ret		; B = 0

; Free segments

FreeSegs:
	ld	a,(DOSversion)
	cp	2
	jr	c,free_seg2
	ld	a,(DOSNrSegs)
	ld	b,a
	ld	hl,DOSSegTab + 4
free_segl:	push	bc
	push	hl
	ld	a,(hl)
	ld	b,0
	ld	de,3
	call	dos2_segrtn
	pop	hl
	inc	hl
	pop	bc
	djnz	free_segl
free_seg2:	xor	a
	ld	(DOSNrSegs),a
	ret


DOSinit:	db	0
DOSversion:	db	0
DOSVarTab:	dw	0
DOSJmpTab:	dw	0
DOSSegTab:	ds	256,0
DOSNrSegs:	db	0


;----------------------------------
;------ disk access routines ------
;----------------------------------

setdma	equ	26
read	equ	39
open	equ	15
close	equ	16

;--- Open file ---

open_file:	ld	de,upper_fcb
	BDOS	open
	ld	hl,1
	ld	(upper_fcb + groot - fcb),hl
	dec	hl
	ld	(upper_fcb + blok - fcb),hl
	ld	(upper_fcb + blok + 2 - fcb),hl
	ret

;--- Load (part of) file ---
; In: HL = number of bytes to read
;     DE = transfer address

load_file:	push	ix
	push	hl
	push	de
	push	hl
	BDOS	setdma	; dma adres = musadr
	ld	de,upper_fcb
	pop	hl
	BDOS	read
	pop	de
	pop	hl
	pop	ix
	ret


;--- Close file ---

close_file:	ld	de,upper_fcb
	ld	c,close
	jp	bdoscall

;--- FCB ---

fcb:	db	0,"           "
	dw	0
groot:	dw	0
bleng:	dw	0
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
blok:	dw	0
	dw	0
einde:	end



