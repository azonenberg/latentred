/***********************************************************************************************************************
*                                                                                                                      *
* LATENTRED                                                                                                            *
*                                                                                                                      *
* Copyright (c) 2023-2025 Andrew D. Zonenberg and contributors                                                         *
* All rights reserved.                                                                                                 *
*                                                                                                                      *
* Redistribution and use in source and binary forms, with or without modification, are permitted provided that the     *
* following conditions are met:                                                                                        *
*                                                                                                                      *
*    * Redistributions of source code must retain the above copyright notice, this list of conditions, and the         *
*      following disclaimer.                                                                                           *
*                                                                                                                      *
*    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the       *
*      following disclaimer in the documentation and/or other materials provided with the distribution.                *
*                                                                                                                      *
*    * Neither the name of the author nor the names of any contributors may be used to endorse or promote products     *
*      derived from this software without specific prior written permission.                                           *
*                                                                                                                      *
* THIS SOFTWARE IS PROVIDED BY THE AUTHORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   *
* TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL *
* THE AUTHORS BE HELD LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES        *
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR       *
* BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT *
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE       *
* POSSIBILITY OF SUCH DAMAGE.                                                                                          *
*                                                                                                                      *
***********************************************************************************************************************/

#include "latentred.h"
#include <ctype.h>
#include "../bsp/FPGATask.h"
#include <tcpip/IPAgingTask1Hz.h>
#include <tcpip/IPAgingTask10Hz.h>
#include <tcpip/PhyPollTask.h>
#include "LocalConsoleTask.h"
#include "LatentRedPhyPollTask.h"

void InitInterfaces();
void InitLineCardSensors(I2C& i2c, uint8_t idx);
void InitTempSensor(I2C& i2c, uint8_t addr, const char* name);

/**
	@brief Initialize global GPIO LEDs
 */
void InitLEDs()
{
	//Turn on the MCU GPIO LEDs
	g_leds[0] = 1;
	g_leds[1] = 1;
	g_leds[2] = 1;
	g_leds[3] = 1;

	//Turn on the FPGA GPIO LEDs
	g_fpgaLEDs[0] = 1;
	g_fpgaLEDs[1] = 1;
	g_fpgaLEDs[2] = 1;
	g_fpgaLEDs[3] = 1;
}

/**
	@brief Initialize sensors and log starting values for each
 */
void InitSensors()
{
	g_log("Initializing sensors\n");
	LogIndenter li(g_log);

	//No fans on this board

	//Read FPGA temperature
	auto temp = FXADC.die_temp;
	g_log("FPGA die temperature:              %uhk C\n", temp);

	//Read FPGA voltage sensors
	int volt = FXADC.volt_core;
	g_log("FPGA VCCINT:                        %uhk V\n", volt);
	volt = FXADC.volt_ram;
	g_log("FPGA VCCBRAM:                       %uhk V\n", volt);
	volt = FXADC.volt_aux;
	g_log("FPGA VCCAUX:                        %uhk V\n", volt);

	//Initialize the line card I2C
	InitLineCardSensors(g_macI2C, 0);
	//TODO: line card 1
}

/**
	@brief Initialize I2C sensors on a line card
 */
void InitLineCardSensors(I2C& i2c, uint8_t idx)
{
	g_log("Line card %d\n", idx);
	LogIndenter li(g_log);

	//Set up the I2C sensors
	InitTempSensor(i2c, 0x90, "PHY 0");
	InitTempSensor(i2c, 0x92, "PHY 1");
	InitTempSensor(i2c, 0x94, "PSU");
}

void InitTempSensor(I2C& i2c, uint8_t addr, const char* name)
{
	//Program for max resolution
	uint8_t payload[] = { 0x01, 0x60, 0x00 };
	if(!i2c.BlockingWrite(addr, payload, 3))
	{
		g_log(Logger::ERROR, "Failed to initialize I2C temp sensor at %02x (%s)\n", addr, name);
		return;
	}
	if(!i2c.BlockingWrite8(addr, 0x00))
	{
		g_log(Logger::ERROR, "Failed to initialize I2C temp sensor at %02x (%s)\n", addr, name);
		return;
	}

	//Read the current temperature
	uint16_t reply;
	if(!i2c.BlockingRead16(addr, reply))
	{
		g_log(Logger::ERROR, "Failed to initialize I2C temp sensor at %02x (%s)\n", addr, name);
		return;
	}

	g_log("%5s:                         %uhk C\n", name, reply);
}

extern "C" void WriteTestx64(volatile void* ptr);

void InitLineCardPHY();
void InitVSC8512(uint8_t phyaddr);
void InitSCCB();

