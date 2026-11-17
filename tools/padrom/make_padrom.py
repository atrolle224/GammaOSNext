"""A 32 KiB Game Boy ROM that turns the screen black while A, B, Select or Start is held
and white otherwise: a core's view of the controller, in a screenshot."""
import sys

rom = bytearray(0x8000)
rom[0x100:0x104] = bytes([0x00, 0xC3, 0x50, 0x01])          # nop; jp $0150
rom[0x134:0x13F] = b"PADTEST".ljust(11, b"\0")
prog = bytes([
    0x3E, 0x10, 0xE0, 0x00,  # $150 ld a,$10; ldh ($00),a   select the buttons
    0xF0, 0x00, 0xF0, 0x00,  #      ldh a,($00) twice        let them settle
    0xE6, 0x0F, 0xFE, 0x0F,  #      and $0F; cp $0F          all high: none held
    0x28, 0x06,              #      jr z,none
    0x3E, 0xFF, 0xE0, 0x47,  #      ld a,$FF; ldh ($47),a    BGP: black
    0x18, 0xEC,              #      jr $150
    0x3E, 0x00, 0xE0, 0x47,  # none: ld a,$00; ldh ($47),a   BGP: white
    0x18, 0xE6,              #      jr $150
])
rom[0x150:0x150 + len(prog)] = prog
x = 0
for i in range(0x134, 0x14D):
    x = (x - rom[i] - 1) & 0xFF
rom[0x14D] = x
open(sys.argv[1], "wb").write(rom)
