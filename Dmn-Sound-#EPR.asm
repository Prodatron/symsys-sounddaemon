nolist

PLATFORM_TYPE   equ 3    ;0=CPC, 1=MSX, 2=PCW, 3=EPR, 4=SVM, 5=NCX, 6=ZNX
OPL4EMU         equ 0    ;1=OPL4 emulation

org #1000

WRITE "f:\symbos\ep\sndd.exe"
READ "..\..\..\SRC-Main\SymbOS-Constants.asm"
READ "Dmn-Sound-Head.asm"
READ "..\..\..\SRC-Main\Docs-Developer\symbos_lib-SystemManager.asm"
READ "..\..\..\SRC-Main\Docs-Developer\symbos_lib-DesktopManager.asm"
READ "..\..\..\SRC-Main\Docs-Developer\symbos_lib-FileManager.asm"
READ "..\..\..\SRC-Main\Docs-Developer\symbos_lib-Kernel.asm"
READ "App-SymAmp-EP.asm"
READ "Dmn-Sound-PlayerEPR.asm"
READ "Dmn-Sound-PlayerEPRfx.asm"
READ "Dmn-Sound-PlayerOPL4.asm"
READ "Dmn-Sound.asm"

App_EndTrns

relocate_table
relocate_end