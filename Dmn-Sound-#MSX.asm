nolist

DRIVER      equ 1    ;0=CPC, 1=MSX, 2=ZXS
OPL4EMU     equ 0    ;WinAmp OPL4 test

org #1000

WRITE "f:\symbos\msx\soundd.exe"
READ "..\..\..\SRC-Main\SymbOS-Constants.asm"
READ "Dmn-Sound-Head.asm"
READ "..\..\..\SRC-Main\Docs-Developer\symbos_lib-SystemManager.asm"
READ "..\..\..\SRC-Main\Docs-Developer\symbos_lib-DesktopManager.asm"
READ "..\..\..\SRC-Main\Docs-Developer\symbos_lib-FileManager.asm"
READ "..\..\..\SRC-Main\Docs-Developer\symbos_lib-Kernel.asm"
READ "Dmn-Sound-PlayerMSX.asm"
READ "Dmn-Sound-PlayerMSXfx.asm"
READ "Dmn-Sound-PlayerOPL4.asm"
READ "Dmn-Sound.asm"

App_EndTrns

relocate_table
relocate_end
