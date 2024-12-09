# latentred
Open hardware 48x 1000baseT + 2x 25G SFP28 Ethernet switch

Originally located in azonenberg/latentpacket but moved out to avoid monorepo bloat.

High level architecture:
* IBC (x1): 48V -> 12V intermediate bus converter. Not in this repo, see https://github.com/azonenberg/common-ibc
* Line card (x2): 24 10/100/1000 baseT ports, driven by two VSC8512 12-port PHYs
* Switch engine (x1): Kintex UltraScale+ FPGA (XCKU3P or 5P in FFVB676), STM32H735 (tentatively), packet buffer SRAM, 2x 25G SFP28 uplink
