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

#ifndef ButtonTask_h
#define ButtonTask_h

#include <core/Task.h>

class ButtonTask : public Task
{
public:
	ButtonTask()
		: m_buttonDown(false)
		, m_pwrButton(&GPIOB, 10, GPIOPin::MODE_INPUT, 0, false)
		, m_rstButton(&GPIOB, 11, GPIOPin::MODE_INPUT, 0, false)
	{
		m_pwrButton.SetPullMode(GPIOPin::PULL_DOWN);
		m_rstButton.SetPullMode(GPIOPin::PULL_DOWN);
	}

	virtual void Iteration()
	{
		if(m_pwrButton && !m_buttonDown)
		{
			g_log("Power button pressed\n");
			if(g_super.IsPowerOn())
				g_super.PowerOff();
			else
				g_super.PowerOn();
		}

		m_buttonDown = m_pwrButton;

		//TODO: make reset button do something
	}

protected:
	bool m_buttonDown;

	GPIOPin m_pwrButton;
	GPIOPin m_rstButton;
};

#endif


