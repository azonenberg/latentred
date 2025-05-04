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

#ifndef PortState_h
#define PortState_h

#include <tcpip/CommonTCPIP.h>
#include <embedded-utils/CooperativeMutex.h>
#include "LatentRedPhyPollTask.h"

/**
	@brief Status of a single interface
 */
class InterfaceState
{
public:
	InterfaceState()
		: m_linkUp(false)
		, m_fullDuplex(true)
		, m_speed(LINK_SPEED_10M)
		, m_autoneg(true)
	{
		memset(m_ifname, 0, sizeof(m_ifname));
		memset(m_friendlyName, 0, sizeof(m_friendlyName));
	}

	///@brief Link up/down state
	bool m_linkUp;

	///@brief Duplex state
	bool m_fullDuplex;

	///@brief Speed
	linkspeed_t m_speed;

	///@brief Autonegotiation enable
	bool m_autoneg;

	///@brief Name of the interface (e.g. Gigabit0/23)
	char m_ifname[16];

	///@brief Friendly name of the interface (user chosen)
	char m_friendlyName[32];
};

/**
	@brief Status of a single line card
 */
class LineCardState
{
public:
	LineCardState(volatile APB_MDIO* mdio, int index);

	InterfaceState m_state[24];

	///@brief Mutex for arbitrating access to MDIO interface
	CooperativeMutex m_mutex;

	///@brief MDIO interface
	volatile APB_MDIO* m_mdio;

	///@brief Polling task
	LatentRedPhyPollTask m_pollTask;

	void LoadFromKVS();
	void SaveToKVS();
};

/**
	@brief Top level container for status of all Ethernet ports
 */
class PortState
{
public:
	PortState();

	LineCardState m_lineCardState[2];
	InterfaceState m_mgmtState;
	InterfaceState m_uplinkState[2];

	void LoadFromKVS();
	void SaveToKVS();
};

#endif