void App_Init()
{
	//Enable interrupts early on since we use them for e.g. debug logging during boot
	EnableInterrupts();

	g_logTimer.Sleep(10 * 1000);

	//Basic hardware setup
	InitLEDs();
	InitDTS();
	InitSensors();
	InitLineCardPHY();
	InitSCCB();
	InitInterfaces();

	static FPGATask fpgaTask;
	//static LatentRedPhyPollTask lcPhyTask(0, &FMDIO);
	static IPAgingTask1Hz ipAgingTask1Hz;
	static IPAgingTask10Hz ipAgingTask10Hz;
	static LocalConsoleTask localConsoleTask;

	g_tasks.push_back(&fpgaTask);
	//g_tasks.push_back(&lcPhyTask);
	g_tasks.push_back(&ipAgingTask1Hz);
	g_tasks.push_back(&ipAgingTask10Hz);
	g_tasks.push_back(&localConsoleTask);

	//g_timerTasks.push_back(&lcPhyTask);
	g_timerTasks.push_back(&ipAgingTask1Hz);
	g_timerTasks.push_back(&ipAgingTask10Hz);
}

void RegisterProtocolHandlers(IPv4Protocol& ipv4)
{
	__attribute__((section(".tcmbss"))) static LatentRedUDPProtocol udp(&ipv4);
	__attribute__((section(".tcmbss"))) static LatentRedTCPProtocol tcp(&ipv4, udp);
	ipv4.UseUDP(&udp);
	ipv4.UseTCP(&tcp);

	g_udp = &udp;
	g_tcp = &tcp;
}

void InitLineCardPHY()
{
	g_log("Initializing line card PHYs\n");
	LogIndenter li(g_log);

	InitVSC8512(0);
	InitVSC8512(12);
}

