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

/**
	@file
	@author	Andrew D. Zonenberg
	@brief	Boot-time hardware initialization
 */
#include <core/platform.h>
#include "hwinit.h"
#include <peripheral/FMC.h>
#include <peripheral/DWT.h>
#include <peripheral/ITM.h>
#include <ctype.h>
#include <embedded-utils/CoreSightRom.h>
#include <fpga/FPGAFirmwareUpdater.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Memory mapped SFRs on the Artix

volatile APB_GPIO FPGA_GPIOA __attribute__((section(".fgpioa")));
volatile APB_DeviceInfo_7series FDEVINFO __attribute__((section(".fdevinfo")));
volatile APB_MDIO FMDIO __attribute__((section(".fmdio")));
volatile APB_XADC FXADC __attribute__((section(".fxadc")));

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Memory mapped SFRs on the Kintex

volatile APB_GPIO FPGA_GPIOB __attribute__((section(".fgpiob")));
volatile APB_DeviceInfo_UltraScale FKDEVINFO __attribute__((section(".fkdevinfo")));

volatile APB_Curve25519 FCURVE25519 __attribute__((section(".fcurve25519")));
volatile APB_EthernetTxBuffer_10G FETHTX __attribute__((section(".fethtx")));
volatile APB_EthernetRxBuffer FETHRX __attribute__((section(".fethrx")));

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Common peripherals used by application and bootloader

/**
	@brief UART console

	Default after reset is for UART4 to be clocked by PCLK1 (APB1 clock) which is 62.5 MHz
	So we need a divisor of 542.53
 */
UART<32, 256> g_cliUART(&UART4, 543);

/**
	@brief MCU GPIO LEDs
 */
GPIOPin g_leds[4] =
{
	GPIOPin(&GPIOC, 2, GPIOPin::MODE_OUTPUT, GPIOPin::SLEW_SLOW),
	GPIOPin(&GPIOC, 3, GPIOPin::MODE_OUTPUT, GPIOPin::SLEW_SLOW),
	GPIOPin(&GPIOA, 0, GPIOPin::MODE_OUTPUT, GPIOPin::SLEW_SLOW),
	GPIOPin(&GPIOA, 1, GPIOPin::MODE_OUTPUT, GPIOPin::SLEW_SLOW)
};

/**
	@brief FPGA GPIO LEDs
 */
APB_GPIOPin g_fpgaLEDs[4] =
{
	APB_GPIOPin(&FPGA_GPIOA, 0, APB_GPIOPin::MODE_OUTPUT, APB_GPIOPin::INIT_DEFERRED),
	APB_GPIOPin(&FPGA_GPIOA, 1, APB_GPIOPin::MODE_OUTPUT, APB_GPIOPin::INIT_DEFERRED),
	APB_GPIOPin(&FPGA_GPIOA, 2, APB_GPIOPin::MODE_OUTPUT, APB_GPIOPin::INIT_DEFERRED),
	APB_GPIOPin(&FPGA_GPIOA, 3, APB_GPIOPin::MODE_OUTPUT, APB_GPIOPin::INIT_DEFERRED)
};

///@brief FPGA QSFP28 power
APB_GPIOPin g_qsfp0_lpmode(&FPGA_GPIOB, 2, APB_GPIOPin::MODE_OUTPUT, APB_GPIOPin::INIT_DEFERRED);
APB_GPIOPin g_qsfp0_rst_n(&FPGA_GPIOB, 4, APB_GPIOPin::MODE_OUTPUT, APB_GPIOPin::INIT_DEFERRED);

/**
	@brief MAC address I2C EEPROM
	Default kernel clock for I2C2 is pclk2 (68.75 MHz for our current config)
	Prescale by 16 to get 4.29 MHz
	Divide by 40 after that to get 107 kHz
*/
I2C g_macI2C(&I2C2, 16, 40);

///@brief The single supported SSH username
char g_sshUsername[CLI_USERNAME_MAX] = "";

///@brief KVS key for the SSH username
const char* g_usernameObjectID = "ssh.username";

///@brief Default SSH username if not configured
const char* g_defaultSshUsername = "admin";

///@brief Selects whether the DHCP client is active or not
//bool g_usingDHCP = false;

///@brief The DHCP client
//ManagementDHCPClient* g_dhcpClient = nullptr;

///@brief IRQ line to the FPGA
//APB_GPIOPin* g_ethIRQ = nullptr;

