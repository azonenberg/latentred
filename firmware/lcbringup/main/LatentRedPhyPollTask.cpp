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
#include "LatentRedPhyPollTask.h"
#include "PortState.h"

/**
	@brief Restart a poll cycle
 */
void LatentRedPhyPollTask::OnTimer()
{
	//Restart polling if we're done with the previous cycle
	//In some cases, we may not have finished (e.g. lots of log messages or network traffic bogging us down)
	//so let the previous iteration finish if so
	if(m_currentPhy >= 24)
	{
		m_currentPhy = 0;
		m_pollState = POLL_IDLE;
		m_linkStateChanged = false;
	}
}

/**
	@brief Restart a poll cycle
 */
void LatentRedPhyPollTask::Iteration()
{
	//Let the base class call OnTimer() if appropriate
	TimerTask::Iteration();

	//Run the actual PHY polling
	PollPHYs();
}

void LatentRedPhyPollTask::PollPHYs()
{
	//Did we already poll the last one? Nothing to do until next polling round
	if(m_currentPhy >= 24)
		return;

	//See what to do next
	switch(m_pollState)
	{
		//Start of poll cycle: request mutex then fetch basic status
		case POLL_IDLE:
			if(m_state.m_mutex.TryLock())
			{
				m_mdio->cmd_addr = (REG_BASIC_STATUS << 8) | m_currentPhy;
				m_pollState = POLL_STATUS;
			}
			break;

		//Wait for status register to be available
		case POLL_STATUS:
			if(m_mdio->status == 0)
			{
				//See if link is up
				uint32_t basicStatus = m_mdio->data;
				bool linkState = (basicStatus & 4) == 4;

				//Update link state
				auto& state = m_state.m_state[m_currentPhy];
				m_linkStateChanged = (state.m_linkUp != linkState);
				state.m_linkUp = linkState;

				//Read basic control
				m_mdio->cmd_addr = (REG_BASIC_CONTROL << 8) | m_currentPhy;
				m_pollState = POLL_CTRL;
			}
			break;

		case POLL_CTRL:
			if(m_mdio->status == 0)
			{
				//Save speed/duplex state
				uint32_t basicCtrl = m_mdio->data;
				auto speed = static_cast<linkspeed_t>(( (basicCtrl >> 13) & 1) | ( (basicCtrl >> 5) & 2));
				auto& state = m_state.m_state[m_currentPhy];
				state.m_speed = static_cast<linkspeed_t>(speed);

				//Print log messages on state change
				if(m_linkStateChanged)
				{
					if(state.m_linkUp)
						g_log("Interface %s: link is up at %s\n", state.m_ifname, g_linkSpeedNamesLong[speed]);
					else
						g_log("Interface %s: changed state to down\n", state.m_ifname);
				}

				//PHY does not report duplex state as expected in basic-control register
				//Instead, we want to grab it from auxiliary control/status!
				m_mdio->cmd_addr = (REG_VSC8512_AUX_CTRL_STAT << 8) | m_currentPhy;
				m_pollState = POLL_EXT_STAT;
			}
			break;

		case POLL_EXT_STAT:
			if(m_mdio->status == 0)
			{
				uint32_t extstat = m_mdio->data;
				auto& state = m_state.m_state[m_currentPhy];
				state.m_fullDuplex = ((extstat & 0x20) == 0x20) ? true : false;

				//Move on to next phy
				m_currentPhy ++;
				m_state.m_mutex.Unlock();
				m_pollState = POLL_IDLE;
			}
			break;

		default:
			break;
	}
}
