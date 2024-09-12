nolist

DRIVER      equ 2    ;0=CPC, 1=MSX, 2=ZXS
OPL4EMU     equ 0    ;1=OPL4 emulation

org #1000

WRITE "f:\symbos\nxt\-sndd.exe"
READ "..\..\..\SRC-Main\SymbOS-Constants.asm"
READ "Dmn-Sound-Head.asm"
READ "..\..\..\SRC-Main\Docs-Developer\symbos_lib-SystemManager.asm"
READ "..\..\..\SRC-Main\Docs-Developer\symbos_lib-DesktopManager.asm"
READ "..\..\..\SRC-Main\Docs-Developer\symbos_lib-FileManager.asm"
READ "..\..\..\SRC-Main\Docs-Developer\symbos_lib-Kernel.asm"
READ "Dmn-Sound-PlayerZXS.asm"
READ "Dmn-Sound-PlayerZXSfx.asm"
READ "Dmn-Sound-PlayerOPL4.asm"
READ "Dmn-Sound.asm"

App_EndTrns

relocate_table
relocate_end
