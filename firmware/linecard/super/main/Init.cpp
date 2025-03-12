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

#include "supervisor.h"
//#include "KupLulzSuperSPIServer.h"
#include "LEDTask.h"
#include "ButtonTask.h"
#include <math.h>
#include <peripheral/ITM.h>
#include <peripheral/DWT.h>

//TODO: fix this path somehow?
//#include "../../../../common-ibc/firmware/main/regids.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Power rail descriptors

GPIOPin g_1v0_en(&GPIOB, 13, GPIOPin::MODE_OUTPUT, GPIOPin::SLEW_SLOW);
GPIOPin g_1v0_pgood(&GPIOB, 14, GPIOPin::MODE_INPUT, GPIOPin::SLEW_SLOW);
RailDescriptorWithEnableAndPGood g_1v0("1V0", g_1v0_en, g_1v0_pgood, g_logTimer, 75);

GPIOPin g_1v0_2_en(&GPIOB, 15, GPIOPin::MODE_OUTPUT, GPIOPin::SLEW_SLOW);
GPIOPin g_1v0_2_pgood(&GPIOA, 8, GPIOPin::MODE_INPUT, GPIOPin::SLEW_SLOW);
RailDescriptorWithEnableAndPGood g_1v0_2("1V0_2", g_1v0_2_en, g_1v0_2_pgood, g_logTimer, 75);

GPIOPin g_2v5_en(&GPIOA, 11, GPIOPin::MODE_OUTPUT, GPIOPin::SLEW_SLOW);
GPIOPin g_2v5_pgood(&GPIOA, 12, GPIOPin::MODE_INPUT, GPIOPin::SLEW_SLOW);
RailDescriptorWithEnableAndPGood g_2v5("2V5", g_2v5_en, g_2v5_pgood, g_logTimer, 75);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Power rail sequence

etl::vector g_powerSequence
{
	//1V0 must come up first, since SERDES 1V0 rail is not allowed to be greater than the core
	(RailDescriptor*)&g_1v0,

	//then SERDES rail
	&g_1v0_2,

	//then 2V5 analog after everything critical
	&g_2v5
};
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Reset descriptors

GPIOPin g_phy0PowerDown(&GPIOC, 13, GPIOPin::MODE_OUTPUT, GPIOPin::SLEW_SLOW, 0);
ActiveLowResetDescriptorWithDelay g_phy0pdDescriptor(g_phy0PowerDown, "PHY0 PD", g_logTimer, 50);

GPIOPin g_phy0Reset(&GPIOB, 9, GPIOPin::MODE_OUTPUT, GPIOPin::SLEW_SLOW, 0);
ActiveLowResetDescriptorWithDelay g_phy0ResetDescriptor(g_phy0Reset, "PHY0 RST", g_logTimer, 50);

GPIOPin g_phy1PowerDown(&GPIOB, 0, GPIOPin::MODE_OUTPUT, GPIOPin::SLEW_SLOW, 0);
ActiveLowResetDescriptorWithDelay g_phy1pdDescriptor(g_phy1PowerDown, "PHY1 PD", g_logTimer, 50);

GPIOPin g_phy1Reset(&GPIOB, 1, GPIOPin::MODE_OUTPUT, GPIOPin::SLEW_SLOW, 0);
ActiveLowResetDescriptorWithDelay g_phy1ResetDescriptor(g_phy1Reset, "PHY1 RST", g_logTimer, 2500);

etl::vector g_resetSequence
{
	//First release power down
	(ResetDescriptor*)&g_phy0pdDescriptor,	//need to cast at least one entry to base class
										//for proper template deduction
	&g_phy1pdDescriptor,

	//then release resets
	&g_phy0ResetDescriptor,
	&g_phy1ResetDescriptor
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Task tables

etl::vector<Task*, MAX_TASKS>  g_tasks;
etl::vector<TimerTask*, MAX_TIMER_TASKS>  g_timerTasks;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// The top level supervisor controller

LineCardPowerResetSupervisor g_super(g_powerSequence, g_resetSequence);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Peripheral initialization

void App_Init()
{
	RCCHelper::Enable(&_RTC);

	//Format version string
	StringBuffer buf(g_version, sizeof(g_version));
	static const char* buildtime = __TIME__;
	buf.Printf("%s %c%c%c%c%c%c",
		__DATE__, buildtime[0], buildtime[1], buildtime[3], buildtime[4], buildtime[6], buildtime[7]);
	g_log("Firmware version %s\n", g_version);

	//Start tracing
	#ifdef _DEBUG
		ITM::Enable();
		DWT::EnablePCSampling(DWT::PC_SAMPLE_SLOW);
		ITM::EnableDwtForwarding();
	#endif

	static LEDTask ledTask;
	static ButtonTask buttonTask;
	//static KupLulzSuperSPIServer spiserver(g_spi);

	g_tasks.push_back(&ledTask);
	g_tasks.push_back(&buttonTask);
	g_tasks.push_back(&g_super);
	//g_tasks.push_back(&spiserver);

	g_timerTasks.push_back(&ledTask);

	//Enable pullups
	g_1v0_pgood.SetPullMode(GPIOPin::PULL_UP);
	g_1v0_2_pgood.SetPullMode(GPIOPin::PULL_UP);
	g_2v5_pgood.SetPullMode(GPIOPin::PULL_UP);

	//Turn on immediately, don't wait for a button press
	g_super.PowerOn();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Main loop
