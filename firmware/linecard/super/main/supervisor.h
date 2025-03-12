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

#ifndef supervisor_h
#define supervisor_h

#include <supervisor/supervisor-common.h>
#include <supervisor/PowerResetSupervisor.h>

//#include <bootloader/BootloaderAPI.h>
#include "../bsp/hwinit.h"

///@brief Project-specific supervisor class with hooks for controlling LEDs on panic
class LineCardPowerResetSupervisor : public PowerResetSupervisor
{
public:
	LineCardPowerResetSupervisor(etl::ivector<RailDescriptor*>& rails, etl::ivector<ResetDescriptor*>& resets)
	: PowerResetSupervisor(rails, resets)
	{}

protected:

	virtual void OnPowerOn() override
	{ g_pgoodLED = 1; }

	virtual void OnPowerOff() override
	{ g_pgoodLED = 0; }

	virtual void OnFault() override
	{
		//Set LEDs to fault state
		g_faultLED = 1;
		g_sysokLED = 0;
		g_pgoodLED = 0;

		//Hang until reset, don't attempt to auto restart
		while(1)
		{}
	}
};

extern LineCardPowerResetSupervisor g_super;

#endif