void InitVSC8512(uint8_t phyaddr)
{
	g_log("Initializing PHY at MDIO base address %d\n", phyaddr);
	LogIndenter li(g_log);

	//Initial ID check
	MDIODevice mdev(&FMDIO, phyaddr);
	auto phyid1 = mdev.ReadRegister(REG_PHY_ID_1);
	auto phyid2 = mdev.ReadRegister(REG_PHY_ID_2);
	if( (phyid1 == 0x0007) && (phyid2 >> 4) == 0x06e)
		g_log("PHY ID = %04x %04x (VSC8512 rev %d)\n", phyid1, phyid2, phyid2 & 0xf);
	else
	{
		g_log("PHY ID = %04x %04x (unknown)\n", phyid1, phyid2);
		return;
	}

	//For now, assume we're a rev D (3) PHY
	//This part has been out for a while and we shouldn't ever have to deal with older silicon revs
	//given the component shortage clearing out old inventory!
	if( (phyid2 & 0xf) != 3)
	{
		g_log(Logger::ERROR, "Don't know how to initialize silicon revisions other than D\n");
		while(1)
		{}
	}

	//Soft reset
	/*g_log("Soft reset PHY\n");
	mdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_MAIN);
	mdev.WriteRegister(REG_BASIC_CONTROL, 0x8000);
	g_logTimer.Sleep(100 * 10);	//wait 100ms before proceeding

	//Check MDIO signal quality
	g_log("MDIO loopback test\n");
	uint32_t prng = 1;
	for(int i=0; i<500; i++)
	{
		//glibc rand() LFSR, grab low 16 bits and mask off reserved bit
		uint16_t random = (prng & 0xffff) & 0xb000;
		prng = ( (prng * 1103515245) + 12345 ) & 0x7fffffff;

		mdev.WriteRegister(REG_AN_ADVERT, random);
		uint16_t readback = mdev.ReadRegister(REG_AN_ADVERT);
		if(readback != random)
		{
			LogIndenter li2(g_log);
			g_log(Logger::ERROR, "MDIO loopback failed (iteration %d): wrote %04x, read %04x\n", i, random, readback);
		}
	}*/

	//Initialization script based on values from luton26_atom12_revCD_init_script() in Microchip MESA
	g_log("Running Atom12 rev C/D init script\n");
	mdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_MAIN);
	mdev.WriteMasked(REG_VSC8512_EXT_CTRL_STAT, 0x0001, 0x0001);	//this register is documented as read only, table 34
	mdev.WriteRegister(REG_VSC8512_EXT_PHY_CTRL_2, 0x0040);			//+2 edge rate for 100baseTX
																	//Reserved bit 6 set
																	//No jumbo frame support or loopback
	mdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_EXT2);
	mdev.WriteRegister(VSC_CU_PMD_TX, 0x02be);					//Non-default trim values for 10baseT amplitude

	mdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_TEST);
	mdev.WriteRegister(20, 0x4420);									//magic undocumented value
	mdev.WriteRegister(24, 0x0c00);									//magic undocumented value
	mdev.WriteRegister(9, 0x18c8);									//magic undocumented value
	mdev.WriteMasked(8, 0x8000, 0x8000);							//magic undocumented value
	mdev.WriteRegister(5, 0x1320);									//magic undocumented value

	//Magic block of writes to registers 18, 17, 16
	//wtf is token ring even doing in this chipset? or is this misnamed?
	mdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_TR);
	static const uint16_t magicTokenRingBlock[45][3] =
	{
		{ 0x0027, 0x303d, 0x9792 },
		{ 0x00a0, 0xf147, 0x97a0 },
		{ 0x0005, 0x2f54, 0x8fe4 },
		{ 0x0004, 0x01bd, 0x8fae },
		{ 0x000f, 0x000f, 0x8fac },
		{ 0x0000, 0x0004, 0x87fe },
		{ 0x0006, 0x0150, 0x8fe0 },
		{ 0x0012, 0x480a, 0x8f82 },
		{ 0x0000, 0x0034, 0x8f80 },
		{ 0x0000, 0x0012, 0x82e0 },
		{ 0x0005, 0x0208, 0x83a2 },
		{ 0x0000, 0x9186, 0x83b2 },
		{ 0x000e, 0x3700, 0x8fb0 },
		{ 0x0004, 0x9fa1, 0x9688 },
		{ 0x0000, 0xffff, 0x8fd2 },
		{ 0x0003, 0x9fa0, 0x968a },
		{ 0x0020, 0x640b, 0x9690 },
		{ 0x0000, 0x2220, 0x8258 },
		{ 0x0000, 0x2a20, 0x825a },
		{ 0x0000, 0x3060, 0x825c },
		{ 0x0000, 0x3fa0, 0x825e },
		{ 0x0000, 0xe0f0, 0x83a6 },
		{ 0x0000, 0x4489, 0x8f92 },
		{ 0x0000, 0x7000, 0x96a2 },
		{ 0x0010, 0x2048, 0x96a6 },
		{ 0x00ff, 0x0000, 0x96a0 },
		{ 0x0091, 0x9880, 0x8fe8 },
		{ 0x0004, 0xd602, 0x8fea },
		{ 0x00ef, 0xef00, 0x96b0 },
		{ 0x0000, 0x7100, 0x96b2 },
		{ 0x0000, 0x5064, 0x96b4 },
		{ 0x0050, 0x100f, 0x87fa },

		//this block is apparently for regular 10baseT mode
		//need different sequence for 10base-Te
		{ 0x0071, 0xf6d9, 0x8488 },
		{ 0x0000, 0x0db6, 0x848e },
		{ 0x0059, 0x6596, 0x849c },
		{ 0x0000, 0x0514, 0x849e },
		{ 0x0041, 0x0280, 0x84a2 },
		{ 0x0000, 0x0000, 0x84a4 },
		{ 0x0000, 0x0000, 0x84a6 },
		{ 0x0000, 0x0000, 0x84a8 },
		{ 0x0000, 0x0000, 0x84aa },
		{ 0x007d, 0xf7dd, 0x84ae },
		{ 0x006d, 0x95d4, 0x84b0 },
		{ 0x0049, 0x2410, 0x84b2 },

		//apparently this improves 100base-TX link startup
		{ 0x0068, 0x8980, 0x8f90 }
	};

	for(int i=0; i<45; i++)
	{
		mdev.WriteRegister(18, magicTokenRingBlock[i][0]);
		mdev.WriteRegister(17, magicTokenRingBlock[i][1]);
		mdev.WriteRegister(16, magicTokenRingBlock[i][2]);
	}

	mdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_TEST);	//undocumented
	mdev.WriteMasked(8, 0x0000, 0x8000);

	mdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_MAIN);
	mdev.WriteMasked(REG_VSC8512_EXT_CTRL_STAT, 0x0000, 0x0001);	//this register is documented as read only, table 34

	//TODO: 8051 microcode patch luton26_atom12_revC_patch?

	//Set the operating mode to 12 PHYs with QSGMII
	//(see table 77)
	//Wait until this completes
	g_log("Selecting 12-PHY QSGMII mode\n");
	mdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_GENERAL_PURPOSE);
	while(true)
	{
		auto tmp = mdev.ReadRegister(REG_VSC_GP_GLOBAL_SERDES);
		if( (tmp & 0x8000) == 0)
			break;
	}
	mdev.WriteRegister(REG_VSC_GP_GLOBAL_SERDES, 0x80a0);	//table 77 of datasheet says 80a0,
															//this doesn't seem to match what we see in MESA code? (80e0)
	while(true)
	{
		auto tmp = mdev.ReadRegister(REG_VSC_GP_GLOBAL_SERDES);
		if( (tmp & 0x8000) == 0)
			break;
	}

	//Set MAC mode to QSGMII
	mdev.WriteMasked(REG_VSC_MAC_MODE, 0x0000, 0xc000);

	//Initialize each port
	g_log("Per-port init\n");
	for(int i=0; i<12; i++)
	{
		MDIODevice pdev(&FMDIO, phyaddr + i);

		pdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_EXT2);
		pdev.WriteRegister(VSC_CU_PMD_TX, 0x02be);							//Non-default trim values for 10baseT amplitude

		pdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_EXT3);
		pdev.WriteRegister(VSC_MAC_PCS_CTL, 0x4180);						//Restart MAC on link state change
																			//Default preamble mode
																			//Enable SGMII autonegotiation

		pdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_MAIN);

		pdev.WriteRegister(REG_GIG_CONTROL, 0x600);							//Advertise multi-port device, 1000/full
		pdev.WriteRegister(REG_AN_ADVERT, 0x141);							//Advertise 100/full, 10/full only

		pdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_MAIN);
		pdev.WriteRegister(REG_VSC8512_LED_MODE, 0x80e0);					//LED configuration (default is 0x8021)
																			//LED3 (not used): half duplex mode
																			//LED2 (not used): link/activity
																			//LED1: constant off
																			//LED0: link state with pulse-stretched activity
	}

	//Initialize undocumented temperature sensor (see vtss_phy_chip_temp_init_private in MESA)
	mdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_GENERAL_PURPOSE);
	mdev.WriteMasked(REG_VSC_TEMP_CONF, 0xc0, 0xc0);
	int16_t tempval = GetVSC8512Temperature(mdev);
	g_log("PHY die temperature: %d.%02d C\n",
		(tempval >> 8),
		static_cast<int>(((tempval & 0xff) / 256.0) * 100));

	//Return to normal base register page
	g_log("PHY init done\n");
	mdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_MAIN);

	//Sanity check they all respond
	for(int i=0; i<12; i++)
	{
		MDIODevice pdev(&FMDIO, phyaddr + i);

		//g_log("PHY %d\n", i);
		//LogIndenter li2(g_log);

		//Read the PHY ID
		auto xphyid1 = pdev.ReadRegister(REG_PHY_ID_1);
		auto xphyid2 = pdev.ReadRegister(REG_PHY_ID_2);

		//g_log("PHY ID %d = %04x %04x\n", i, phyid1, phyid2);
		if( (xphyid1 != 0x0007) || (xphyid2 >> 4) != 0x06e)
		{
			g_log(Logger::ERROR, "PHY ID = %04x %04x (invalid)\n", xphyid1, xphyid2);
			return;
		}
	}
}

