;No need to put a ORG or anything.

;Declare the hardware (check the player source for the flag to declare.
;CPC'ers don't need to add anything, CPC is default).

PLY_AKG_HARDWARE_MSX = 1   ;MSX is used here, for example.

;If sound effects, declares the SFX flag. Once again,
;check the player source to know what flag to declare.
PLY_AKG_MANAGE_SOUND_EFFECTS = 1     ;Remove the line if no SFX!

include "PlayerAkg.asm"        ;This is the AKG player.
