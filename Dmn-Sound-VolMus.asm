;------------------------------------------------------------------------------
PLY_AKG_VOLLOOKUP
    ld bc,0                 ;3   c=music, b=effects
    ld hl,PLY_AKG_PSGREG8   ;3
    ld e,(hl)               ;2
PLY_AKG_VOLTYP_A
    ld d,c ;/b              ;1
    ld a,(de)               ;2
    ld (hl),a               ;2 13
    ld hl,PLY_AKG_PSGREG9   ;3
    ld e,(hl)               ;2
PLY_AKG_VOLTYP_B
    ld d,c ;/b              ;1
    ld a,(de)               ;2
    ld (hl),a               ;2 10
    inc hl                  ;2
    ld e,(hl)               ;2
PLY_AKG_VOLTYP_C
    ld d,c ;/b              ;1
    ld a,(de)               ;2
    ld (hl),a               ;2  9 -> 32
;------------------------------------------------------------------------------