/**
	@brief Get the temperature of the VSC8512 in 8.8 fixed point format

	(see vtss_phy_read_temp_reg, vtss_phy_chip_temp_get_private)

	Transfer function: adc value * -0.714C + 135.3
 */
uint16_t GetVSC8512Temperature(MDIODevice& mdev)
{
	mdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_GENERAL_PURPOSE);

	mdev.WriteMasked(REG_VSC_TEMP_CONF, 0x00, 0x40);
	mdev.WriteMasked(REG_VSC_TEMP_CONF, 0x40, 0x40);
	uint8_t tempadc = mdev.ReadRegister(REG_VSC_TEMP_VAL) & 0xff;
	int16_t tempval = 34636 - 183*tempadc;

	mdev.WriteRegister(REG_VSC8512_PAGESEL, VSC_PAGE_MAIN);

	return tempval;
}

void InitSCCB()
{
	g_log("Initializing SCCB link to remote FPGA\n");
	LogIndenter li(g_log);

	static GPIOPin sfp_tx_disable(&GPIOB, 0, GPIOPin::MODE_OUTPUT, GPIOPin::SLEW_SLOW);
	sfp_tx_disable = 0;

	//TODO: poll until link is up, for now just wait 1 sec and hope for the best
	g_logTimer.Sleep(10 * 1000);

	PrintFPGAInfo(&FKDEVINFO);
}

/**
	@brief Initialize all of the switch ports
 */
void InitInterfaces()
{
	g_log("Initializing switch ports\n");
	LogIndenter li(g_log);

	static PortState portState;
	g_portState = &portState;

	//TODO: load speed, duplex, vlan, etc. settings from flash
}
