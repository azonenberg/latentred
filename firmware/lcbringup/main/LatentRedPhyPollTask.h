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

#ifndef LatentRedPhyPollTask_h
#define LatentRedPhyPollTask_h

#include <core/Task.h>
#include <embedded-utils/CooperativeMutex.h>

class LineCardState;

class LatentRedPhyPollTask : public TimerTask
{
public:
	LatentRedPhyPollTask(volatile APB_MDIO* mdio, uint8_t index, LineCardState& state)
		: TimerTask(0, 10*50)
		, m_mdio(mdio)
		, m_lineCardIndex(index)
		, m_state(state)
		, m_currentPhy(0)
		, m_pollState(POLL_IDLE)
		, m_linkStateChanged(false)
	{}

	virtual void OnTimer();
	virtual void Iteration();

protected:
	void PollPHYs();

	///@brief MDIO transceiver to use
	volatile APB_MDIO* m_mdio;

	///@brief Index of the line card (for display of messages etc)
	uint8_t		m_lineCardIndex;

	///@brief State of the line card
	LineCardState& m_state;

	///@brief Index of the phy being polled
	uint16_t	m_currentPhy;

	///@brief Current position in the polling cycle
	enum
	{
		POLL_IDLE,
		POLL_STATUS,
		POLL_CTRL,
		POLL_EXT_STAT
	} m_pollState;

	///@brief True if link state of the most recent poll changed
	bool m_linkStateChanged;
};

#endif

