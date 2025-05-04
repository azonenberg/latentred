# lcbringup

This is a bringup test fixture for validating the line card (in conjunction with my kup-lulz XCKU5P FPGA board) and not intended to be part of the final LATENTED system.

Known errata: MDIO and MDC are on ball locations that are NC in the 7a35t FGG484 package. Reworked board connecting MDIO to the SPI pins on the adjacent bank and added external level shifters.
