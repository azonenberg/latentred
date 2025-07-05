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

extern "C" void WriteTestx64(volatile void* ptr);

bool InitLineCardPHY();
void InitSCCB();

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

void App_Init()
{
	//Enable interrupts early on since we use them for e.g. debug logging during boot
	EnableInterrupts();

	g_logTimer.Sleep(10 * 1000);

	//Basic hardware setup
	InitLEDs();
	InitDTS();
	InitSensors();
	InitSCCB();

	//The below must come after SCCB link is up since we depend on Kintex-side peripherals
	if(!InitLineCardPHY())
	{
		g_log(Logger::ERROR, "Unrecoverable hardware failure initializing line card\n");

		//TODO: drop into debug shell or bootloader or something?
		while(1)
		{}
	}
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

bool InitLineCardPHY()
{
	g_log("Initializing line card PHYs\n");
	LogIndenter li(g_log);

	//Initialize the GPIOs on the QSFP28 interface (QSGMII to the upper PHY)
	g_qsfp0_lpmode = 1;
	g_qsfp0_rst_n = 1;
	g_logTimer.Sleep(250);

	//TODO: I2C command to the line card to power cycle and/or reset the PHYs to a clean state

	//Bring up the PHYs
	for(int lane=0; lane<2; lane++)
	{
		if(!g_linecard0_phys[lane]->Init())
			return false;

		//Set the default TX FFE tap value for QSGMII signal integrity tuning
		g_linecard0_phys[lane]->SetSerdes6GPostCursor0Tap(0x4);
	}
	return true;
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
