# 24-port non-PoE 10/100/1000baseT QSGMII line card

Input: 12V at 1.25A max, fused at 3A to be conservative.

Expect ~15W max power consumption, less under typical operation

## ERRATA

v0.1: right LED on the RJ45 is swapped between upper and lower ports

## Power

### Needs

* VDD (1.0V): 1.15A per PHY, 2.3A total
* VDD_A (1.0V): 180 mA per PHY, 360 mA total
* VDD_AH (2.5V): 1.37A per PHY, 2.74A total
* VDD_AL (1.0V): 190 mA per PHY, 380 total
* VDD_IO (2.5V): 60 mA per PHY, 120 mA total
* VDD_VS (1.0V): 90 mA per PHY, 180 mA total
* Plus a 3.3V standby rail for the management MCU

## I2C address map

* 0x80: INA230 on 3V3
* 0x82: INA230 on 2V5
* 0x84: INA230 on 1V0
* 0x86: INA230 on 1V0_2
* 0x90: AT30TS74 near PHY 0
* 0x92: AT30ST74 near PHY 1
* 0x94: AT30TS74 near power supply
