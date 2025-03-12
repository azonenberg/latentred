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

#include "supervisor.h"

typedef void(*fnptr)();

extern uint32_t __stack;
extern uint32_t __bss_start__;
extern uint32_t __bss_end__;

//prototypes
extern "C" void _start();
void MMUFault_Handler();
void UsageFault_Handler();
void BusFault_Handler();
void HardFault_Handler();
void NMI_Handler();

void defaultISR();
void SPI_CSHandler();
void SPI1_Handler();
void USART1_Handler();

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Interrupt vector table

fnptr __attribute__((section(".vector"))) vectorTable[] =
{
	(fnptr)&__stack,		//stack
	_start,					//reset
	NMI_Handler,			//NMI
	HardFault_Handler,		//hardfault
	MMUFault_Handler,		//mmufault
	BusFault_Handler,		//busfault
	UsageFault_Handler,		//usagefault
	defaultISR,				//reserved_7
	defaultISR,				//reserved_8
	defaultISR,				//reserved_9
	defaultISR,				//reserved_10
	defaultISR,				//svcall
	defaultISR,				//debug
	defaultISR,				//reserved_13
	defaultISR,				//pend_sv
	defaultISR,				//systick
	defaultISR,				//irq0 WWDG
	defaultISR,				//irq1 PVD
	defaultISR,				//irq2 RTC
	defaultISR,				//irq3 RTC_WKUP
	defaultISR,				//irq4 FLASH
	defaultISR,				//irq5 RCC
	defaultISR,				//irq6 EXTI0
	defaultISR,				//irq7 EXTI1
	defaultISR,				//irq8 EXTI1
	defaultISR,				//irq9 EXTI3
	SPI_CSHandler,			//irq10 EXTI4
	defaultISR,				//irq11 DMA1_CH1
	defaultISR,				//irq12 DMA1_CH2
	defaultISR,				//irq13 DMA1_CH3
	defaultISR,				//irq14 DMA1_CH4
	defaultISR,				//irq15 DMA1_CH5
	defaultISR,				//irq16 DMA1_CH6
	defaultISR,				//irq17 DMA1_CH7
	defaultISR,				//irq18 ADC1_2
	defaultISR,				//irq19 CAN1_TX
	defaultISR,				//irq20 CAN1_RX0
	defaultISR,				//irq21 CAN1_RX1
	defaultISR,				//irq22 CAN1_SCE
	defaultISR,				//irq23 EXTI9_5
	defaultISR,				//irq24 TIM1_BRK/TIM15
	defaultISR,				//irq25 TIM1_UP/TIM16
	defaultISR,				//irq26 TIM1_TRG_COM
	defaultISR,				//irq27 TIM1_CC
	defaultISR,				//irq28 TIM2
	defaultISR,				//irq29 TIM3
	defaultISR,				//irq30 reserved
	defaultISR,				//irq31 I2C1_EV
	defaultISR,				//irq32 I2C1_ER
	defaultISR,				//irq33 I2C2_EV
	defaultISR,				//irq34 I2C2_ER
	SPI1_Handler,			//irq35 SPI1
	defaultISR,				//irq36 SPI2
	USART1_Handler,			//irq37 USART1
	defaultISR,				//irq38 USART2
	defaultISR,				//irq39 USART3
	defaultISR,				//irq40 EXTI15_10
	defaultISR,				//irq41 RTC_ALARM
	defaultISR,				//irq42 reserved
	defaultISR,				//irq43 reserved
	defaultISR,				//irq44 reserved
	defaultISR,				//irq45 reserved
	defaultISR,				//irq46 reserved
	defaultISR,				//irq47 reserved
	defaultISR,				//irq48 reserved
	defaultISR,				//irq49 SDMMC1
	defaultISR,				//irq50 reserved
	defaultISR,				//irq51 SPI3
	defaultISR,				//irq52 UART4
	defaultISR,				//irq53 reserved
	defaultISR,				//irq54 TIM6_DACUNDER
	defaultISR,				//irq55 TIM7
	defaultISR,				//irq56 DMA2_CH1
	defaultISR,				//irq57 DMA2_CH2
	defaultISR,				//irq58 DMA2_CH3
	defaultISR,				//irq59 DMA2_CH4
	defaultISR,				//irq60 DMA2_CH5
	defaultISR,				//irq61 DFSDM1_FLT0
	defaultISR,				//irq62 DFSDM1_FLT1
	defaultISR,				//irq63 reserved
	defaultISR,				//irq64 COMP
	defaultISR,				//irq65 LPTIM1
	defaultISR,				//irq66 LPTIM2
	defaultISR,				//irq67 USB_FS
	defaultISR,				//irq68 DMA2_CH6
	defaultISR,				//irq69 DMA2_CH7
	defaultISR,				//irq70 LPUART1
	defaultISR,				//irq71 QUADSPI
	defaultISR,				//irq72 I2C3_EV
	defaultISR,				//irq73 I2C3_ER
	defaultISR,				//irq74 SAI1
	defaultISR,				//irq75 reserved
	defaultISR,				//irq76 SWPMI1
	defaultISR,				//irq77 TSC
	defaultISR,				//irq78 LCD
	defaultISR,				//irq79 AES
	defaultISR,				//irq80 RNG
	defaultISR,				//irq81 FPU
	defaultISR,				//irq82 CRS
	defaultISR,				//irq83 I2C4_EV
	defaultISR				//irq84 I2C4_ER
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Firmware version string used for the bootloader

extern "C" const char
	__attribute__((section(".fwid")))
	__attribute__((used))
	g_firmwareID[] = "kup-lulz-supervisor";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Stub for unused interrupts

void defaultISR()
{
	//g_bbram->m_state = STATE_CRASH;
	//g_bbram->m_crashReason = CRASH_UNUSED_ISR;
	Reset();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Exception vectors

void NMI_Handler()
{
	//g_bbram->m_state = STATE_CRASH;
	//g_bbram->m_crashReason = CRASH_NMI;
	Reset();
}

void HardFault_Handler()
{
	//Save registers
	uint32_t* msp;
	asm volatile("mrs %[result], MSP" : [result]"=r"(msp));
	msp += 12;	//locals/alignment
	uint32_t r0 = msp[0];
	uint32_t r1 = msp[1];
	uint32_t r2 = msp[2];
	uint32_t r3 = msp[3];
	uint32_t r12 = msp[4];
	uint32_t lr = msp[5];
	uint32_t pc = msp[6];
	uint32_t xpsr = msp[7];

	g_uart.Printf("Hard fault\n");
	g_uart.Printf("    HFSR  = %08x\n", *(volatile uint32_t*)(0xe000ed2C));
	g_uart.Printf("    MMFAR = %08x\n", *(volatile uint32_t*)(0xe000ed34));
	g_uart.Printf("    BFAR  = %08x\n", *(volatile uint32_t*)(0xe000ed38));
	g_uart.Printf("    CFSR  = %08x\n", *(volatile uint32_t*)(0xe000ed28));
	g_uart.Printf("    UFSR  = %08x\n", *(volatile uint16_t*)(0xe000ed2a));
	g_uart.Printf("    DFSR  = %08x\n", *(volatile uint32_t*)(0xe000ed30));
	g_uart.Printf("    MSP   = %08x\n", msp);
	g_uart.BlockingFlush();
	g_uart.Printf("    r0    = %08x\n", r0);
	g_uart.Printf("    r1    = %08x\n", r1);
	g_uart.Printf("    r2    = %08x\n", r2);
	g_uart.Printf("    r3    = %08x\n", r3);
	g_uart.Printf("    r12   = %08x\n", r12);
	g_uart.Printf("    lr    = %08x\n", lr);
	g_uart.Printf("    pc    = %08x\n", pc);
	g_uart.Printf("    xpsr  = %08x\n", xpsr);

	g_uart.Printf("    Stack:\n");
	g_uart.BlockingFlush();
	for(int i=0; i<16; i++)
	{
		g_uart.Printf("        %08x\n", msp[i]);
		g_uart.BlockingFlush();
	}

	//Shut down as we can no longer properly supervise the rails
	g_super.PanicShutdown();

	while(1)
	{}

	//g_bbram->m_state = STATE_CRASH;
	//g_bbram->m_crashReason = CRASH_HARD_FAULT;
	//Reset();
}

void BusFault_Handler()
{
	//g_bbram->m_state = STATE_CRASH;
	//g_bbram->m_crashReason = CRASH_BUS_FAULT;
	Reset();
}

void UsageFault_Handler()
{
	//g_bbram->m_state = STATE_CRASH;
	//g_bbram->m_crashReason = CRASH_USAGE_FAULT;
	Reset();
}

void MMUFault_Handler()
{
	//g_bbram->m_state = STATE_CRASH;
	//g_bbram->m_crashReason = CRASH_MMU_FAULT;
	Reset();
}
