;------------------------------------------------------------------------------
PLY_SE_VOLLOOKUP
    ld d,0                  ;2
    ld hl,PLY_SE_PSGREG8    ;3
    ld e,(hl)               ;2
    ld a,(de)               ;2
    ld (hl),a               ;2 11
    ld hl,PLY_SE_PSGREG9    ;3
    ld e,(hl)               ;2
    ld a,(de)               ;2
    ld (hl),a               ;2 9
    inc hl                  ;2
    ld e,(hl)               ;2
    ld a,(de)               ;2
    ld (hl),a               ;2 8 -> 28
;------------------------------------------------------------------------------
