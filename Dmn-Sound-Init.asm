;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@                 S y m b O S   -   S o u n d - D a e m o n                  @
;@                                                                            @
;@             (c) 2023-2025 by Prodatron / SymbiosiS (Jörn Mika)             @
;@                      device-specific initializations                       @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

dvcini

if PLATFORM_TYPE=PLATFORM_SVM
        ld a,D_PSGCCPC+D_PSGSABC
        out (P_PSG1CTRL),a
        ld a,D_PSGOFF
        out (P_PSG2CTRL),a
endif
        ret
