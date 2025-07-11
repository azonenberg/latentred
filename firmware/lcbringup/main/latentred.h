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

extern void PrintFPGAInfo(volatile APB_DeviceInfo_7series* devinfo);
extern void PrintFPGAInfo(volatile APB_DeviceInfo_UltraScale* devinfo);
extern void PrintFPGAInfo(volatile APB_DeviceInfo_7series* devinfo, CharacterDevice* stream);
extern void PrintFPGAInfo(volatile APB_DeviceInfo_UltraScale* devinfo, CharacterDevice* stream);

#include "PortState.h"
extern PortState* g_portState;

#endif
