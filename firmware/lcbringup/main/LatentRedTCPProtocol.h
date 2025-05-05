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

#ifndef LatentRedTCPProtocol_h
#define LatentRedTCPProtocol_h

#include <fpga/AcceleratedCryptoEngine.h>
#include "LatentRedSSHTransportServer.h"
#include <services/Iperf3Server.h>

class UDPProtocol;

class LatentRedTCPProtocol : public TCPProtocol
{
public:
	LatentRedTCPProtocol(IPv4Protocol* ipv4, UDPProtocol& udp);

	virtual void OnAgingTick10x() override;

	LatentRedSSHTransportServer& GetSSH()
	{ return m_ssh; }

protected:
	virtual bool IsPortOpen(uint16_t port) override;
	virtual void OnConnectionAccepted(TCPTableEntry* state) override;
	virtual void OnConnectionClosed(TCPTableEntry* state) override;
	virtual void OnRxData(TCPTableEntry* state, uint8_t* payload, uint16_t payloadLen) override;

	virtual uint32_t GenerateInitialSequenceNumber() override;

	LatentRedSSHTransportServer m_ssh;
	Iperf3Server m_iperf;

	AcceleratedCryptoEngine m_crypt;
};

extern Iperf3Server* g_iperfServer;

#endif
