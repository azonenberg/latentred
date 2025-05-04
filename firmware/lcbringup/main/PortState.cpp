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
#include "PortState.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// LineCardState

LineCardState::LineCardState(volatile APB_MDIO* mdio, int index)
	: m_mdio(mdio)
	, m_pollTask(mdio, index, *this)
{
	//Add the polling task iff we've got it (skip this part on lcbringup for missing line cards)
	if(mdio)
	{
		g_tasks.push_back(&m_pollTask);
		g_timerTasks.push_back(&m_pollTask);
	}

	//Name our ports
	for(int i=0; i<24; i++)
	{
		StringBuffer sbuf(m_state[i].m_ifname, sizeof(m_state[i].m_ifname));
		sbuf.Clear();
		sbuf.Printf("g%d/%d", index, i);
	}
}

void LineCardState::LoadFromKVS()
{
}

void LineCardState::SaveToKVS()
{
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// PortState

PortState::PortState()
	: m_lineCardState { LineCardState( &FMDIO, 0), LineCardState(nullptr, 1) }
{

}

void PortState::LoadFromKVS()
{
	for(int i=0; i<2; i++)
		m_lineCardState[i].LoadFromKVS();
}

void PortState::SaveToKVS()
{
	for(int i=0; i<2; i++)
		m_lineCardState[i].SaveToKVS();
}
