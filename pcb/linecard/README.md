# 24-port non-PoE 10/100/1000baseT QSGMII line card

Input: 12V at 1.25A max, fused at 2A. Expect ~15W max power consumption, less under typical operation

## Power

### Needs

* VDD (1.0V): 1.15A per PHY, 2.3A total
* VDD_A (1.0V): 180 mA per PHY, 360 mA total
* VDD_AH (2.5V): 1.37A per PHY, 2.74A total
* VDD_AL (1.0V): 190 mA per PHY, 380 total
* VDD_IO (2.5V): 60 mA per PHY, 120 mA total
* VDD_VS (1.0V): 90 mA per PHY, 180 mA total
* Plus a 3.3V standby rail for the management MCU
