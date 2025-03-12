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

/**
	@file
	@author	Andrew D. Zonenberg
	@brief	ISRs shared by bootloader and application
 */
#include <core/platform.h>
#include "hwinit.h"

uint32_t g_spiRxFifoOverflows = 0;

void USART1_Handler();

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ISRs

/**
	@brief GPIO interrupt used for SPI chip select
 */
void SPI_CSHandler()
{
	//for now only trigger on falling edge so no need to check
	g_spi.OnIRQCSEdge(false);

	//Acknowledge the interrupt
	EXTI::ClearPending(4);
}

/**
	@brief SPI data interrupt
 */
void SPI1_Handler()
{
	if(SPI1.SR & SPI_RX_NOT_EMPTY)
	{
		if(!g_spi.OnIRQRxData(SPI1.DR))
			g_spiRxFifoOverflows ++;
	}
	if(SPI1.SR & SPI_TX_EMPTY)
	{
		if(g_spi.HasNextTxByte())
			SPI1.DR = g_spi.GetNextTxByte();

		//if no data to send, disable the interrupt
		else
			SPI1.CR2 &= ~SPI_TXEIE;
	}
}

/**
	@brief UART1 interrupt
 */
void USART1_Handler()
{
	if(USART1.ISR & USART_ISR_TXE)
		g_uart.OnIRQTxEmpty();

	if(USART1.ISR & USART_ISR_RXNE)
		g_uart.OnIRQRxData();
}
