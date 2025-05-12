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

#ifndef latentred_h
#define latentred_h

#include <core/platform.h>
#include <hwinit.h>

#include <peripheral/SPI.h>

#include <common-embedded-platform/services/Iperf3Server.h>
#include <embedded-utils/StringBuffer.h>

#include "LatentRedUDPProtocol.h"
#include "LatentRedTCPProtocol.h"

extern Iperf3Server* g_iperfServer;
extern LatentRedUDPProtocol* g_udp;
extern LatentRedTCPProtocol* g_tcp;

void InitLEDs();
void InitSensors();

//extern DumptruckSSHTransportServer* g_sshd;

enum mdioreg_t_ext
{
	//VSC8512 specific
	REG_VSC8512_PAGESEL			= 0x1f,

	//VSC8512 main/standard page
	REG_VSC8512_EXT_CTRL_STAT	= 0x14,
	REG_VSC8512_EXT_PHY_CTRL_2	= 0x18,
	REG_VSC8512_AUX_CTRL_STAT	= 0x1c,

	//VSC8512 extended page 1
	REG_VSC8512_LED_MODE		= 0x1d,

	//VSC8512 extended page 2
	VSC_CU_PMD_TX				= 0x10,

	//VSC8512 extended page 3
	VSC_MAC_PCS_CTL				= 0x10,

	//GPIO / global command page
	REG_VSC_GP_GLOBAL_SERDES	= 0x12,
	REG_VSC_MAC_MODE			= 0x13,
	//14.2.3 p18 says 19G 15:14 = 00/10
	REG_VSC_TEMP_CONF			= 0x1a,
	REG_VSC_TEMP_VAL			= 0x1c
};

enum vsc_page_t
{
	VSC_PAGE_MAIN				= 0x0000,
	VSC_PAGE_EXT1				= 0x0001,
	VSC_PAGE_EXT2				= 0x0002,
	VSC_PAGE_EXT3				= 0x0003,

	VSC_PAGE_GENERAL_PURPOSE	= 0x0010,
	VSC_PAGE_TEST				= 0x2a30,
	VSC_PAGE_TR					= 0x52b5
};

uint16_t GetVSC8512Temperature(MDIODevice& mdev);

extern void PrintFPGAInfo(volatile APB_DeviceInfo_7series* devinfo);
extern void PrintFPGAInfo(volatile APB_DeviceInfo_UltraScale* devinfo);
extern void PrintFPGAInfo(volatile APB_DeviceInfo_7series* devinfo, CharacterDevice* stream);
extern void PrintFPGAInfo(volatile APB_DeviceInfo_UltraScale* devinfo, CharacterDevice* stream);

#include "PortState.h"
extern PortState* g_portState;

#endif
