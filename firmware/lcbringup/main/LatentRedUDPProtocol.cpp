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
#include "LatentRedUDPProtocol.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

LatentRedUDPProtocol::LatentRedUDPProtocol(IPv4Protocol* ipv4)
	: UDPProtocol(ipv4)
	//, m_dhcp(this)
	, m_ntp(this)
{
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Timer handlers

void LatentRedUDPProtocol::OnAgingTick()
{
	//m_dhcp.OnAgingTick();
	m_ntp.OnAgingTick();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Message handlers

#ifdef HAVE_ITCM
__attribute__((section(".tcmtext")))
#endif
void LatentRedUDPProtocol::OnRxData(
	IPv4Address srcip,
	uint16_t sport,
	uint16_t dport,
	uint8_t* payload,
	uint16_t payloadLen)
{
	switch(dport)
	{
		/*case DHCP_CLIENT_PORT:
			m_dhcp.OnRxData(srcip, sport, dport, payload, payloadLen);
			break;*/

		case IPERF3_PORT:
			g_iperfServer->OnRxUdpData(srcip, sport, dport, payload, payloadLen);
			break;

		case NTP_PORT:
			m_ntp.OnRxData(srcip, sport, dport, payload, payloadLen);
			break;

		//ignore it
		default:
			break;
	}
}