///@brief The battery-backed RAM used to store state across power cycles
volatile BootloaderBBRAM* g_bbram = reinterpret_cast<volatile BootloaderBBRAM*>(&_RTC.BKP[0]);

///@brief Database of authorized SSH keys
SSHKeyManager g_keyMgr;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Do other initialization

void InitITM();

void BSP_Init()
{
	//Set up PLL2 to run the external memory bus
	//We have some freedom with how fast we clock this!
	//Doesn't have to be a multiple of 500 since separate VCO from the main system
	RCCHelper::InitializePLL(
		2,		//PLL2
		25,		//input is 25 MHz from the HSE
		2,		//25/2 = 12.5 MHz at the PFD
		22,		//12.5 * 22 = 275 MHz at the VCO
		32,		//div P (not used for now)
		32,		//div Q (not used for now)
		1,		//div R (275 MHz FMC kernel clock = 137.5 MHz FMC clock)
		RCCHelper::CLOCK_SOURCE_HSE
	);

	InitRTCFromHSE();
	InitFMC();
	InitFPGA();
	DoInitKVS();
	InitI2C();
	InitMacEEPROM();
	//InitManagementPHY();
	InitIP();
	InitITM();

	App_Init();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Enable trace

/**
	@brief Initialize tracing
 */
void InitITM()
{
	//Enable ITM, enable PC sampling, and turn on forwarding to the TPIU
	#ifdef _DEBUG
		g_log("Initializing ITM\n");
		ITM::Enable();
		DWT::EnablePCSampling(DWT::PC_SAMPLE_SLOW);
		ITM::EnableDwtForwarding();
	#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BSP overrides for low level init

void BSP_InitUART()
{
	//Initialize the UART for local console: 115.2 Kbps using PA12 for UART4 transmit and PA11 for UART4 receive
	//TODO: nice interface for enabling UART interrupts
	static GPIOPin uart_tx(&GPIOA, 12, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_SLOW, 6);
	static GPIOPin uart_rx(&GPIOA, 11, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_SLOW, 6);

	//Enable the UART interrupt
	NVIC_EnableIRQ(52);

	g_logTimer.Sleep(10);	//wait for UART pins to be high long enough to remove any glitches during powerup
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Higher level initialization we used for a lot of stuff

void InitFMC()
{
	g_log("Initializing FMC...\n");
	LogIndenter li(g_log);

	static GPIOPin fmc_ad0(&GPIOD, 14, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad1(&GPIOD, 15, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad2(&GPIOD, 0, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad3(&GPIOD, 1, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad4(&GPIOE, 7, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad5(&GPIOE, 8, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad6(&GPIOE, 9, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad7(&GPIOE, 10, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad8(&GPIOE, 11, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad9(&GPIOA, 5, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad10(&GPIOB, 14, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad11(&GPIOE, 14, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad12(&GPIOE, 15, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad13(&GPIOD, 8, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad14(&GPIOD, 9, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_ad15(&GPIOD, 10, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);

	static GPIOPin fmc_a16(&GPIOD, 11, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_a17(&GPIOD, 12, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_a18(&GPIOD, 13, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_a19(&GPIOE, 3, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_a20(&GPIOE, 4, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_a21(&GPIOE, 5, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_a22(&GPIOE, 6, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_a23(&GPIOE, 2, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_a24(&GPIOG, 13, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_a25(&GPIOG, 14, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);

	static GPIOPin fmc_nl_nadv(&GPIOB, 7, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_nwait(&GPIOC, 6, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 9);
	static GPIOPin fmc_ne1(&GPIOC, 7, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 9);
	static GPIOPin fmc_ne3(&GPIOG, 6, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_clk(&GPIOD, 3, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_noe(&GPIOD, 4, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_nwe(&GPIOD, 5, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_nbl0(&GPIOE, 0, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);
	static GPIOPin fmc_nbl1(&GPIOE, 1, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_VERYFAST, 12);

	//Add a pullup on NWAIT
	fmc_nwait.SetPullMode(GPIOPin::PULL_UP);

	InitFMCForFPGA();

	//Initialize the LEDs
	for(auto& led : g_fpgaLEDs)
		led.DeferredInit();
}

void InitI2C()
{
	g_log("Initializing I2C interfaces\n");
	static GPIOPin mac_i2c_scl(&GPIOH, 4, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_SLOW, 4, true);
	static GPIOPin mac_i2c_sda(&GPIOH, 5, GPIOPin::MODE_PERIPHERAL, GPIOPin::SLEW_SLOW, 4, true);
}
