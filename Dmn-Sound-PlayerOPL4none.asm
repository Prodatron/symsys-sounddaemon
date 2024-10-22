;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@                 S y m b O S   -   S o u n d - D a e m o n                  @
;@                                                                            @
;@                            no-OPL4 dummy driver                            @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

smpall
smprem
smpefx
smpefr
smpbtl

op4vmu
op4vfx
op4kof
op4xpl
op4min
op4stp
op4mpl
op4frm  ret

channel     db 255
op4_64kbnk  db 0
smppag      dw 12

patadr2     ds 3
patadr6     ds 3

;### OP4DET -> tries to detect an OPL4 chip
;### Output     CF=0 -> OPL4 found
;###            CF=1 -> no hardware detected
op4det  scf
        ret

